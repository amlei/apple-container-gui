import AppKit

final class MachinesPage: PageViewController {
    private let grid = FlippedStackView()

    override func buildContent() {
        grid.orientation = .vertical
        grid.spacing = 12
        grid.alignment = .leading
        grid.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.documentView = grid
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            grid.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        reload()
    }

    override func reload() {
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let list = Store.shared.machines
        if list.isEmpty {
            grid.addArrangedSubview(EmptyStateView(symbol: "display", title: L("mach.empty"), hint: L("mach.empty.hint"), actionTitle: L("mach.new.title")) { [weak self] in self?.presentSheet(NewMachineSheet()) })
        }
        for m in list {
            grid.addArrangedSubview(MachineCard(machine: m) { [weak self] in self?.machineAction(m) })
        }
    }

    override func makeToolbarItems() -> [NSView] {
        [makeButton(L("mach.new.title"), symbol: "plus", primary: true) { [weak self] in self?.presentSheet(NewMachineSheet()) }]
    }

    @discardableResult
    override func runPrimary() -> Bool {
        presentSheet(NewMachineSheet())
        return true
    }

    private func machineAction(_ m: MachineResourceJSON) {
        let menu = NSMenu()
        if m.isRunning {
            menu.addItem(withTitle: L("mach.stop.title", ["n": m.name]), action: #selector(mStop(_:)), keyEquivalent: "")
        }
        menu.addItem(withTitle: L("act.setDefault"), action: #selector(mSetDef(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let del = menu.addItem(withTitle: L("act.delete"), action: #selector(mDelete(_:)), keyEquivalent: "")
        del.attributedTitle = NSAttributedString(string: L("act.delete"), attributes: [.foregroundColor: NSColor.systemRed])
        for item in menu.items { item.target = self; item.representedObject = m.name }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: nil)
    }

    @objc private func mStop(_ sender: NSMenuItem) { Task { try? await Commands.machineStop(sender.representedObject as? String); Store.shared.refresh() } }
    @objc private func mSetDef(_ sender: NSMenuItem) {
        Task { @MainActor in
            guard let name = sender.representedObject as? String else { return }
            try? await Commands.machineSetDefault(name)
            Toast.shared.show(L("mach.setdef.ok", ["n": name]))
            Store.shared.refresh()
        }
    }
    @objc private func mDelete(_ sender: NSMenuItem) {
        Task { @MainActor in
            guard let name = sender.representedObject as? String,
                  await ConfirmPanel.confirm(title: L("del.mach.title", ["n": name]), message: L("del.mach.msg"), confirm: L("confirm.yes"), on: view.window) else { return }
            try? await Commands.machineDelete(name)
            Store.shared.refresh()
        }
    }
}

final class MachineCard: NSView {
    init(machine m: MachineResourceJSON, onMenu: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cardStyle()
        widthAnchor.constraint(equalToConstant: 520).isActive = true

        let title = stackH([
            makeLabel(m.name, font: .systemFont(ofSize: 14, weight: .semibold)),
            (m.default ?? false) ? Pill(text: L("mach.default"), color: .systemOrange) : nil,
            DotView(color: m.isRunning ? .systemGreen : .systemGray, pulsing: m.isRunning),
            makeLabel(m.isRunning ? L("mach.running") : L("mach.stopped"), font: .systemFont(ofSize: 11), color: .secondaryLabelColor),
        ].compactMap { $0 }, spacing: 8)

        let meta = stackV([
            makeMonoLabel("image: \(m.diskSize != nil ? "— " : "")\(Fmt.bytes(m.diskSize)) disk", size: 11),
            makeMonoLabel("resources: \(m.cpus ?? 0) CPU · \(Fmt.bytes(m.memory))", size: 11),
            makeLabel(L("mach.created") + ": " + Fmt.relTime(m.createdDate), font: .systemFont(ofSize: 11), color: .secondaryLabelColor),
        ], spacing: 4)
        meta.alignment = .leading

        let foot = stackH([], spacing: 8)
        if m.isRunning {
            let stop = makeButton(L("act.stop"), symbol: "stop.fill", small: true)
            stop.target = self
            stop.action = #selector(tapStop)
            foot.addArrangedSubview(stop)
        }
        let menu = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)!, target: self, action: #selector(tapMenu))
        menu.isBordered = false
        menu.contentTintColor = .secondaryLabelColor
        objc_setAssociatedObject(self, "cb", onMenu, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        foot.addArrangedSubview(NSView())
        foot.addArrangedSubview(menu)

        let col = stackV([title, meta, foot], spacing: 10)
        col.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            col.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            col.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            col.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            foot.trailingAnchor.constraint(equalTo: col.trailingAnchor),
            foot.widthAnchor.constraint(equalTo: col.widthAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { cardStyle() }

    @objc private func tapStop() { Task { try? await Commands.machineStop(nil); Store.shared.refresh() } }
    @objc private func tapMenu() { (objc_getAssociatedObject(self, "cb") as? () -> Void)?() }
}
