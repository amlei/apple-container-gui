import AppKit
import SwiftUI

struct SettingsPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel
    @AppStorage("theme") private var themeRaw = "auto"
    @State private var themeSel = 0
    @State private var dnsInput = ""
    @State private var recAction: String?
    @State private var recToken: Any?
    @State private var keymapVersion = 0
    @State private var langSel = 0

    var body: some View {
        PageScaffold(title: L("nav.settings")) {
            EmptyView()
        } body: {
            VStack(spacing: 16) {
                appearanceGroup
                serviceGroup
                kernelGroup
                dnsGroup
                registriesGroup
                propertiesGroup
                shortcutsGroup
            }
        }
        .onAppear {
            themeSel = ["auto", "light", "dark"].firstIndex(of: themeRaw) ?? 0
            applyTheme(themeSel)
            langSel = ["auto", "zh-Hans", "en"].firstIndex(of: AppLanguage.current) ?? 0
        }
        .onChange(of: themeSel) { _ in applyTheme(themeSel) }
        .onChange(of: langSel) { _ in Store.shared.setLanguage(["auto", "zh-Hans", "en"][langSel]) }
    }

    private var appearanceGroup: some View {
        SQSettingsGroup(title: L("set.appearance")) {
            SQSettingsRow(label: L("set.theme")) {
                SQSegmented(options: [L("theme.auto"), L("theme.light"), L("theme.dark")], selection: $themeSel)
            }
            SQSettingsRow(label: L("set.language")) {
                Picker("", selection: $langSel) {
                    ForEach(["auto", "zh-Hans", "en"].indices, id: \.self) { i in
                        Text(langLabel(i)).tag(i)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func langLabel(_ i: Int) -> String {
        switch i {
        case 1: return "简体中文"
        case 2: return "English"
        default: return L("set.language.system")
        }
    }

    private func applyTheme(_ idx: Int) {
        themeRaw = ["auto", "light", "dark"][idx]
        let ap = idx == 1 ? NSAppearance(named: .aqua) : (idx == 2 ? NSAppearance(named: .darkAqua) : nil)
        // Apply synchronously so the appearance and the segmented thumb update in one
        // render pass; deferring this to an async pass causes a two-phase flash.
        NSApp.appearance = ap
    }

    private var serviceGroup: some View {
        SQSettingsGroup(title: L("set.svc"), desc: L("set.svc.desc")) {
            SQSettingsRow(label: L("set.svc.state")) {
                SQPill(text: store.servicesRunning ? L("svc.running") : L("svc.stopped"), ok: store.servicesRunning)
                if store.servicesRunning {
                    SQButton(title: L("svc.stopBtn"), icon: "power", danger: true, small: true) {
                        model.confirm(L("svc.stopWarnTitle"), message: L("svc.stopWarnMsg"), confirm: L("confirm.stop"), danger: true) {
                            Task { try? await Commands.systemStop(); Store.shared.refresh() }
                        }
                    }
                } else {
                    SQButton(title: L("svc.startBtn"), icon: "play.fill", primary: true, small: true) {
                        Task { model.showToast(L("svc.starting")); try? await Commands.systemStart(); model.showToast(L("svc.running")); Store.shared.refresh() }
                    }
                }
                SQButton(title: L("set.syslogs"), icon: "doc.text", small: true) { model.show(.systemLogs) }
            }
            SQSettingsRow(label: L("ov.service.version.cli")) {
                Text("container \(store.cliVersion)").font(SQ.mono).foregroundStyle(SQ.text2)
            }
            SQSettingsRow(label: L("ov.service.version.api")) {
                Text(store.apiVersion).font(SQ.mono).foregroundStyle(SQ.text2)
            }
        }
    }

    private var kernelGroup: some View {
        SQSettingsGroup(title: L("set.kernel"), desc: L("set.kernel.rec")) {
            let kernel = store.properties.first { $0.key == "kernel.binaryPath" }?.value.components(separatedBy: "/").last ?? "—"
            SQSettingsRow(label: L("set.kernel.current")) { Text(kernel).font(SQ.mono).foregroundStyle(SQ.text2) }
            SQSettingsRow(label: L("set.kernel.arch")) { Text("arm64") }
            SQSettingsRow(label: L("set.kernel.digest")) { Text(L("ct.d.none")).font(SQ.mono).foregroundStyle(SQ.text3) }
            SQSettingsRow(label: "") {
                SQButton(title: L("act.installRecKernel"), icon: "arrow.down", primary: true, small: true) {
                    Task { model.showToast(L("set.kernel.installing")); try? await Commands.kernelSetRecommended(); model.showToast(L("set.kernel.ok")); Store.shared.refreshSystemInfo() }
                }
                SQButton(title: L("act.customKernel"), icon: "folder", small: true) {
                    let dlg = NSOpenPanel()
                    dlg.canChooseFiles = true
                    dlg.canChooseDirectories = false
                    if let w = NSApp.keyWindow {
                        dlg.beginSheetModal(for: w) { resp in
                            guard resp == .OK, let path = dlg.url?.path else { return }
                            Task { try? await Commands.kernelSetBinary(path); model.showToast(path); Store.shared.refreshSystemInfo() }
                        }
                    }
                }
            }
        }
    }

    private var dnsGroup: some View {
        SQSettingsGroup(title: L("set.dns"), desc: L("set.dns.desc")) {
            ForEach(store.dnsDomains, id: \.self) { d in
                SQSettingsRow(label: "*.\(d)") {
                    Text("/etc/resolver/\(d)").font(SQ.mono).foregroundStyle(SQ.text2).frame(maxWidth: .infinity, alignment: .leading)
                    SQButton(title: L("act.remove"), icon: "trash", danger: true, small: true) {
                        model.confirm(d, message: "/etc/resolver/\(d)", confirm: L("act.remove"), danger: true) {
                            Task { try? await Commands.dnsDelete(d); Store.shared.refreshSystemInfo() }
                        }
                    }
                }
            }
            SQSettingsRow(label: "") {
                HStack(spacing: 8) {
                    TextField(L("set.dns.add.ph"), text: $dnsInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(SQ.fill1))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(SQ.hairline, lineWidth: 0.5))
                        .frame(width: 220)
                    SQButton(title: L("act.add"), icon: "plus", small: true) {
                        let d = dnsInput.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "*.", with: "")
                        guard !d.isEmpty else { return }
                        Task { try? await Commands.dnsCreate(d); model.showToast("*." + d); dnsInput = ""; Store.shared.refreshSystemInfo() }
                    }
                }
            }
        }
    }

    private var registriesGroup: some View {
        SQSettingsGroup(title: L("set.reg"), desc: L("set.reg.desc")) {
            ForEach(store.registries, id: \.self) { r in
                SQSettingsRow(label: r) {
                    Text("—").font(SQ.mono).foregroundStyle(SQ.text2).frame(maxWidth: .infinity, alignment: .leading)
                    SQButton(title: L("act.logout"), small: true) {
                        model.confirm(r, message: L("set.reg.desc"), confirm: L("confirm.logout"), danger: true) {
                            Task { try? await Commands.registryLogout(r); Store.shared.refreshSystemInfo() }
                        }
                    }
                }
            }
            SQSettingsRow(label: "") {
                SQButton(title: L("act.login"), icon: "key", primary: true, small: true) { model.show(.registryLogin) }
            }
        }
    }

    private var propertiesGroup: some View {
        SQSettingsGroup(title: L("set.props"), desc: L("set.props.desc")) {
            ForEach(Array(store.properties.prefix(30)), id: \.key) { p in
                SQSettingsRow(label: p.key) {
                    Text(p.value).font(SQ.mono).foregroundStyle(SQ.text2).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
            }
        }
    }

    private var shortcutsGroup: some View {
        SQSettingsGroup(title: L("keys.title"), desc: L("keys.desc")) {
            shortcutRow(L("nav.overview"), "nav.overview")
            shortcutRow(L("nav.containers"), "nav.containers")
            shortcutRow(L("nav.images"), "nav.images")
            shortcutRow(L("nav.volumes"), "nav.volumes")
            shortcutRow(L("nav.networks"), "nav.networks")
            shortcutRow(L("nav.machines"), "nav.machines")
            shortcutRow(L("nav.k8s"), "nav.k8s")
            shortcutRow(L("nav.settings"), "nav.settings")
            shortcutRow(L("act.search"), "focus.search")
            shortcutRow(L("act.primary"), "primary.action")
            SQSettingsRow(label: "") {
                SQButton(title: L("keys.reset"), icon: "arrow.triangle.2.circlepath", small: true) {
                    Keymap.reset()
                    keymapVersion += 1
                    NotificationCenter.default.post(name: .keymapChanged, object: nil)
                    model.showToast(L("keys.saved"))
                }
            }
        }
        .id(keymapVersion)
    }

    private func shortcutRow(_ label: String, _ action: String) -> some View {
        SQSettingsRow(label: label) {
            Button {
                startRecording(action)
            } label: {
                Text(recAction == action ? L("keys.recording") : (Keymap.combo(action).isEmpty ? L("keys.none") : Keymap.pretty(Keymap.combo(action))))
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(minWidth: 44)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(recAction == action ? SQ.accent.opacity(0.16) : SQ.fill1))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(recAction == action ? SQ.accent.opacity(0.5) : SQ.hairlineStrong, lineWidth: 0.5))
            }
            .buttonStyle(SQPlainButtonStyle())
        }
    }

    private func startRecording(_ action: String) {
        ShortcutRecorder.stop(recToken)
        recAction = action
        recToken = ShortcutRecorder.start(onCapture: { combo in
            Keymap.set(action, combo)
            recAction = nil
            recToken = nil
            keymapVersion += 1
            NotificationCenter.default.post(name: .keymapChanged, object: nil)
            model.showToast(L("keys.saved"))
        }, onCancel: {
            recAction = nil
            recToken = nil
        }, onInvalid: {
            recAction = nil
            recToken = nil
            model.showToast(L("keys.needmod"), isError: true)
        })
    }
}

// MARK: - Settings group / row

private struct SQSettingsGroup<Content: View>: View {
    let title: String
    var desc: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        SQCard {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14.5, weight: .bold))
                    if let desc {
                        Text(desc).font(.system(size: 12)).foregroundStyle(SQ.text2).lineLimit(3)
                    }
                }
                .padding(.vertical, 12)
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
            }
            .padding(.horizontal, SQ.pad)
        }
    }
}

private struct SQSettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 168, alignment: .leading)
            HStack(spacing: 8) { content() }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 11)
    }
}

extension SQ {
    static let monoFontName = "SFMono"
}
