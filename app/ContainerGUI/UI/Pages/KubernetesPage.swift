import AppKit

final class KubernetesPage: PageViewController {
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
        let clusters = Store.shared.clusters
        if clusters.isEmpty {
            grid.addArrangedSubview(EmptyStateView(symbol: "steeringwheel", title: L("k8.empty"), hint: L("k8.empty.hint"), actionTitle: L("k8.new.title")) { [weak self] in self?.presentSheet(NewClusterSheet()) })
        }
        for k in clusters {
            grid.addArrangedSubview(ClusterCard(cluster: k) { [weak self] in self?.clusterMenu(k) })
        }
    }

    override func makeToolbarItems() -> [NSView] {
        [makeButton(L("k8.new.title"), symbol: "plus", primary: true) { [weak self] in self?.presentSheet(NewClusterSheet()) }]
    }

    @discardableResult
    override func runPrimary() -> Bool {
        presentSheet(NewClusterSheet())
        return true
    }

    private func clusterMenu(_ k: K8sCluster) {
        let menu = NSMenu()
        if !k.isRunning {
            menu.addItem(withTitle: L("act.start"), action: #selector(kStart(_:)), keyEquivalent: "")
        }
        let load = menu.addItem(withTitle: L("k8.loadimg.short"), action: #selector(kLoad(_:)), keyEquivalent: "")
        load.isEnabled = k.isRunning
        let wc = menu.addItem(withTitle: L("k8.writecfg"), action: #selector(kWriteCfg(_:)), keyEquivalent: "")
        wc.isEnabled = k.isRunning
        menu.addItem(.separator())
        let del = menu.addItem(withTitle: L("act.delete"), action: #selector(kDelete(_:)), keyEquivalent: "")
        del.attributedTitle = NSAttributedString(string: L("act.delete"), attributes: [.foregroundColor: NSColor.systemRed])
        for item in menu.items { item.target = self; item.representedObject = k.name }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: nil)
    }

    @objc private func kStart(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Task { Toast.shared.show(L("svc.starting")); try? await Commands.k8sStart(name); Toast.shared.show(L("st.running") + " · " + name); Store.shared.refresh() }
    }
    @objc private func kLoad(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        presentSheet(LoadImageSheet(clusterName: name))
    }
    @objc private func kWriteCfg(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: L("k8.writecfg"), message: L("k8.writecfg.msg"), confirm: L("act.confirm"), on: view.window) else { return }
            try? await Commands.k8sWriteConfig(name)
            Toast.shared.show(L("k8.writecfg.doneMsg", ["n": name]))
        }
    }
    @objc private func kDelete(_ sender: NSMenuItem) {
        Task { @MainActor in
            guard let name = sender.representedObject as? String,
                  await ConfirmPanel.confirm(title: L("del.k8s.title", ["n": name]), message: L("del.k8s.msg"), confirm: L("confirm.yes"), on: view.window) else { return }
            try? await Commands.k8sDelete(name)
            Toast.shared.show(name + " · " + L("act.delete"))
            Store.shared.refresh()
        }
    }
}

final class ClusterCard: NSView {
    init(cluster k: K8sCluster, onMenu: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cardStyle()
        widthAnchor.constraint(equalToConstant: 520).isActive = true

        let title = stackH([
            sfIcon("steeringwheel", size: 14),
            makeLabel(k.name, font: .systemFont(ofSize: 14, weight: .semibold)),
            DotView(color: k.isRunning ? .systemGreen : .systemGray, pulsing: k.isRunning),
            makeLabel(k.isRunning ? L("mach.running") : L("mach.stopped"), font: .systemFont(ofSize: 11), color: .secondaryLabelColor),
            Pill(text: L("k8.exp.tag"), color: .systemOrange),
        ], spacing: 8)

        let meta = stackV([
            makeMonoLabel("\(L("k8.nodeImage")): \(k.nodeImage)", size: 11),
            makeMonoLabel("nodes: \(k.nodes)", size: 11),
        ], spacing: 4)
        meta.alignment = .leading

        let foot = stackH([], spacing: 8)
        if k.isRunning {
            let load = makeButton(L("k8.loadimg.short"), symbol: "square.and.arrow.up", small: true)
            load.target = self
            load.action = #selector(tapLoad)
            foot.addArrangedSubview(load)
        } else {
            let start = makeButton(L("act.start"), symbol: "play.fill", small: true)
            start.target = self
            start.action = #selector(tapStart)
            foot.addArrangedSubview(start)
        }
        let menu = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)!, target: self, action: #selector(tapMenu))
        menu.isBordered = false
        menu.contentTintColor = .secondaryLabelColor
        objc_setAssociatedObject(self, "cb", onMenu, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        objc_setAssociatedObject(self, "name", k.name, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        objc_setAssociatedObject(self, "running", k.isRunning, .OBJC_ASSOCIATION_RETAIN)
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

    @objc private func tapStart() {
        guard let name = objc_getAssociatedObject(self, "name") as? String else { return }
        Task { try? await Commands.k8sStart(name); Store.shared.refresh() }
    }
    @objc private func tapLoad() {
        guard let name = objc_getAssociatedObject(self, "name") as? String,
              (objc_getAssociatedObject(self, "running") as? Bool) == true else { return }
        if let page = nearestAncestorPage() as? KubernetesPage {
            page.presentSheet(LoadImageSheet(clusterName: name))
        }
    }
    @objc private func tapMenu() { (objc_getAssociatedObject(self, "cb") as? () -> Void)?() }

    private func nearestAncestorPage() -> PageViewController? {
        var responder: NSResponder? = self
        while let r = responder {
            if let page = r as? PageViewController { return page }
            responder = r.nextResponder
        }
        return nil
    }
}
