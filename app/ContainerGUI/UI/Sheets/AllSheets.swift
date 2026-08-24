import AppKit

@MainActor
class SheetViewController: NSViewController {
    let body = stackV([], spacing: 10)
    let submitButton: NSButton
    private let submitAction: (SheetViewController) async -> Bool
    private let titleText: String
    private var progressIndicator: NSProgressIndicator?

    init(title: String, submitTitle: String, submitSymbol: String = "checkmark", onSubmit: @escaping (SheetViewController) async -> Bool) {
        submitAction = onSubmit
        submitButton = makeButton(submitTitle, symbol: submitSymbol, primary: true)
        titleText = title
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 560, height: 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    private var extraConstraints: [NSLayoutConstraint] = []

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = makeLabel(titleText, font: .systemFont(ofSize: 16, weight: .bold))
        let cancel = makeButton(L("act.cancel"))
        cancel.target = self
        cancel.action = #selector(cancelTap)
        submitButton.target = self
        submitButton.action = #selector(submitTap)

        body.alignment = .leading
        body.translatesAutoresizingMaskIntoConstraints = false

        let footer = stackH([NSView(), cancel, submitButton], spacing: 8)
        footer.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(title)
        root.addSubview(body)
        root.addSubview(footer)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            body.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            body.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            footer.topAnchor.constraint(greaterThanOrEqualTo: body.bottomAnchor, constant: 16),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            root.widthAnchor.constraint(equalToConstant: 560),
        ])
        view = root
    }

    func addField(label: String, placeholder: String = "", value: String = "", mono: Bool = false) -> NSTextField {
        let f = NSTextField(string: value)
        f.placeholderString = placeholder
        f.font = mono ? .monospacedSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 13)
        f.translatesAutoresizingMaskIntoConstraints = false
        let group = fieldGroup(label, control: f)
        body.addArrangedSubview(group)
        group.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        return f
    }

    func addSelect(label: String, options: [String], selected: Int = 0) -> NSPopUpButton {
        let p = NSPopUpButton()
        p.addItems(withTitles: options)
        p.selectItem(at: selected)
        p.controlSize = .small
        p.font = .systemFont(ofSize: 12)
        p.translatesAutoresizingMaskIntoConstraints = false
        let group = fieldGroup(label, control: p)
        body.addArrangedSubview(group)
        group.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        return p
    }

    func addSwitch(label: String, isOn: Bool = false) -> NSSwitch {
        let sw = NSSwitch()
        sw.controlSize = .small
        sw.state = isOn ? .on : .off
        sw.translatesAutoresizingMaskIntoConstraints = false
        let row = stackH([makeLabel(label, font: .systemFont(ofSize: 12)), NSView(), sw], spacing: 8)
        row.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: body.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: body.trailingAnchor).isActive = true
        return sw
    }

    func addCustom(_ v: NSView, label: String? = nil) {
        v.translatesAutoresizingMaskIntoConstraints = false
        if let label {
            let group = fieldGroup(label, control: v)
            body.addArrangedSubview(group)
            group.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        } else {
            body.addArrangedSubview(v)
            v.leadingAnchor.constraint(equalTo: body.leadingAnchor).isActive = true
            v.trailingAnchor.constraint(equalTo: body.trailingAnchor).isActive = true
        }
    }

    private func fieldGroup(_ label: String, control: NSView) -> NSView {
        stackV([makeLabel(label, font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), control], spacing: 4)
    }

    func setError(_ message: String) {
        let l = NSTextField(wrappingLabelWithString: message)
        l.font = .systemFont(ofSize: 11)
        l.textColor = .systemRed
        addCustom(l)
    }

    func setBusy(_ busy: Bool) {
        submitButton.isEnabled = !busy
        if busy {
            let p = NSProgressIndicator()
            p.style = .spinning
            p.controlSize = .small
            p.startAnimation(nil)
            p.translatesAutoresizingMaskIntoConstraints = false
            body.addArrangedSubview(p)
            p.leadingAnchor.constraint(equalTo: body.leadingAnchor).isActive = true
            progressIndicator = p
        } else {
            progressIndicator?.removeFromSuperview()
        }
    }

    @objc private func cancelTap() { dismiss() }
    @objc private func submitTap() {
        setBusy(true)
        Task { @MainActor in
            let ok = await submitAction(self)
            setBusy(false)
            if ok { dismiss() }
        }
    }

    func dismiss() {
        view.window?.sheetParent?.endSheet(view.window!)
    }
}

// MARK: - Run Container

final class RunContainerSheet: SheetViewController {
    private var imageField: NSTextField!
    private var nameField: NSTextField!
    private var cmdField: NSTextField!
    private var workdirField: NSTextField!
    private var cpuOut: NSTextField!
    private var memSelect: NSPopUpButton!
    private var netSelect: NSPopUpButton!
    private var portsEditor: KVEditor!
    private var volsEditor: KVEditor!
    private var envEditor: KVEditor!
    private var swInit = NSSwitch(), swRosetta = NSSwitch(), swRO = NSSwitch(), swRm = NSSwitch(), swTty = NSSwitch()

    init(prefillImage: String = "") {
        super.init(title: L("run.title"), submitTitle: L("run.submit"), submitSymbol: "play.fill") { sheet in
            guard let s = sheet as? RunContainerSheet else { return false }
            let image = s.imageField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !image.isEmpty else { s.setError(L("run.err.image")); return false }
            let memValue = s.memSelect.titleOfSelectedItem ?? "1 GB"
            var spec = RunSpec(
                image: image,
                name: s.nameField.stringValue.isEmpty ? nil : s.nameField.stringValue,
                cmd: s.cmdField.stringValue.isEmpty ? nil : s.cmdField.stringValue,
                cpus: Int(s.cpuOut.stringValue),
                memory: memValue.replacingOccurrences(of: " ", with: "").lowercased(),
                network: s.netSelect.titleOfSelectedItem,
                workdir: s.workdirField.stringValue.isEmpty ? nil : s.workdirField.stringValue)
            spec.ports = s.portsEditor.collect().filter { !$0.0.isEmpty && !$0.1.isEmpty }
            spec.volumes = s.volsEditor.collect().filter { !$0.0.isEmpty && !$0.1.isEmpty }
            spec.env = s.envEditor.collect().filter { !$0.0.isEmpty }
            spec.initProc = s.swInit.state == .on
            spec.rosetta = s.swRosetta.state == .on
            spec.readOnly = s.swRO.state == .on
            spec.autoRemove = s.swRm.state == .on
            spec.tty = s.swTty.state == .on
            do {
                try await Commands.runContainer(spec)
                Toast.shared.show((spec.name ?? image) + " · " + L("st.running"))
                return true
            } catch {
                s.setError(error.localizedDescription)
                return false
            }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        imageField = addField(label: L("run.image") + " *", placeholder: L("run.image.ph"), value: prefill, mono: true)
        nameField = NSTextField(); nameField.placeholderString = L("run.name.ph")
        nameField.font = .systemFont(ofSize: 13)
        workdirField = NSTextField(); workdirField.placeholderString = "/app"
        workdirField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let nameCol = stackV([makeLabel(L("run.name"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), nameField], spacing: 4)
        let wdCol = stackV([makeLabel(L("run.workdir"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), workdirField], spacing: 4)
        let twoCol = stackH([nameCol, wdCol], spacing: 10)
        twoCol.distribution = .fillEqually
        addCustom(twoCol)

        cmdField = addField(label: L("run.cmd"), placeholder: L("run.cmd.ph"), mono: true)

        cpuOut = NSTextField(labelWithString: "2")
        cpuOut.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let minus = NSButton(title: "−", target: self, action: #selector(stepCpu(_:))); minus.isBordered = true; minus.bezelStyle = .rounded; minus.controlSize = .small; minus.tag = -1
        let plus = NSButton(title: "+", target: self, action: #selector(stepCpu(_:))); plus.isBordered = true; plus.bezelStyle = .rounded; plus.controlSize = .small; plus.tag = 1
        let cpuCol = stackV([makeLabel(L("run.cpus"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), stackH([minus, cpuOut, plus], spacing: 6)], spacing: 4)

        memSelect = NSPopUpButton()
        memSelect.addItems(withTitles: ["512 MB", "1 GB", "2 GB", "4 GB", "8 GB"])
        memSelect.selectItem(at: 1)
        memSelect.controlSize = .small
        let memCol = stackV([makeLabel(L("run.memory"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), memSelect], spacing: 4)

        netSelect = NSPopUpButton()
        netSelect.addItems(withTitles: ["default"])
        netSelect.controlSize = .small
        let netCol = stackV([makeLabel(L("run.net"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), netSelect], spacing: 4)

        let resRow = stackH([cpuCol, memCol, netCol], spacing: 12)
        addCustom(resRow)

        portsEditor = KVEditor(); portsEditor.setPlaceholders(L("run.port.ph.host"), L("run.port.ph.ct"))
        addCustom(portsEditor, label: L("run.ports"))
        volsEditor = KVEditor(); volsEditor.setPlaceholders(L("run.vol.ph.host"), L("run.vol.ph.ct"))
        addCustom(volsEditor, label: L("run.vols"))
        envEditor = KVEditor(); envEditor.setPlaceholders(L("run.env.k"), L("run.env.v"))
        addCustom(envEditor, label: L("run.env"))

        swInit = addSwitch(label: L("run.opt.init"))
        swRosetta = addSwitch(label: L("run.opt.rosetta"))
        swRO = addSwitch(label: L("run.opt.ro"))
        swRm = addSwitch(label: L("run.opt.rm"))
        swTty = addSwitch(label: L("run.opt.tty"))

        Task { @MainActor in
            let nets = await Commands.listNetworks()
            for n in nets where !n.isSystem { netSelect.addItem(withTitle: n.name) }
        }
    }

    private var prefill = ""
    convenience init(prefill: String) {
        self.init(prefillImage: prefill)
        self.prefill = prefill
    }

    @objc private func stepCpu(_ sender: NSButton) {
        let v = max(1, min(16, (Int(cpuOut.stringValue) ?? 2) + sender.tag))
        cpuOut.stringValue = "\(v)"
    }
}

// MARK: - Pull Image

final class PullImageSheet: SheetViewController {
    private var refField: NSTextField!
    private var platformSelect: NSPopUpButton!
    private var logView: NSTextView!

    init() {
        super.init(title: L("pull.title"), submitTitle: L("pull.begin"), submitSymbol: "arrow.down") { sheet in
            guard let s = sheet as? PullImageSheet else { return false }
            let ref = s.refField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !ref.isEmpty else { s.setError(L("run.err.image")); return false }
            do {
                try await CLIRunner.run(["image", "pull", "--progress", "plain", ref])
                Toast.shared.show(L("pull.doneMsg", ["ref": ref, "size": ""]))
                return true
            } catch {
                s.setError(error.localizedDescription)
                return false
            }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        refField = addField(label: L("pull.ref") + " *", placeholder: L("pull.ref.ph"), mono: true)
        platformSelect = addSelect(label: L("pull.platform"), options: [L("pull.platform.auto"), "linux/arm64", "linux/amd64"])

        let scroll = NSScrollView()
        logView = NSTextView()
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        logView.autoresizingMask = [.width]
        logView.isVerticallyResizable = true
        scroll.documentView = logView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addCustom(scroll, label: "progress")
        scroll.heightAnchor.constraint(equalToConstant: 180).isActive = true
    }
}

// MARK: - Build Image

final class BuildImageSheet: SheetViewController {
    private var dockerfileField: NSTextField!
    private var contextField: NSTextField!
    private var tagsField: NSTextField!
    private var argsEditor: KVEditor!
    private var targetField: NSTextField!
    private var swNocache = NSSwitch(), swPull = NSSwitch()

    init() {
        super.init(title: L("build.title"), submitTitle: L("build.submit"), submitSymbol: "hammer") { sheet in
            guard let s = sheet as? BuildImageSheet else { return false }
            let tags = s.tagsField.stringValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !tags.isEmpty else { s.setError(L("run.err.image")); return false }
            var spec = BuildSpec(dockerfile: s.dockerfileField.stringValue, context: s.contextField.stringValue, tags: tags)
            spec.buildArgs = s.argsEditor.collect().filter { !$0.0.isEmpty }
            spec.target = s.targetField.stringValue.isEmpty ? nil : s.targetField.stringValue
            spec.noCache = s.swNocache.state == .on
            spec.pull = s.swPull.state == .on
            do {
                try await Commands.buildImage(spec)
                Toast.shared.show(L("build.doneMsg", ["ref": tags[0], "size": ""]))
                return true
            } catch {
                s.setError(error.localizedDescription)
                return false
            }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        let dfCol = stackV([makeLabel(L("build.dockerfile"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor)], spacing: 4)
        dockerfileField = NSTextField(string: "Dockerfile")
        dockerfileField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        dfCol.addArrangedSubview(dockerfileField)
        let ctxCol = stackV([makeLabel(L("build.context"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor)], spacing: 4)
        contextField = NSTextField(string: ".")
        contextField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        ctxCol.addArrangedSubview(contextField)
        let two = stackH([dfCol, ctxCol], spacing: 10)
        two.distribution = .fillEqually
        addCustom(two)

        tagsField = addField(label: L("build.tags") + " *", placeholder: L("build.tag.ph"), mono: true)
        argsEditor = KVEditor(); argsEditor.setPlaceholders("KEY", "value")
        addCustom(argsEditor, label: L("build.args"))
        targetField = addField(label: L("build.target"), placeholder: L("build.target.ph"), mono: true)
        swNocache = addSwitch(label: L("build.opt.nocache"))
        swPull = addSwitch(label: L("build.opt.pull"))
    }
}

// MARK: - New Volume / Network / Machine / Cluster / Registry / Tag / LoadImage

final class NewVolumeSheet: SheetViewController {
    private var nameField: NSTextField!
    private var sizeField: NSTextField!
    private var unitSelect: NSPopUpButton!
    private var journalSelect: NSPopUpButton!

    init() {
        super.init(title: L("vol.new.title"), submitTitle: L("act.create")) { sheet in
            guard let s = sheet as? NewVolumeSheet else { return false }
            let name = s.nameField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { s.setError(L("run.err.image")); return false }
            let sizeStr: String?
            if let n = Double(s.sizeField.stringValue), n > 0 {
                let unit = ["GB", "MB", "TB"][s.unitSelect.indexOfSelectedItem]
                sizeStr = "\(n)\(unit.first!)"
            } else { sizeStr = nil }
            let journal = ["", "ordered", "writeback", "journal"][s.journalSelect.indexOfSelectedItem]
            do {
                try await Commands.createVolume(name: name, size: sizeStr, journal: journal.isEmpty ? nil : journal)
                Toast.shared.show(name + " · " + L("vol.new.title"))
                return true
            } catch { s.setError(error.localizedDescription); return false }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        nameField = addField(label: L("vol.new.name") + " *", placeholder: L("vol.new.name.ph"), mono: true)
        sizeField = addField(label: L("vol.new.size"), placeholder: "10")
        unitSelect = addSelect(label: "unit", options: ["GB", "MB", "TB"])
        journalSelect = addSelect(label: L("vol.new.journal"), options: [L("journal.none"), L("journal.ordered"), L("journal.writeback"), L("journal.journal")])
    }
}

final class NewNetworkSheet: SheetViewController {
    private var nameField: NSTextField!
    private var s4Field: NSTextField!
    private var s6Field: NSTextField!
    private var swInternal = NSSwitch()

    init() {
        super.init(title: L("net.new.title"), submitTitle: L("act.create")) { sheet in
            guard let s = sheet as? NewNetworkSheet else { return false }
            let name = s.nameField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { s.setError(L("run.err.image")); return false }
            do {
                try await Commands.createNetwork(
                    name: name,
                    subnet4: s.s4Field.stringValue.isEmpty ? nil : s.s4Field.stringValue,
                    subnet6: s.s6Field.stringValue.isEmpty ? nil : s.s6Field.stringValue,
                    internalOnly: s.swInternal.state == .on)
                Toast.shared.show(name + " · " + L("net.new.title"))
                return true
            } catch { s.setError(error.localizedDescription); return false }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        nameField = addField(label: L("net.new.name") + " *", placeholder: L("net.new.name.ph"), mono: true)
        s4Field = addField(label: L("net.subnet4"), placeholder: L("net.new.sub4.ph"), mono: true)
        s6Field = addField(label: L("net.subnet6"), placeholder: L("net.new.sub6.ph"), mono: true)
        swInternal = addSwitch(label: L("net.new.internal"))
    }
}

final class NewMachineSheet: SheetViewController {
    private var imageField: NSTextField!
    private var nameField: NSTextField!
    private var cpuOut: NSTextField!
    private var memSelect: NSPopUpButton!
    private var homeSelect: NSPopUpButton!
    private var swVirt = NSSwitch()
    private var swDefault = NSSwitch()

    init() {
        super.init(title: L("mach.new.title"), submitTitle: L("act.create")) { sheet in
            guard let s = sheet as? NewMachineSheet else { return false }
            let image = s.imageField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !image.isEmpty else { s.setError(L("run.err.image")); return false }
            let spec = MachineSpec(
                image: image,
                name: s.nameField.stringValue.isEmpty ? nil : s.nameField.stringValue,
                cpus: Int(s.cpuOut.stringValue),
                memory: (s.memSelect.titleOfSelectedItem ?? "8 GB").replacingOccurrences(of: " ", with: "").lowercased(),
                homeMount: ["rw", "ro", "none"][s.homeSelect.indexOfSelectedItem],
                virtualization: s.swVirt.state == .on,
                setDefault: s.swDefault.state == .on,
                kernelPath: nil)
            do {
                try await Commands.createMachine(spec)
                Toast.shared.show((spec.name ?? image) + " · " + L("st.running"))
                return true
            } catch { s.setError(error.localizedDescription); return false }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        imageField = addField(label: L("mach.new.image") + " *", placeholder: "alpine:3.22", mono: true)
        nameField = addField(label: L("mach.new.name"), placeholder: L("mach.new.name.ph"), mono: true)

        cpuOut = NSTextField(labelWithString: "4")
        let minus = NSButton(title: "−", target: self, action: #selector(stepCpu(_:))); minus.bezelStyle = .rounded; minus.controlSize = .small; minus.tag = -1
        let plus = NSButton(title: "+", target: self, action: #selector(stepCpu(_:))); plus.bezelStyle = .rounded; plus.controlSize = .small; plus.tag = 1
        let cpuCol = stackV([makeLabel(L("mach.new.cpus"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), stackH([minus, cpuOut, plus], spacing: 6)], spacing: 4)

        memSelect = NSPopUpButton()
        memSelect.addItems(withTitles: ["2 GB", "4 GB", "8 GB", "16 GB"])
        memSelect.selectItem(at: 2)
        memSelect.controlSize = .small
        let memCol = stackV([makeLabel(L("mach.new.mem"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), memSelect], spacing: 4)

        let resRow = stackH([cpuCol, memCol], spacing: 12)
        addCustom(resRow)

        homeSelect = addSelect(label: L("mach.new.home"), options: [L("mach.home.rw"), L("mach.home.ro"), L("mach.home.none")])
        swVirt = addSwitch(label: L("mach.new.virt"))
        swDefault = addSwitch(label: L("mach.new.def"))
    }

    @objc private func stepCpu(_ sender: NSButton) {
        let v = max(1, min(16, (Int(cpuOut.stringValue) ?? 4) + sender.tag))
        cpuOut.stringValue = "\(v)"
    }
}

final class NewClusterSheet: SheetViewController {
    private var nameField: NSTextField!
    private var imageField: NSTextField!
    private var cpuOut: NSTextField!
    private var memSelect: NSPopUpButton!
    private var swRm = NSSwitch()

    init() {
        super.init(title: L("k8.new.title"), submitTitle: L("act.create")) { sheet in
            guard let s = sheet as? NewClusterSheet else { return false }
            let name = s.nameField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { s.setError(L("run.err.image")); return false }
            let spec = K8sSpec(
                name: name,
                nodeImage: s.imageField.stringValue.isEmpty ? nil : s.imageField.stringValue,
                cpus: Int(s.cpuOut.stringValue),
                memory: (s.memSelect.titleOfSelectedItem ?? "8 GB").replacingOccurrences(of: " ", with: "").lowercased(),
                autoRemove: s.swRm.state == .on)
            do {
                Toast.shared.show(L("k8.create.ok", ["n": name]))
                try await Commands.k8sCreate(spec)
                return true
            } catch { s.setError(error.localizedDescription); return false }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        nameField = addField(label: L("k8.new.name") + " *", placeholder: L("k8.new.name.ph"), value: "k8s-dev", mono: true)
        imageField = addField(label: L("k8.new.image"), placeholder: L("k8.new.image.ph"), value: "docker.io/kindest/node:v1.35.5", mono: true)

        cpuOut = NSTextField(labelWithString: "4")
        let minus = NSButton(title: "−", target: self, action: #selector(stepCpu(_:))); minus.bezelStyle = .rounded; minus.controlSize = .small; minus.tag = -1
        let plus = NSButton(title: "+", target: self, action: #selector(stepCpu(_:))); plus.bezelStyle = .rounded; plus.controlSize = .small; plus.tag = 1
        let cpuCol = stackV([makeLabel(L("mach.new.cpus"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), stackH([minus, cpuOut, plus], spacing: 6)], spacing: 4)
        memSelect = NSPopUpButton()
        memSelect.addItems(withTitles: ["2 GB", "4 GB", "8 GB", "16 GB"])
        memSelect.selectItem(at: 2)
        memSelect.controlSize = .small
        let memCol = stackV([makeLabel(L("mach.new.mem"), font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor), memSelect], spacing: 4)
        let resRow = stackH([cpuCol, memCol], spacing: 12)
        addCustom(resRow)

        swRm = addSwitch(label: L("k8.new.rm"))
        let note = NSTextField(wrappingLabelWithString: L("k8.exp.note"))
        note.font = .systemFont(ofSize: 11)
        note.textColor = .tertiaryLabelColor
        addCustom(note)
    }

    @objc private func stepCpu(_ sender: NSButton) {
        let v = max(2, min(16, (Int(cpuOut.stringValue) ?? 4) + sender.tag))
        cpuOut.stringValue = "\(v)"
    }
}

final class RegistryLoginSheet: SheetViewController {
    private var serverField: NSTextField!
    private var userField: NSTextField!
    private var passField: NSSecureTextField!

    init() {
        super.init(title: L("set.reg.login.title"), submitTitle: L("act.login"), submitSymbol: "key") { sheet in
            guard let s = sheet as? RegistryLoginSheet else { return false }
            let server = s.serverField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !server.isEmpty else { s.setError(L("run.err.image")); return false }
            do {
                try await Commands.registryLogin(server: server, user: s.userField.stringValue.isEmpty ? nil : s.userField.stringValue, password: s.passField.stringValue)
                Toast.shared.show(server + " · " + L("act.login"))
                return true
            } catch { s.setError(error.localizedDescription); return false }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        serverField = addField(label: L("set.reg.login.server") + " *", placeholder: L("set.reg.login.server.ph"), mono: true)
        userField = addField(label: L("set.reg.login.user"))
        passField = NSSecureTextField()
        passField.font = .systemFont(ofSize: 13)
        passField.translatesAutoresizingMaskIntoConstraints = false
        addCustom(passField, label: L("set.reg.login.pass"))
    }
}

final class TagImageSheet: SheetViewController {
    private var targetField: NSTextField!
    private let source: String

    init(source ref: String) {
        self.source = ref
        super.init(title: L("tagd.title"), submitTitle: L("act.confirm")) { sheet in
            guard let s = sheet as? TagImageSheet else { return false }
            let target = s.targetField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !target.isEmpty else { s.setError(L("run.err.image")); return false }
            do {
                try await Commands.tagImage(s.source, target)
                Toast.shared.show("\(target) ← \(s.source)")
                return true
            } catch { s.setError(error.localizedDescription); return false }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        let src = addField(label: L("tagd.source"), value: source, mono: true)
        src.isEnabled = false
        targetField = addField(label: L("tagd.target"), placeholder: L("tagd.target.ph"), mono: true)
    }
}

final class LoadImageSheet: SheetViewController {
    private var refField: NSTextField!
    private let clusterName: String

    init(clusterName: String) {
        self.clusterName = clusterName
        super.init(title: L("k8.loadimg.title", ["n": clusterName]), submitTitle: L("k8.loadimg.short"), submitSymbol: "square.and.arrow.up") { sheet in
            guard let s = sheet as? LoadImageSheet else { return false }
            let ref = s.refField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !ref.isEmpty else { s.setError(L("run.err.image")); return false }
            do {
                try await Commands.k8sLoadImage(s.clusterName, image: ref)
                Toast.shared.show(L("k8.loadimg.doneMsg", ["img": ref, "n": s.clusterName]))
                return true
            } catch { s.setError(error.localizedDescription); return false }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        refField = addField(label: L("k8.loadimg.ref") + " *", placeholder: L("k8.loadimg.ph"), mono: true)
    }
}
