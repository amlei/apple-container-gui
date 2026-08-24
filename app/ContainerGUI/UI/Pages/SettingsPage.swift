import AppKit

final class SettingsPage: PageViewController {
    private let stack = stackV([], spacing: 14)

    override func buildContent() {
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.documentView = stack
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        reload()
    }

    override func reload() {
        let s = Store.shared
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Appearance
        let appearance = SettingsGroup(title: L("set.appearance"))
        let themeLabel = makeLabel(L("set.theme"), font: .systemFont(ofSize: 13))
        let themeSeg = NSSegmentedControl(labels: [L("theme.auto"), L("theme.light"), L("theme.dark")], trackingMode: .selectOne, target: self, action: #selector(themeChanged(_:)))
        themeSeg.controlSize = .small
        let current = NSApp.appearance == nil ? 0 : (NSApp.appearance?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 2 : 1)
        themeSeg.selectedSegment = current
        appearance.addRow(themeLabel, themeSeg)

        // Service
        let service = SettingsGroup(title: L("set.svc"), desc: L("set.svc.desc"))
        let stateRow = stackH([
            DotView(color: s.servicesRunning ? .systemGreen : .systemGray, pulsing: s.servicesRunning),
            makeLabel(s.servicesRunning ? L("svc.running") : L("svc.stopped"), font: .systemFont(ofSize: 12, weight: .medium)),
        ], spacing: 6)
        let svcBtn: NSButton
        if s.servicesRunning {
            svcBtn = makeButton(L("svc.stopBtn"), symbol: "power", danger: true, small: true)
            svcBtn.target = self
            svcBtn.action = #selector(stopServices)
        } else {
            svcBtn = makeButton(L("svc.startBtn"), symbol: "play.fill", small: true)
            svcBtn.target = self
            svcBtn.action = #selector(startServices)
        }
        let logsBtn = makeButton(L("set.syslogs"), symbol: "doc.text", small: true) { [weak self] in
            self?.presentInspector(SystemLogsInspector())
        }
        service.addRow(stateRow, stackH([svcBtn, logsBtn], spacing: 8))
        service.addRow(KVRow(key: L("ov.service.version.cli"), value: "container " + s.cliVersion), NSView())
        service.addRow(KVRow(key: L("ov.service.version.api"), value: s.apiVersion), NSView())

        // Kernel
        let kernel = SettingsGroup(title: L("set.kernel"), desc: L("set.kernel.rec"))
        let kernelVersion = s.properties.first { $0.key == "kernel.binaryPath" }?.value
            .components(separatedBy: "/").last ?? "—"
        kernel.addRow(KVRow(key: L("set.kernel.current"), value: kernelVersion), NSView())
        let recBtn = makeButton(L("act.installRecKernel"), symbol: "arrow.down", small: true) { [weak self] in
            Task {
                Toast.shared.show(L("set.kernel.installing"))
                try? await Commands.kernelSetRecommended()
                Toast.shared.show(L("set.kernel.ok"))
                Store.shared.refreshSystemInfo()
            }
        }
        let customBtn = makeButton(L("act.customKernel"), symbol: "folder", small: true) { [weak self] in
            guard let w = self?.view.window else { return }
            let dlg = NSOpenPanel()
            dlg.canChooseFiles = true
            dlg.canChooseDirectories = false
            dlg.beginSheetModal(for: w) { resp in
                guard resp == .OK, let path = dlg.url?.path else { return }
                Task {
                    try? await Commands.kernelSetBinary(path)
                    Toast.shared.show(path)
                    Store.shared.refreshSystemInfo()
                }
            }
        }
        kernel.addRow(NSView(), stackH([recBtn, customBtn], spacing: 8))

        // DNS
        let dns = SettingsGroup(title: L("set.dns"), desc: L("set.dns.desc"))
        for d in s.dnsDomains {
            let delBtn = makeButton(L("act.remove"), symbol: "trash", danger: true, small: true)
            delBtn.target = self
            delBtn.action = #selector(dnsDelete(_:))
            objc_setAssociatedObject(delBtn, "val", d, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            dns.addRow(KVRow(key: "*." + d, value: "/etc/resolver/" + d), delBtn)
        }
        let dnsInput = NSTextField()
        dnsInput.placeholderString = L("set.dns.add.ph")
        dnsInput.controlSize = .small
        dnsInput.translatesAutoresizingMaskIntoConstraints = false
        dnsInput.widthAnchor.constraint(equalToConstant: 160).isActive = true
        let dnsAdd = makeButton(L("act.add"), symbol: "plus", small: true)
        dnsAdd.target = self
        dnsAdd.action = #selector(dnsAddTap)
        objc_setAssociatedObject(dnsAdd, "input", dnsInput, .OBJC_ASSOCIATION_RETAIN)
        dns.addRow(dnsInput, dnsAdd)

        // Registries
        let reg = SettingsGroup(title: L("set.reg"), desc: L("set.reg.desc"))
        for r in s.registries {
            let out = makeButton(L("act.logout"), small: true)
            out.target = self
            out.action = #selector(regLogout(_:))
            objc_setAssociatedObject(out, "val", r, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            reg.addRow(KVRow(key: r, value: ""), out)
        }
        let loginBtn = makeButton(L("act.login"), symbol: "key", small: true) { [weak self] in self?.presentSheet(RegistryLoginSheet()) }
        reg.addRow(NSView(), loginBtn)

        // Properties
        let props = SettingsGroup(title: L("set.props"), desc: L("set.props.desc"))
        for p in s.properties.prefix(30) {
            props.addRow(KVRow(key: p.key, value: p.value), NSView())
        }

        stack.addArrangedSubview(appearance)
        stack.addArrangedSubview(service)
        stack.addArrangedSubview(kernel)
        stack.addArrangedSubview(dns)
        stack.addArrangedSubview(reg)
        stack.addArrangedSubview(props)
    }

    @objc private func themeChanged(_ seg: NSSegmentedControl) {
        switch seg.selectedSegment {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
        reload()
    }

    @objc private func startServices() {
        Task { Toast.shared.show(L("svc.starting")); try? await Commands.systemStart(); Toast.shared.show(L("svc.running")); Store.shared.refresh() }
    }
    @objc private func stopServices() {
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: L("svc.stopWarnTitle"), message: L("svc.stopWarnMsg"), confirm: L("confirm.stop"), on: view.window) else { return }
            try? await Commands.systemStop()
            Store.shared.refresh()
        }
    }
    @objc private func dnsDelete(_ sender: NSButton) {
        guard let d = objc_getAssociatedObject(sender, "val") as? String else { return }
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: d, message: "/etc/resolver/" + d, confirm: L("act.remove"), on: view.window) else { return }
            try? await Commands.dnsDelete(d)
            Store.shared.refreshSystemInfo()
        }
    }
    @objc private func dnsAddTap(_ sender: NSButton) {
        guard let input = objc_getAssociatedObject(sender, "input") as? NSTextField else { return }
        let d = input.stringValue.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "*.", with: "")
        guard !d.isEmpty else { return }
        Task {
            try? await Commands.dnsCreate(d)
            Toast.shared.show("*." + d)
            input.stringValue = ""
            Store.shared.refreshSystemInfo()
        }
    }
    @objc private func regLogout(_ sender: NSButton) {
        guard let r = objc_getAssociatedObject(sender, "val") as? String else { return }
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: r, message: L("set.reg.desc"), confirm: L("confirm.logout"), on: view.window) else { return }
            try? await Commands.registryLogout(r)
            Store.shared.refreshSystemInfo()
        }
    }

    private func presentInspector(_ vc: InspectorViewController) {
        InspectorPresenter.present(vc, from: self)
    }
}

final class SettingsGroup: NSView {
    private let rows = stackV([], spacing: 10)

    init(title: String, desc: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cardStyle()
        let head = stackV([makeLabel(title, font: .systemFont(ofSize: 14, weight: .semibold))], spacing: 2)
        if let desc {
            let d = NSTextField(wrappingLabelWithString: desc)
            d.font = .systemFont(ofSize: 11)
            d.textColor = .tertiaryLabelColor
            head.addArrangedSubview(d)
        }
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(head)
        addSubview(rows)
        NSLayoutConstraint.activate([
            head.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            head.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            head.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            rows.topAnchor.constraint(equalTo: head.bottomAnchor, constant: 12),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            rows.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { cardStyle() }

    func addRow(_ left: NSView, _ right: NSView) {
        left.translatesAutoresizingMaskIntoConstraints = false
        right.translatesAutoresizingMaskIntoConstraints = false
        let row = stackH([left, NSView(), right], spacing: 10)
        row.translatesAutoresizingMaskIntoConstraints = false
        rows.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: rows.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: rows.trailingAnchor).isActive = true
    }
}
