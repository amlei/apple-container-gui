import AppKit
import SwiftUI

// MARK: - Root SwiftUI content

struct ContentRootView: View {
    @ObservedObject private var store = Store.shared
    @StateObject private var model = SQAppModel()
    @State private var keyMonitor: Any?

    var body: some View {
        ZStack(alignment: .trailing) {
            page
            if let drawer = model.drawer {
                SQDrawerHost(drawer: drawer)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .allowsHitTesting(true)
            }
        }
        .background(SQ.contentBg)
        .environmentObject(model)
        .sheet(item: $model.sheet) { sheet in
            SQSheetView(sheet: sheet)
                .environmentObject(model)
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                SQToastView(toast: toast)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert(item: $model.confirmation) { confirm in
            Alert(
                title: Text(confirm.title),
                message: confirm.message.isEmpty ? nil : Text(confirm.message),
                primaryButton: .destructive(Text(confirm.confirm), action: { confirm.onConfirm() }),
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .runPrimaryAction)) { _ in
            runPrimary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchAction)) { _ in
            model.requestSearchFocus()
        }
        .onAppear { installKeyMonitor() }
        .onDisappear {
            if let m = keyMonitor { NSEvent.removeMonitor(m) }
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // "/" focuses the page search field when not already typing.
            if event.charactersIgnoringModifiers == "/", !isEditingText {
                NotificationCenter.default.post(name: .focusSearchAction, object: nil)
                return nil
            }
            // Escape closes the right-hand drawer.
            if event.keyCode == 53, model.drawer != nil {
                model.closeDrawer()
                return nil
            }
            return event
        }
    }

    private var isEditingText: Bool {
        guard let fr = NSApp.keyWindow?.firstResponder else { return false }
        return fr is NSTextView || fr is NSTextField
    }

    private func runPrimary() {
        switch store.route {
        case .containers: model.show(.run(image: nil))
        case .images: model.show(.pull)
        case .volumes: model.show(.newVolume)
        case .networks: model.show(.newNetwork)
        case .machines: model.show(.newMachine)
        case .k8s: model.show(.k8sNew)
        case .overview: store.setRoute(.containers)
        default: break
        }
    }

    @ViewBuilder private var page: some View {
        switch store.route {
        case .overview: OverviewPageView()
        case .containers: ContainersPageView()
        case .images: ImagesPageView()
        case .volumes: VolumesPageView()
        case .networks: NetworksPageView()
        case .machines: MachinesPageView()
        case .k8s: K8sPageView()
        case .settings: SettingsPageView()
        }
    }
}

// MARK: - Page scaffold (title + actions + body)

struct PageScaffold<Actions: View, Content: View>: View {
    let title: String
    let actions: () -> Actions
    let content: () -> Content

    init(title: String,
         @ViewBuilder actions: @escaping () -> Actions,
         @ViewBuilder body: @escaping () -> Content) {
        self.title = title
        self.actions = actions
        self.content = body
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    HStack(spacing: 10) { actions() }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(minHeight: 34)
                content()
            }
            .padding(.top, 18)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Offline banner

struct SQOfflineBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(SQ.red)
                .padding(.top, 1)
            Text("**\(L("svc.notRunning.banner.title"))** · \(L("svc.notRunning.banner.msg"))")
                .font(.system(size: 12.5))
                .foregroundStyle(SQ.text)
            Spacer()
        }
        .padding(11)
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SQ.red.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SQ.red.opacity(0.28), lineWidth: 0.5))
    }
}

// MARK: - Toast

struct SQToastView: View {
    let toast: SQToast
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(toast.isError ? SQ.red : SQ.green)
            Text(toast.message)
                .font(.system(size: 12.5, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(SQ.contentBg.opacity(0.92)))
        .overlay(Capsule().stroke(SQ.hairlineStrong, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

// MARK: - Drawer host (right side panel over content)

struct SQDrawerHost: View {
    @EnvironmentObject private var model: SQAppModel
    let drawer: SQDrawer

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Transparent, non-dimming scrim: keeps click-to-close on the empty
                // area without the gray overlay the prototype drops.
                Color.clear
                    .onTapGesture { model.closeDrawer() }
                    .transition(.opacity)
                switch drawer {
                case .container(let id): ContainerDrawerView(containerID: id)
                case .image(let ref): ImageDrawerView(ref: ref)
                case .volume(let name): VolumeDrawerView(name: name)
                case .machineShell(let name): MachineShellDrawerView(name: name)
                case .machineLogs(let name): MachineLogsDrawerView(name: name)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .trailing)
            .clipped()
        }
    }
}
