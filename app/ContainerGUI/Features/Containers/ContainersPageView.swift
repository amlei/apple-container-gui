import AppKit
import SwiftUI

struct ContainersPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel
    @State private var filter = 0
    @State private var search = ""
    @State private var stats: [String: ContainerStatsSnapshot] = [:]
    @FocusState private var searchFocused: Bool

    var body: some View {
        PageScaffold(title: L("nav.containers")) {
            SQSegmented(options: [L("filter.all"), L("filter.running"), L("filter.stopped")], selection: $filter)
            SQSearchField(placeholder: L("search.ph.containers"), text: $search)
                .focused($searchFocused)
            SQButton(title: L("act.runContainer"), icon: "plus", primary: true) { model.show(.run(image: nil)) }
        } body: {
            VStack(spacing: 12) {
                if !store.servicesRunning { SQOfflineBanner() }
                if filtered.isEmpty {
                    SQCard {
                        SQEmpty(
                            icon: search.isEmpty ? "cube" : "magnifyingglass",
                            title: search.isEmpty ? L("ct.empty") : L("ct.nomatch"),
                            hint: search.isEmpty ? L("ct.empty.hint") : "",
                            buttonTitle: search.isEmpty ? L("act.runContainer") : nil
                        ) { model.show(.run(image: nil)) }
                    }
                } else {
                    SQCard {
                        VStack(spacing: 0) {
                            containerHeader
                            ForEach(filtered) { c in
                                SQContainerRow(container: c, stats: stats[c.id]) {
                                    model.openDrawer(.container(id: c.id))
                                }
                                .contextMenu { containerMenu(for: c) }
                                if c.id != filtered.last?.id { Divider() }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { loadStats() }
        .onChange(of: store.containers.count) { _ in loadStats() }
        .onChange(of: model.searchFocusTick) { _ in searchFocused = true }
    }

    private var filtered: [ManagedContainer] {
        var rows = store.containers
        if filter == 1 { rows = rows.filter(\.isRunning) }
        if filter == 2 { rows = rows.filter { !$0.isRunning } }
        if !search.isEmpty {
            let q = search.lowercased()
            rows = rows.filter { $0.id.lowercased().contains(q) || $0.imageRef.lowercased().contains(q) }
        }
        return rows
    }

    private var containerHeader: some View {
        HStack(spacing: 16) {
            Text(L("ct.name")).frame(maxWidth: .infinity, alignment: .leading)
            Text(L("ct.status")).frame(width: 92, alignment: .leading)
            Text(L("ct.cpu")).frame(width: 56, alignment: .trailing)
            Text(L("ct.mem")).frame(width: 76, alignment: .trailing)
            Text(L("ct.ip")).frame(maxWidth: .infinity, alignment: .leading)
            Text(L("ct.created")).frame(width: 92, alignment: .trailing)
            Color.clear.frame(width: 56)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(SQ.text2)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(SQ.cardBg.opacity(0.88))
        .overlay(alignment: .bottom) { Rectangle().fill(SQ.hairlineStrong).frame(height: 0.5) }
    }

    @ViewBuilder private func containerMenu(for c: ManagedContainer) -> some View {
        containerActionMenu(c, model)
    }

    private func loadStats() {
        guard !store.containers.isEmpty else { return }
        Task {
            var result: [String: ContainerStatsSnapshot] = [:]
            for c in store.containers where c.isRunning {
                if let s = await Commands.stats(id: c.id) { result[c.id] = s }
            }
            await MainActor.run { stats = result }
        }
    }
}

private struct SQContainerRow: View {
    let container: ManagedContainer
    let stats: ContainerStatsSnapshot?
    let onOpen: () -> Void
    @EnvironmentObject private var model: SQAppModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(container.isRunning ? SQ.green : (container.status.state == .stopped ? SQ.red.opacity(0.3) : SQ.text2))
                        .frame(width: 8, height: 8)
                    Text(container.id)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(container.imageRef)
                    .font(SQ.monoSmall)
                    .foregroundStyle(SQ.text2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusCell.frame(width: 92, alignment: .leading)
            Text(cpuText)
                .font(.system(size: 12))
                .foregroundStyle(SQ.text2)
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
            Text(memText)
                .font(.system(size: 12))
                .foregroundStyle(SQ.text2)
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.ip)
                    .font(SQ.monoSmall)
                    .foregroundStyle(SQ.text)
                Text(portsText)
                    .font(SQ.monoSmall)
                    .foregroundStyle(SQ.text2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.relTime(container.isRunning ? container.status.startedDate : (container.status.finishedDate ?? container.status.startedDate)))
                .font(.system(size: 12))
                .foregroundStyle(SQ.text2)
                .frame(width: 92, alignment: .trailing)

            HStack(spacing: 3) {
                Button {
                    Task {
                        try? await Commands.containerAction(container.isRunning ? "stop" : "start", ids: [container.id])
                        Store.shared.refresh()
                    }
                } label: {
                    Image(systemName: container.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SQ.text2)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? SQ.fill2 : Color.clear))
                }
                .buttonStyle(SQPlainButtonStyle())
                Menu {
                    containerActionMenu(container, model)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SQ.text2)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? SQ.fill2 : Color.clear))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .frame(width: 56)
            .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(hovering ? SQ.fill1 : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onOpen)
    }

    @ViewBuilder private var statusCell: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(container.isRunning ? SQ.green : (container.status.state == .stopped ? SQ.red.opacity(0.3) : SQ.text2))
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SQ.text)
        }
    }

    private var statusText: String {
        if container.isRunning { return L("st.running") }
        switch container.status.state {
        case .stopped: return L("st.exited")
        case .created: return L("st.created")
        case .running: return L("st.running")
        case .unknown: return L("st.exited")
        case nil: return "—"
        }
    }

    private var cpuText: String {
        container.isRunning ? String(format: "%.1f%%", stats?.cpuPercent ?? 0) : "—"
    }
    private var memText: String {
        container.isRunning ? Fmt.bytes(stats?.memoryUsageBytes ?? 0) : "—"
    }
    private var portsText: String {
        let pairs = container.portPairs
        guard !pairs.isEmpty else { return "" }
        return pairs.map { "\($0.host)→\($0.ct)/\($0.proto)" }.joined(separator: ", ")
    }
}

@ViewBuilder func containerActionMenu(_ c: ManagedContainer, _ model: SQAppModel) -> some View {
    if c.isRunning {
        Button { Task { try? await Commands.containerAction("stop", ids: [c.id]); Store.shared.refresh() } } label: {
            Label(L("act.stop"), systemImage: "stop.fill")
        }
        Button(role: .destructive, action: {
            model.confirm(L("kill.title", ["id": c.id]), message: L("kill.msg"), confirm: L("confirm.kill"), danger: true) {
                Task { try? await Commands.containerAction("kill", ids: [c.id]); Store.shared.refresh() }
            }
        }) { Label(L("act.kill"), systemImage: "bolt.fill").foregroundStyle(SQ.red) }
    } else {
        Button { Task { try? await Commands.containerAction("start", ids: [c.id]); Store.shared.refresh() } } label: {
            Label(L("act.start"), systemImage: "play.fill")
        }
    }
    Divider()
    Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(c.id, forType: .string)
        model.showToast(L("copied"))
    } label: {
        Label(L("act.copyId"), systemImage: "doc.on.doc")
    }
    Button {
        let dlg = NSSavePanel()
        dlg.nameFieldStringValue = c.id + ".tar"
        if let w = NSApp.keyWindow {
            dlg.beginSheetModal(for: w) { resp in
                guard resp == .OK, let url = dlg.url else { return }
                Task {
                    try? await Commands.exportContainer(c.id, to: url.path)
                    model.showToast(L("export.doneMsg", ["path": url.path]))
                }
            }
        }
    } label: {
        Label(L("act.exportFs"), systemImage: "square.and.arrow.up")
    }
    Divider()
    Button(role: .destructive) {
        model.confirm(L("del.ct.title", ["id": c.id]), message: L("del.ct.msg"), confirm: L("confirm.yes"), danger: true) {
            Task { try? await Commands.containerAction("delete", ids: [c.id]); Store.shared.refresh() }
        }
    } label: { Label(L("act.delete"), systemImage: "trash").foregroundStyle(SQ.red) }
}

@ViewBuilder func imageActionMenu(_ image: ImageResourceJSON, _ model: SQAppModel) -> some View {
    Button { model.show(.run(image: image.ref)) } label: {
        Label(L("act.runContainer"), systemImage: "play.fill")
    }
    Button {
        Task { try? await Commands.pushImage(image.ref); model.showToast(L("push.doneMsg", ["ref": image.ref])) }
    } label: {
        Label(L("act.push"), systemImage: "arrow.up")
    }
    Button { model.show(.tag(image: image.ref)) } label: {
        Label(L("act.tagNew"), systemImage: "tag")
    }
    Divider()
    Button {
        let dlg = NSSavePanel()
        dlg.nameFieldStringValue = image.ref.components(separatedBy: "/").last?.replacingOccurrences(of: ":", with: "_").appending(".tar") ?? "image.tar"
        if let w = NSApp.keyWindow {
            dlg.beginSheetModal(for: w) { resp in
                guard resp == .OK, let url = dlg.url else { return }
                Task {
                    try? await Commands.saveImage(image.ref, to: url.path)
                    model.showToast(L("saved.doneMsg", ["path": url.path]))
                }
            }
        }
    } label: {
        Label(L("act.saveTar"), systemImage: "arrow.down")
    }
    Divider()
    Button(role: .destructive) {
        model.confirm(L("del.img.title", ["ref": image.ref]), message: L("del.img.msg"), confirm: L("confirm.yes"), danger: true) {
            Task { try? await Commands.deleteImages([image.ref]); Store.shared.refresh() }
        }
    } label: { Label(L("act.delete"), systemImage: "trash").foregroundStyle(SQ.red) }
}
