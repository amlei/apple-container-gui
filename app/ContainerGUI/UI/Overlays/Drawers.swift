import AppKit
import SwiftUI

// MARK: - Drawer chrome

struct SQDrawerPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @EnvironmentObject private var model: SQAppModel
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(SQ.monoSmall)
                        .foregroundStyle(SQ.text2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.closeDrawer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SQ.text2)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SQ.fill1))
                }
                .buttonStyle(SQPlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 472)
        .frame(maxHeight: .infinity)
        .background(SQ.contentBg)
        .overlay(Rectangle().frame(width: 0.5).foregroundStyle(SQ.hairlineStrong), alignment: .leading)
        .shadow(color: .black.opacity(0.25), radius: 30, x: -8, y: 0)
    }
}

// MARK: - Drawer tabs

struct SQDrawerTabs: View {
    let tabs: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = i }
                } label: {
                    Text(tabs[i])
                        .font(.system(size: 12.5, weight: selection == i ? .semibold : .medium))
                        .foregroundStyle(selection == i ? SQ.text : SQ.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == i ? SQ.cardBg : Color.clear)
                        )
                }
                .buttonStyle(SQPlainButtonStyle())
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SQ.fill1))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SQ.hairline, lineWidth: 0.5))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }
}

// MARK: - Container drawer

struct ContainerDrawerView: View {
    let containerID: String
    @State private var tab = 0
    @EnvironmentObject private var model: SQAppModel

    private var container: ManagedContainer? {
        Store.shared.containers.first { $0.id == containerID }
    }

    var body: some View {
        if let c = container {
            SQDrawerPanel(title: c.id, subtitle: "\(c.imageRef) · \(c.ip)") {
                VStack(spacing: 0) {
                    SQDrawerTabs(tabs: [L("ct.tab.info"), L("ct.tab.logs"), L("ct.tab.stats"), L("ct.tab.term")], selection: $tab)
                    ScrollView {
                        Group {
                            switch tab {
                            case 0: ContainerInfoTab(container: c)
                            case 1: ContainerLogTab(container: c)
                            case 2: ContainerStatsTab(container: c)
                            default: SQTerminal(host: c.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        } else {
            SQDrawerPanel(title: containerID, subtitle: "") {
                Text(L("ct.d.none")).foregroundStyle(SQ.text3).padding()
            }
        }
    }
}

private struct ContainerInfoTab: View {
    let container: ManagedContainer
    @EnvironmentObject private var model: SQAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if container.isRunning {
                    SQButton(title: L("act.stop"), icon: "stopfill", small: true) {
                        Task {
                            try? await Commands.containerAction("stop", ids: [container.id])
                            Store.shared.refresh()
                        }
                    }
                    SQButton(title: L("act.kill"), icon: "bolt.fill", danger: true, small: true) {
                        model.confirm(L("kill.title", ["id": container.id]), message: L("kill.msg"), confirm: L("confirm.kill"), danger: true) {
                            Task {
                                try? await Commands.containerAction("kill", ids: [container.id])
                                Store.shared.refresh()
                            }
                        }
                    }
                } else {
                    SQButton(title: L("act.start"), icon: "play.fill", small: true) {
                        Task {
                            try? await Commands.containerAction("start", ids: [container.id])
                            Store.shared.refresh()
                        }
                    }
                }
                SQButton(title: L("ct.ip"), icon: "doc.on.doc", small: true) {
                    let v = container.ip
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(v, forType: .string)
                    model.showToast(L("copied"))
                }
                SQButton(title: L("act.exportFs"), icon: "square.and.arrow.up", small: true) {
                    let id = container.id
                    let dlg = NSSavePanel()
                    dlg.nameFieldStringValue = id + ".tar"
                    if let w = NSApp.keyWindow {
                        dlg.beginSheetModal(for: w) { resp in
                            guard resp == .OK, let url = dlg.url else { return }
                            Task {
                                try? await Commands.exportContainer(id, to: url.path)
                                model.showToast(L("export.doneMsg", ["path": url.path]))
                            }
                        }
                    }
                }
            }

            let archText = container.configuration.platform.map { "\($0.os)/\($0.architecture)" } ?? "—"
            let resourceText = container.configuration.resources.map {
                "\($0.cpus ?? 0) CPU · \(Fmt.bytes($0.memoryInBytes))"
            } ?? "—"
            let portsText = container.portPairs.isEmpty
                ? L("ct.d.none")
                : container.portPairs.map { "\($0.host):\($0.ct)/\($0.proto)" }.joined(separator: "\n")
            SQKV(monoValue: true, rows: [
                (L("ct.d.id"), container.id),
                (L("ct.image"), container.imageRef),
                (L("ct.status"), statusText),
                (L("ct.d.arch"), archText),
                (L("ct.d.cmd"), container.commandText),
                (L("run.net"), container.networkName),
                (L("ct.ports"), portsText),
                (L("run.res"), resourceText),
                (L("ct.d.workdir"), container.workdirText),
                (L("ct.d.user"), container.userText),
                (L("ct.created"), Fmt.dateTime(container.createdDate ?? container.status.startedDate)),
            ])

            SQDisclosure(L("ct.d.env"), open: true) {
                if container.envPairs.isEmpty {
                    SQKV(monoValue: true, rows: [(L("ct.d.none"), "")])
                } else {
                    SQKV(monoValue: true, rows: container.envPairs)
                }
            }
            SQDisclosure(L("ct.d.mounts")) {
                if container.mountPairs.isEmpty {
                    SQKV(monoValue: true, rows: [(L("ct.d.none"), "")])
                } else {
                    SQKV(monoValue: true, rows: container.mountPairs.map { ($0.src, "→ \($0.dst)") })
                }
            }
            if !container.optionFlags.isEmpty {
                SQDisclosure(L("ct.d.options")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(Array(container.optionFlags.enumerated()), id: \.offset) { _, flag in
                                SQBadge(text: flag, accent: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 12)
    }

    private var statusText: String {
        let state = container.status.state
        if container.isRunning { return L("st.running") }
        switch state {
        case .stopped: return L("st.exited")
        case .created: return L("st.created")
        case .running: return L("st.running")
        case .unknown: return L("st.exited")
        case nil: return "—"
        }
    }
}

private struct ContainerLogTab: View {
    let container: ManagedContainer
    @State private var follow = true
    @State private var boot = false
    @State private var tail = 0
    @State private var lines: [String] = []
    @State private var handle: ProcessHandle?
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Toggle(isOn: $follow) { }
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)
                    .frame(width: 24)
                Text(L("logs.follow")).font(.system(size: 12))
                Toggle(isOn: $boot) { }
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)
                    .frame(width: 24)
                Text(L("logs.boot")).font(.system(size: 12))
                Spacer()
                Picker("", selection: $tail) {
                    Text(L("logs.all")).tag(0)
                    Text("100").tag(100)
                    Text("500").tag(500)
                }
                .frame(width: 72)
                .controlSize(.small)
            }
            .padding(.top, 6)

            if loaded && lines.isEmpty {
                Text("—")
                    .font(SQ.monoSmall)
                    .foregroundStyle(SQ.text3)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SQ.fill1))
            } else {
                SQLogView(lines: lines)
            }
        }
        .onAppear { start() }
        .onDisappear { handle?.terminate() }
        .onChange(of: follow) { _ in start() }
        .onChange(of: boot) { _ in start() }
        .onChange(of: tail) { _ in start() }
    }

    private func start() {
        handle?.terminate()
        handle = nil
        lines = []
        loaded = false
        handle = Commands.containerLogsStream(id: container.id, tail: tail, boot: boot, follow: follow) { line in
            DispatchQueue.main.async {
                loaded = true
                lines.append(line)
                if lines.count > 800 { lines.removeFirst(lines.count - 800) }
            }
        }
    }
}

private struct ContainerStatsTab: View {
    let container: ManagedContainer
    @State private var cpuHist: [Double] = []
    @State private var memHist: [Double] = []
    @State private var netHist: [Double] = []
    @State private var snapshot: ContainerStatsSnapshot?
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let cpu = snapshot?.cpuPercent ?? 0
            let mem = snapshot?.memoryUsageBytes ?? 0
            let limit = snapshot?.memoryLimitBytes ?? 0
            let rx = snapshot?.networkRxBytes ?? 0
            let tx = snapshot?.networkTxBytes ?? 0
            chartBox(title: L("stats.cpu"), value: String(format: "%.1f%%", cpu)) {
                SQSparkline(values: cpuHist)
            }
            chartBox(title: L("stats.mem"), value: "\(Fmt.bytes(mem)) / \(Fmt.bytes(limit))") {
                SQSparkline(values: memHist, color: SQ.purple)
            }
            chartBox(title: L("stats.net"), value: "\(Fmt.bytes(rx))/s ↓ · \(Fmt.bytes(tx))/s ↑") {
                SQSparkline(values: netHist, color: SQ.teal)
            }
            SQKV(rows: [
                (L("stats.pids"), "\(snapshot?.numProcesses ?? 0)"),
                (L("stats.block") + " " + L("stats.read").lowercased(), Fmt.bytes(snapshot?.blockReadBytes)),
                (L("stats.block") + " " + L("stats.write").lowercased(), Fmt.bytes(snapshot?.blockWriteBytes)),
            ])
        }
        .padding(.top, 12)
        .onAppear { startSampling() }
        .onDisappear { timer?.invalidate() }
    }

    @ViewBuilder private func chartBox<C: View>(title: String, value: String, @ViewBuilder chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(SQ.text2).textCase(.uppercase)
                Spacer()
                Text(value).font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            chart().frame(height: 88)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SQ.fill1))
    }

    private func startSampling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task {
                if let s = await Commands.stats(id: container.id) {
                    await MainActor.run {
                        snapshot = s
                        cpuHist.append(s.cpuPercent)
                        memHist.append(Double(s.memoryUsageBytes ?? 0))
                        netHist.append(Double(s.networkRxBytes ?? 0) + Double(s.networkTxBytes ?? 0))
                        for arr in [cpuHist, memHist, netHist] {
                            if arr.count > 40 { _ = arr.dropFirst(arr.count - 40) }
                        }
                    }
                }
            }
        }
        timer?.fire()
    }
}

// MARK: - Image drawer

struct ImageDrawerView: View {
    let ref: String
    @EnvironmentObject private var model: SQAppModel

    private var image: ImageResourceJSON? { Store.shared.images.first { $0.ref == ref } }
    private var usedBy: [String] {
        guard let img = image else { return [] }
        return Store.shared.containers.filter { $0.imageRef == img.ref }.map(\.id)
    }

    var body: some View {
        if let img = image {
            SQDrawerPanel(title: img.ref, subtitle: img.id) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            SQButton(title: L("act.runContainer"), icon: "play.fill", small: true) { model.show(.run(image: img.ref)) }
                            SQButton(title: L("act.push"), icon: "arrow.up", small: true) {
                                Task { try? await Commands.pushImage(img.ref); model.showToast(L("push.doneMsg", ["ref": img.ref])) }
                            }
                            SQButton(title: L("act.tagNew"), icon: "tag", small: true) { model.show(.tag(image: img.ref)) }
                            SQButton(title: L("act.saveTar"), icon: "arrow.down", small: true) {
                                let dlg = NSSavePanel()
                                dlg.nameFieldStringValue = img.ref.components(separatedBy: "/").last?.replacingOccurrences(of: ":", with: "_").appending(".tar") ?? "image.tar"
                                if let w = NSApp.keyWindow {
                                    dlg.beginSheetModal(for: w) { resp in
                                        guard resp == .OK, let url = dlg.url else { return }
                                        Task {
                                            try? await Commands.saveImage(img.ref, to: url.path)
                                            model.showToast(L("saved.doneMsg", ["path": url.path]))
                                        }
                                    }
                                }
                            }
                        }
                        SQKV(monoValue: true, rows: [
                            ("ID", img.id),
                            (L("img.size"), Fmt.bytes(img.sizeBytes)),
                            (L("img.osarch"), "linux/\(img.arch)"),
                            (L("img.usedBy"), usedBy.isEmpty ? L("ct.d.none") : usedBy.joined(separator: ", ")),
                            (L("img.created"), Fmt.dateTime(img.configuration.creationDate)),
                        ])

                        if !img.layers.isEmpty {
                            SQDisclosure("\(L("pull.layers")) · \(img.layers.count)") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(img.layers.enumerated()), id: \.offset) { _, layer in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text(layer.cmd)
                                                .font(SQ.mono)
                                                .foregroundStyle(SQ.text)
                                                .lineLimit(2)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(SQ.fill1)
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)
                }
            }
        } else {
            SQDrawerPanel(title: ref, subtitle: "") { Text(L("ct.d.none")).foregroundStyle(SQ.text3).padding() }
        }
    }
}

// MARK: - Volume drawer

struct VolumeDrawerView: View {
    let name: String
    @EnvironmentObject private var model: SQAppModel

    private var volume: VolumeResourceJSON? { Store.shared.volumes.first { $0.name == name } }
    private var attached: [String] {
        Store.shared.containers
            .filter { c in c.mountPairs.contains { $0.src == name } }
            .map(\.id)
    }

    var body: some View {
        if let v = volume {
            SQDrawerPanel(title: v.name, subtitle: "driver: \(v.configuration.driver ?? "default")") {
                ScrollView {
                    SQKV(monoValue: true, rows: [
                        (L("vol.size"), v.configuration.sizeInBytes.map { Fmt.bytes($0) } ?? L("ct.d.none")),
                        (L("vol.journal"), v.journalMode ?? "default"),
                        (L("vol.attached"), attached.isEmpty ? L("ct.d.none") : attached.joined(separator: ", ")),
                        (L("vol.created"), Fmt.dateTime(v.configuration.creationDate)),
                    ])
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        } else {
            SQDrawerPanel(title: name, subtitle: "") { Text(L("ct.d.none")).foregroundStyle(SQ.text3).padding() }
        }
    }
}

// MARK: - Machine shell drawer

struct MachineShellDrawerView: View {
    let name: String
    @EnvironmentObject private var model: SQAppModel

    var body: some View {
        SQDrawerPanel(title: name, subtitle: "container machine run -n \(name)") {
            VStack {
                SQTerminal(host: name)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                Spacer()
            }
        }
    }
}

// MARK: - Machine logs drawer

struct MachineLogsDrawerView: View {
    let name: String
    @State private var follow = true
    @State private var lines: [String] = []

    var body: some View {
        SQDrawerPanel(title: name, subtitle: "container machine logs") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Toggle(isOn: $follow) {}
                        .toggleStyle(.switch)
                        .scaleEffect(0.75)
                        .frame(width: 24)
                    Text(L("logs.follow")).font(.system(size: 12))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                SQLogView(lines: lines)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .task {
                let out = await Commands.machineLogs(name)
                lines = out.components(separatedBy: "\n").filter { !$0.isEmpty }
            }
        }
    }
}

// MARK: - Log view (dark terminal look)

struct SQLogView: View {
    let lines: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if !hasLeadingTimestamp(line) {
                        Text(timeLabel(line))
                            .foregroundStyle(SQ.text3)
                    }
                    Text(line)
                        .foregroundStyle(Color(red: 0.84, green: 0.84, blue: 0.86))
                }
                .font(SQ.monoSmall)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.106, green: 0.114, blue: 0.133))
        )
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .frame(minHeight: 260)
    }

    private func timeLabel(_ line: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private func hasLeadingTimestamp(_ line: String) -> Bool {
        guard line.count >= 10 else { return false }
        let chars = Array(line)
        return chars[0].isNumber && chars[1].isNumber && chars[2].isNumber && chars[3].isNumber && chars[4] == "-"
    }
}

// MARK: - Mini terminal (local shell, mirrors prototype)

struct SQTerminal: View {
    let host: String
    @State private var lines: [String] = []
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                            Text(l).font(SQ.mono).foregroundStyle(Color(red: 0.84, green: 0.84, blue: 0.86)).id(l)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .onChange(of: lines.count) { _ in
                    if let last = lines.last { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .frame(minHeight: 220)

            HStack(spacing: 8) {
                Text("\(host):/#")
                    .font(SQ.mono)
                    .foregroundStyle(Color(red: 0.47, green: 0.77, blue: 0.49))
                    .fixedSize()
                TextField("", text: $input)
                    .textFieldStyle(.plain)
                    .font(SQ.mono)
                    .foregroundStyle(Color(red: 0.95, green: 0.95, blue: 0.96))
                    .focused($focused)
                    .onSubmit(run)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Rectangle().fill(Color(red: 0.09, green: 0.10, blue: 0.12)))
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.white.opacity(0.08)), alignment: .top)
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.106, green: 0.114, blue: 0.133)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            lines = [
                "container exec -it \(host) /bin/sh",
                L("term.help"),
            ]
            focused = true
        }
    }

    private func run() {
        let raw = input.trimmingCharacters(in: .whitespaces)
        lines.append("\(host):/# \(raw)")
        input = ""
        guard !raw.isEmpty else { return }
        let parts = raw.split(separator: " ")
        let cmd = String(parts.first ?? "")
        let rest = String(parts.dropFirst().joined(separator: " "))
        switch cmd {
        case "help": lines.append("ls  ps  pwd  whoami  uname -a  cat <file>  echo <text>  df  free  clear  exit")
        case "clear": lines = []
        case "pwd": lines.append("/")
        case "whoami": lines.append("root")
        case "uname": lines.append("Linux \(host) 6.18.35 #1 SMP PREEMPT arm64 GNU/Linux")
        case "ls": lines.append("bin   dev   etc   home   proc   root   tmp   usr   var")
        case "ps": lines.append("PID   USER     TIME   COMMAND\n    1 root     0:00   /sbin/init")
        case "cat":
            if rest.contains("os-release") { lines.append("NAME=\"Alpine Linux\"\nID=alpine\nVERSION_ID=3.22.0") }
            else if rest.contains("hostname") { lines.append(host) }
            else { lines.append("cat: can't open '\(rest.isEmpty ? "?" : rest)': No such file or directory") }
        case "echo": lines.append(rest.replacingOccurrences(of: "\"", with: ""))
        case "df": lines.append("Filesystem           Size      Used Available Use% Mounted on\noverlay              9.8G      1.2G      8.6G  12% /")
        case "free": lines.append("            total       used       free\nMem:        1010564     213120     797444")
        case "exit": lines.append("exit")
        default: lines.append("sh: \(cmd): not found")
        }
    }
}

// MARK: - Sparkline

struct SQSparkline: View {
    let values: [Double]
    var color: Color = SQ.accent

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxV = max(values.max() ?? 1, 1)
            Path { p in
                guard values.count > 1 else { return }
                for i in values.indices {
                    let x = CGFloat(i) / CGFloat(values.count - 1) * w
                    let y = h - CGFloat(values[i] / maxV) * (h - 4) - 2
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, lineWidth: 1.8)
        }
    }
}
