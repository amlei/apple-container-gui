import AppKit
import SwiftUI

// MARK: - Sheet scaffold

struct SQSheet<Content: View>: View {
    let title: String
    let submit: String
    let submitIcon: String
    let onSubmit: () async -> String?
    let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var err: String?

    init(title: String, submit: String, submitIcon: String = "checkmark",
         @ViewBuilder content: @escaping () -> Content,
         onSubmit: @escaping () async -> String?) {
        self.title = title
        self.submit = submit
        self.submitIcon = submitIcon
        self.content = content
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 20)
                .padding(.horizontal, 22)
            ScrollView { content() }
                .padding(.top, 12)
                .padding(.horizontal, 22)
                .frame(maxHeight: 620)
            if let err {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(SQ.red)
                    .lineLimit(3)
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
            }
            HStack(spacing: 8) {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                SQButton(title: L("act.cancel")) { dismiss() }
                SQButton(title: submit, icon: submitIcon, primary: true) { submitTap() }
            }
            .padding(.top, 14)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .frame(width: 560)
    }

    private func submitTap() {
        guard !busy else { return }
        busy = true
        err = nil
        Task {
            let e = await onSubmit()
            busy = false
            if let e { err = e } else { dismiss() }
        }
    }
}

// MARK: - Form controls

struct SQField: View {
    let label: String
    var placeholder = ""
    @Binding var text: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(SQ.text2)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(mono ? SQ.mono : .system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(SQ.fill1))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(SQ.hairline, lineWidth: 0.5))
        }
    }
}

struct SQSelect: View {
    let label: String
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(SQ.text2)
            Picker("", selection: $selection) {
                ForEach(options.indices, id: \.self) { i in Text(options[i]).tag(i) }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SQTog: View {
    let label: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .frame(width: 28)
            Text(label).font(.system(size: 12))
            Spacer()
        }
    }
}

struct SQStepper: View {
    let label: String
    @Binding var value: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(SQ.text2)
            HStack(spacing: 6) {
                Button { value = max(1, value - 1) } label: {
                    Image(systemName: "minus").font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                Text("\(value)").font(.system(size: 13, weight: .medium)).monospacedDigit().frame(width: 28)
                Button { value = min(16, value + 1) } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct SQKVEditor: View {
    let keyPh: String
    let valuePh: String
    @Binding var rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    TextField(keyPh, text: $rows[i].0)
                        .textFieldStyle(.plain)
                        .font(SQ.mono)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SQ.fill1))
                    TextField(valuePh, text: $rows[i].1)
                        .textFieldStyle(.plain)
                        .font(SQ.mono)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SQ.fill1))
                    Button { rows.remove(at: i) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(SQ.text3)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                rows.append(("", ""))
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text(L("act.add")).font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(SQ.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Sheets

struct SQRunSheet: View {
    let prefillImage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: SQAppModel

    @State private var image = ""
    @State private var name = ""
    @State private var cmd = ""
    @State private var workdir = ""
    @State private var cpus = 2
    @State private var memIdx = 1
    @State private var netName = "default"
    @State private var ports: [(String, String)] = []
    @State private var vols: [(String, String)] = []
    @State private var env: [(String, String)] = []
    @State private var initProc = false
    @State private var rosetta = false
    @State private var readOnly = false
    @State private var autoRemove = false
    @State private var tty = false
    @State private var networks: [String] = ["default"]

    init(prefillImage: String? = nil) {
        self.prefillImage = prefillImage
        _image = State(initialValue: prefillImage ?? "")
    }

    var body: some View {
        SQSheet(title: L("run.title"), submit: L("run.submit"), submitIcon: "play.fill") {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("run.image") + " *", placeholder: L("run.image.ph"), text: $image, mono: true)
                HStack(spacing: 10) {
                    SQField(label: L("run.name"), placeholder: L("run.name.ph"), text: $name)
                    SQField(label: L("run.workdir"), placeholder: "/app", text: $workdir, mono: true)
                }
                SQField(label: L("run.cmd"), placeholder: L("run.cmd.ph"), text: $cmd, mono: true)
                HStack(spacing: 12) {
                    SQStepper(label: L("run.cpus"), value: $cpus)
                    SQSelect(label: L("run.memory"), options: ["512 MB", "1 GB", "2 GB", "4 GB", "8 GB"], selection: $memIdx)
                    SQSelect(label: L("run.net"), options: networks, selection: Binding(
                        get: { networks.firstIndex(of: netName) ?? 0 },
                        set: { netName = networks[$0] }
                    ))
                }
                SQKVEditor(keyPh: L("run.port.ph.host"), valuePh: L("run.port.ph.ct"), rows: $ports)
                    .padding(.top, 4)
                SQKVEditor(keyPh: L("run.vol.ph.host"), valuePh: L("run.vol.ph.ct"), rows: $vols)
                SQKVEditor(keyPh: L("run.env.k"), valuePh: L("run.env.v"), rows: $env)
                SQTog(label: L("run.opt.init"), isOn: $initProc)
                SQTog(label: L("run.opt.rosetta"), isOn: $rosetta)
                SQTog(label: L("run.opt.ro"), isOn: $readOnly)
                SQTog(label: L("run.opt.rm"), isOn: $autoRemove)
                SQTog(label: L("run.opt.tty"), isOn: $tty)
            }
        } onSubmit: {
            guard !image.trimmingCharacters(in: .whitespaces).isEmpty else { return L("run.err.image") }
            let memv = ["512 MB", "1 GB", "2 GB", "4 GB", "8 GB"][memIdx].replacingOccurrences(of: " ", with: "").lowercased()
            var spec = RunSpec(
                image: image.trimmingCharacters(in: .whitespaces),
                name: name.isEmpty ? nil : name,
                cmd: cmd.isEmpty ? nil : cmd,
                cpus: cpus,
                memory: memv,
                network: netName,
                workdir: workdir.isEmpty ? nil : workdir)
            spec.ports = ports.filter { !$0.0.isEmpty && !$0.1.isEmpty }
            spec.volumes = vols.filter { !$0.0.isEmpty && !$0.1.isEmpty }
            spec.env = env.filter { !$0.0.isEmpty }
            spec.initProc = initProc
            spec.rosetta = rosetta
            spec.readOnly = readOnly
            spec.autoRemove = autoRemove
            spec.tty = tty
            do {
                try await Commands.runContainer(spec)
                model.showToast((spec.name ?? spec.image) + " · " + L("st.running"))
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
        .onAppear {
            Task {
                let nets = await Commands.listNetworks()
                networks = ["default"] + nets.filter { !$0.isSystem }.map(\.name)
            }
        }
    }
}

struct SQPullSheet: View {
    @EnvironmentObject private var model: SQAppModel
    @State private var ref = ""
    @State private var platformIdx = 0

    var body: some View {
        SQSheet(title: L("pull.title"), submit: L("pull.begin"), submitIcon: "arrow.down") {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("pull.ref") + " *", placeholder: L("pull.ref.ph"), text: $ref, mono: true)
                SQSelect(label: L("pull.platform"), options: [L("pull.platform.auto"), "linux/arm64", "linux/amd64"], selection: $platformIdx)
            }
        } onSubmit: {
            guard !ref.trimmingCharacters(in: .whitespaces).isEmpty else { return L("run.err.image") }
            do {
                try await Commands.pullImage(ref.trimmingCharacters(in: .whitespaces), platform: platformIdx == 0 ? nil : ["linux/arm64", "linux/amd64"][platformIdx - 1])
                model.showToast(L("pull.doneMsg", ["ref": ref, "size": ""]))
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQBuildSheet: View {
    @EnvironmentObject private var model: SQAppModel
    @State private var dockerfile = "Dockerfile"
    @State private var context = "."
    @State private var tags = ""
    @State private var args: [(String, String)] = []
    @State private var target = ""
    @State private var noCache = false
    @State private var pull = false

    var body: some View {
        SQSheet(title: L("build.title"), submit: L("build.submit"), submitIcon: "hammer") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    SQField(label: L("build.dockerfile"), text: $dockerfile, mono: true)
                    SQField(label: L("build.context"), placeholder: ".", text: $context, mono: true)
                }
                SQField(label: L("build.tags") + " *", placeholder: L("build.tag.ph"), text: $tags, mono: true)
                SQKVEditor(keyPh: "KEY", valuePh: "value", rows: $args)
                SQField(label: L("build.target"), placeholder: L("build.target.ph"), text: $target, mono: true)
                SQTog(label: L("build.opt.nocache"), isOn: $noCache)
                SQTog(label: L("build.opt.pull"), isOn: $pull)
            }
        } onSubmit: {
            let t = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !t.isEmpty else { return L("run.err.image") }
            var spec = BuildSpec(dockerfile: dockerfile, context: context.isEmpty ? "." : context, tags: t)
            spec.buildArgs = args.filter { !$0.0.isEmpty }
            spec.target = target.isEmpty ? nil : target
            spec.noCache = noCache
            spec.pull = pull
            do {
                try await Commands.buildImage(spec)
                model.showToast(L("build.doneMsg", ["ref": t[0], "size": ""]))
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQNewVolumeSheet: View {
    @EnvironmentObject private var model: SQAppModel
    @State private var name = ""
    @State private var size = ""
    @State private var unit = 0
    @State private var journal = 0

    var body: some View {
        SQSheet(title: L("vol.new.title"), submit: L("act.create")) {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("vol.new.name") + " *", placeholder: L("vol.new.name.ph"), text: $name, mono: true)
                HStack(spacing: 10) {
                    SQField(label: L("vol.new.size"), placeholder: "10", text: $size)
                    SQSelect(label: "unit", options: ["GB", "MB", "TB"], selection: $unit)
                }
                SQSelect(label: L("vol.new.journal"), options: [L("journal.none"), L("journal.ordered"), L("journal.writeback"), L("journal.journal")], selection: $journal)
            }
        } onSubmit: {
            let n = name.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { return L("run.err.image") }
            let sizeStr: String? = Double(size).flatMap { $0 > 0 ? "\($0)\(["GB", "MB", "TB"][unit].first!)" : nil }
            let j = ["", "ordered", "writeback", "journal"][journal]
            do {
                try await Commands.createVolume(name: n, size: sizeStr, journal: j.isEmpty ? nil : j)
                model.showToast(n + " · " + L("vol.new.title"))
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQNewNetworkSheet: View {
    @EnvironmentObject private var model: SQAppModel
    @State private var name = ""
    @State private var s4 = ""
    @State private var s6 = ""
    @State private var internalOnly = false

    var body: some View {
        SQSheet(title: L("net.new.title"), submit: L("act.create")) {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("net.new.name") + " *", placeholder: L("net.new.name.ph"), text: $name, mono: true)
                SQField(label: L("net.subnet4"), placeholder: L("net.new.sub4.ph"), text: $s4, mono: true)
                SQField(label: L("net.subnet6"), placeholder: L("net.new.sub6.ph"), text: $s6, mono: true)
                SQTog(label: L("net.new.internal"), isOn: $internalOnly)
            }
        } onSubmit: {
            let n = name.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { return L("run.err.image") }
            do {
                try await Commands.createNetwork(name: n, subnet4: s4.isEmpty ? nil : s4, subnet6: s6.isEmpty ? nil : s6, internalOnly: internalOnly)
                model.showToast(n + " · " + L("net.new.title"))
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQNewMachineSheet: View {
    @EnvironmentObject private var model: SQAppModel
    @State private var image = "alpine:3.22"
    @State private var name = ""
    @State private var cpus = 4
    @State private var memIdx = 2
    @State private var home = 0
    @State private var virt = false
    @State private var setDefault = false

    var body: some View {
        SQSheet(title: L("mach.new.title"), submit: L("act.create")) {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("mach.new.image") + " *", placeholder: "alpine:3.22", text: $image, mono: true)
                SQField(label: L("mach.new.name"), placeholder: L("mach.new.name.ph"), text: $name, mono: true)
                HStack(spacing: 12) {
                    SQStepper(label: L("mach.new.cpus"), value: $cpus)
                    SQSelect(label: L("mach.new.mem"), options: ["2 GB", "4 GB", "8 GB", "16 GB"], selection: $memIdx)
                }
                SQSelect(label: L("mach.new.home"), options: [L("mach.home.rw"), L("mach.home.ro"), L("mach.home.none")], selection: $home)
                SQTog(label: L("mach.new.virt"), isOn: $virt)
                SQTog(label: L("mach.new.def"), isOn: $setDefault)
            }
        } onSubmit: {
            guard !image.isEmpty else { return L("run.err.image") }
            let spec = MachineSpec(
                image: image,
                name: name.isEmpty ? nil : name,
                cpus: cpus,
                memory: ["2 GB", "4 GB", "8 GB", "16 GB"][memIdx].replacingOccurrences(of: " ", with: "").lowercased(),
                homeMount: ["rw", "ro", "none"][home],
                virtualization: virt,
                setDefault: setDefault,
                kernelPath: nil)
            do {
                try await Commands.createMachine(spec)
                model.showToast((spec.name ?? image) + " · " + L("st.running"))
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQNewClusterSheet: View {
    @EnvironmentObject private var model: SQAppModel
    @State private var name = "k8s-dev"
    @State private var image = "docker.io/kindest/node:v1.35.5"
    @State private var cpus = 4
    @State private var memIdx = 2
    @State private var autoRemove = false

    var body: some View {
        SQSheet(title: L("k8.new.title"), submit: L("act.create")) {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("k8.new.name") + " *", placeholder: L("k8.new.name.ph"), text: $name, mono: true)
                SQField(label: L("k8.new.image"), placeholder: L("k8.new.image.ph"), text: $image, mono: true)
                HStack(spacing: 12) {
                    SQStepper(label: L("mach.new.cpus"), value: $cpus)
                    SQSelect(label: L("mach.new.mem"), options: ["2 GB", "4 GB", "8 GB", "16 GB"], selection: $memIdx)
                }
                SQTog(label: L("k8.new.rm"), isOn: $autoRemove)
                Text(L("k8.exp.note")).font(.system(size: 11)).foregroundStyle(SQ.text3)
            }
        } onSubmit: {
            let n = name.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { return L("run.err.image") }
            let spec = K8sSpec(
                name: n,
                nodeImage: image.isEmpty ? nil : image,
                cpus: cpus,
                memory: ["2 GB", "4 GB", "8 GB", "16 GB"][memIdx].replacingOccurrences(of: " ", with: "").lowercased(),
                autoRemove: autoRemove)
            do {
                model.showToast(L("k8.create.ok", ["n": n]))
                try await Commands.k8sCreate(spec)
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQRegistryLoginSheet: View {
    @EnvironmentObject private var model: SQAppModel
    @State private var server = ""
    @State private var user = ""
    @State private var password = ""

    var body: some View {
        SQSheet(title: L("set.reg.login.title"), submit: L("act.login"), submitIcon: "key") {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("set.reg.login.server") + " *", placeholder: L("set.reg.login.server.ph"), text: $server, mono: true)
                SQField(label: L("set.reg.login.user"), text: $user)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("set.reg.login.pass")).font(.system(size: 12, weight: .medium)).foregroundStyle(SQ.text2)
                    SecureField("", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(SQ.fill1))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(SQ.hairline, lineWidth: 0.5))
                }
            }
        } onSubmit: {
            guard !server.trimmingCharacters(in: .whitespaces).isEmpty else { return L("run.err.image") }
            do {
                try await Commands.registryLogin(server: server.trimmingCharacters(in: .whitespaces), user: user.isEmpty ? nil : user, password: password)
                model.showToast(server + " · " + L("act.login"))
                Store.shared.refreshSystemInfo()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQTagImageSheet: View {
    let source: String
    @EnvironmentObject private var model: SQAppModel
    @State private var target = ""

    var body: some View {
        SQSheet(title: L("tagd.title"), submit: L("act.confirm")) {
            VStack(alignment: .leading, spacing: 12) {
                SQField(label: L("tagd.source"), text: .constant(source), mono: true)
                    .disabled(true)
                SQField(label: L("tagd.target"), placeholder: L("tagd.target.ph"), text: $target, mono: true)
            }
        } onSubmit: {
            guard !target.isEmpty else { return L("run.err.image") }
            do {
                try await Commands.tagImage(source, target)
                model.showToast("\(target) ← \(source)")
                Store.shared.refresh()
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQLoadImageSheet: View {
    let clusterName: String
    @EnvironmentObject private var model: SQAppModel
    @State private var ref = ""

    var body: some View {
        SQSheet(title: L("k8.loadimg.title", ["n": clusterName]), submit: L("k8.loadimg.short"), submitIcon: "arrow.up") {
            SQField(label: L("k8.loadimg.ref") + " *", placeholder: L("k8.loadimg.ph"), text: $ref, mono: true)
        } onSubmit: {
            guard !ref.isEmpty else { return L("run.err.image") }
            do {
                try await Commands.k8sLoadImage(clusterName, image: ref)
                model.showToast(L("k8.loadimg.doneMsg", ["img": ref, "n": clusterName]))
                return nil
            } catch { return error.localizedDescription }
        }
    }
}

struct SQSystemLogsSheet: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("set.syslogs")).font(.system(size: 16, weight: .bold))
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.containers.prefix(20), id: \.id) { c in
                        Text("[\(c.id)] \(c.imageRef) · \(c.status.state?.rawValue ?? "—")")
                            .font(SQ.monoSmall)
                            .foregroundStyle(SQ.text2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.106, green: 0.114, blue: 0.133)))
            }
            .frame(height: 320)
            HStack { Spacer(); SQButton(title: L("act.close")) { dismiss() } }
        }
        .padding(20)
        .frame(width: 560)
    }
}

// MARK: - Sheet router

struct SQSheetView: View {
    let sheet: SQSheetKind

    var body: some View {
        switch sheet {
        case .run(let img): SQRunSheet(prefillImage: img)
        case .pull: SQPullSheet()
        case .build: SQBuildSheet()
        case .newVolume: SQNewVolumeSheet()
        case .newNetwork: SQNewNetworkSheet()
        case .newMachine: SQNewMachineSheet()
        case .k8sNew: SQNewClusterSheet()
        case .registryLogin: SQRegistryLoginSheet()
        case .tag(let img): SQTagImageSheet(source: img)
        case .loadImage(let cluster): SQLoadImageSheet(clusterName: cluster)
        case .systemLogs: SQSystemLogsSheet()
        }
    }
}
