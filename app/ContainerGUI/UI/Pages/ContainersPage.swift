import AppKit

final class ContainersPage: PageViewController {
    private var filter = "all"
    private var search = ""
    private var table: NSTableView!
    private var scroll: NSScrollView!
    private var emptyView: EmptyStateView?
    private var host: NSView!

    override func buildContent() {
        host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: content.topAnchor),
            host.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        rebuild()
    }

    private func rebuild() {
        host.subviews.forEach { $0.removeFromSuperview() }
        emptyView = nil

        table = NSTableView()
        table.headerView = nil
        table.rowHeight = 52
        table.gridStyleMask = [.solidHorizontalGridLineMask]
        table.gridColor = .separatorColor.withAlphaComponent(0.25)
        let col = NSTableColumn(identifier: .init("c"))
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self

        scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let card = CardView()
        card.addSubview(scroll)

        let header = TableHeaderBar(labels: [
            (L("ct.name"), 280), (L("ct.status"), 70), (L("ct.ip"), 110), (L("ct.created"), 90), ("", 30),
        ])
        let wrap = stackV([header, card], spacing: 6)
        wrap.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(wrap)
        NSLayoutConstraint.activate([
            wrap.topAnchor.constraint(equalTo: host.topAnchor),
            wrap.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            wrap.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            wrap.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: card.topAnchor, constant: 1),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -1),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 1),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -1),
        ])
        reload()
    }

    private var filtered: [ManagedContainer] {
        var rows = Store.shared.containers
        if filter == "running" { rows = rows.filter(\.isRunning) }
        if filter == "stopped" { rows = rows.filter { !$0.isRunning } }
        if !search.isEmpty {
            let q = search.lowercased()
            rows = rows.filter { $0.id.lowercased().contains(q) || $0.imageRef.lowercased().contains(q) }
        }
        return rows
    }

    override func reload() {
        guard table != nil else { return }
        table.reloadData()
        let rows = filtered
        if rows.isEmpty {
            if emptyView == nil {
                let e = Store.shared.containers.isEmpty
                    ? EmptyStateView(symbol: "cube", title: L("ct.empty"), hint: L("ct.empty.hint"), actionTitle: L("act.runContainer")) { [weak self] in self?.openRunSheet() }
                    : EmptyStateView(symbol: "magnifyingglass", title: L("ct.nomatch"), hint: "")
                host.addSubview(e)
                NSLayoutConstraint.activate([
                    e.topAnchor.constraint(equalTo: host.topAnchor, constant: 40),
                    e.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                    e.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                ])
                emptyView = e
                scroll.isHidden = true
            }
        } else {
            emptyView?.removeFromSuperview()
            emptyView = nil
            scroll.isHidden = false
        }
    }

    override func makeToolbarItems() -> [NSView] {
        let seg = NSSegmentedControl(labels: [L("filter.all"), L("filter.running"), L("filter.stopped")], trackingMode: .selectOne, target: self, action: #selector(filterChanged(_:)))
        seg.controlSize = .small
        seg.font = .systemFont(ofSize: 12)
        seg.selectedSegment = ["all", "running", "stopped"].firstIndex(of: filter) ?? 0

        let field = NSSearchField()
        field.placeholderString = L("search.ph.containers")
        field.controlSize = .small
        field.font = .systemFont(ofSize: 12)
        field.target = self
        field.action = #selector(searchChanged)
        field.widthAnchor.constraint(equalToConstant: 220).isActive = true
        searchField = field

        let run = makeButton(L("act.runContainer"), symbol: "plus", primary: true) { [weak self] in self?.openRunSheet() }
        return [seg, field, run]
    }

    @discardableResult
    override func runPrimary() -> Bool {
        openRunSheet()
        return true
    }

    @objc private func filterChanged(_ seg: NSSegmentedControl) {
        filter = ["all", "running", "stopped"][seg.selectedSegment]
        rebuild()
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        search = sender.stringValue
        table.reloadData()
    }

    @objc private func openDetail() {
        let row = table.clickedRow
        guard row >= 0, row < filtered.count else { return }
        let c = filtered[row]
        let inspector = ContainerInspector(containerID: c.id)
        presentInspector(inspector)
    }

    func openRunSheet() {
        presentSheet(RunContainerSheet())
    }

    func presentInspector(_ vc: InspectorViewController) {
        InspectorPresenter.present(vc, from: self)
    }
}

extension Notification.Name {
    static let closeInspector = Notification.Name("closeInspector")
}

extension ContainersPage: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        ContainerRowView(container: filtered[row])
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 52 }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        guard row >= 0, row < filtered.count else { return }
        let c = filtered[row]
        let inspector = ContainerInspector(containerID: c.id)
        presentInspector(inspector)
        DispatchQueue.main.async { [weak self] in self?.table.deselectAll(nil) }
    }
}

// MARK: - Row view

final class ContainerRowView: NSTableCellView {
    init(container c: ManagedContainer) {
        super.init(frame: .zero)

        let dot = DotView(color: c.isRunning ? .systemGreen : .systemGray, pulsing: c.isRunning)
        let name = makeLabel(c.id, font: .systemFont(ofSize: 13, weight: .semibold))
        let image = makeMonoLabel(c.imageRef, size: 11, color: .secondaryLabelColor)
        let nameCol = stackV([stackH([dot, name], spacing: 7), image], spacing: 3)
        nameCol.alignment = .leading

        let stateText = c.isRunning ? L("st.running") : (c.status.state.map { $0.rawValue.capitalized } ?? L("st.exited"))
        let state = makeLabel(stateText, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        state.lineBreakMode = .byTruncatingTail
        state.widthAnchor.constraint(equalToConstant: 70).isActive = true

        let ip = makeMonoLabel(c.ip, size: 11)
        ip.widthAnchor.constraint(equalToConstant: 110).isActive = true

        let created = makeLabel(Fmt.relTime(c.status.startedDate ?? nil), font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        created.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let menu = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)!, target: self, action: #selector(menuTap))
        menu.isBordered = false
        menu.contentTintColor = .secondaryLabelColor
        menu.translatesAutoresizingMaskIntoConstraints = false
        menu.widthAnchor.constraint(equalToConstant: 30).isActive = true
        objc_setAssociatedObject(menu, "id", c.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        objc_setAssociatedObject(menu, "running", c.isRunning, .OBJC_ASSOCIATION_RETAIN)

        let row = stackH([nameCol, state, ip, created, menu], spacing: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.distribution = .fill
        nameCol.widthAnchor.constraint(equalToConstant: 280).isActive = true
        menu.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func menuTap(_ sender: NSButton) {
        guard let id = objc_getAssociatedObject(sender, "id") as? String else { return }
        let menu = NSMenu()
        let running = (objc_getAssociatedObject(sender, "running") as? Bool) ?? false
        if running {
            menu.addItem(withTitle: L("act.stop"), action: #selector(actStop), keyEquivalent: "")
            menu.addItem(withTitle: L("act.kill"), action: #selector(actKill), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: L("act.start"), action: #selector(actStart), keyEquivalent: "")
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: L("act.copyId"), action: #selector(actCopy), keyEquivalent: "")
        menu.addItem(withTitle: L("act.exportFs"), action: #selector(actExport), keyEquivalent: "")
        menu.addItem(.separator())
        let del = menu.addItem(withTitle: L("act.delete"), action: #selector(actDelete), keyEquivalent: "")
        for item in menu.items { item.target = self }
        objc_setAssociatedObject(self, "menuId", id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        del.attributedTitle = NSAttributedString(string: L("act.delete"), attributes: [.foregroundColor: NSColor.systemRed])
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height), in: sender)
    }

    private var menuId: String { objc_getAssociatedObject(self, "menuId") as? String ?? "" }

    @objc private func actStop() { Task { try? await Commands.containerAction("stop", ids: [menuId]); Store.shared.refresh() } }
    @objc private func actKill() {
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: L("kill.title", ["id": menuId]), message: L("kill.msg"), confirm: L("confirm.kill"), on: window) else { return }
            try? await Commands.containerAction("kill", ids: [menuId])
            Store.shared.refresh()
        }
    }
    @objc private func actStart() { Task { try? await Commands.containerAction("start", ids: [menuId]); Store.shared.refresh() } }
    @objc private func actCopy() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(menuId, forType: .string); Toast.shared.show(L("copied")) }
    @objc private func actExport() {
        let id = menuId
        Task { @MainActor [weak self] in
            guard let w = self?.window else { return }
            let dlg = NSSavePanel()
            dlg.nameFieldStringValue = id + ".tar"
            dlg.beginSheetModal(for: w) { response in
                guard response == .OK, let url = dlg.url else { return }
                Task {
                    try? await Commands.exportContainer(id, to: url.path)
                    await MainActor.run { Toast.shared.show(L("export.doneMsg", ["path": url.path])) }
                }
            }
        }
    }
    @objc private func actDelete() {
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: L("del.ct.title", ["id": menuId]), message: L("del.ct.msg"), confirm: L("confirm.yes"), on: window) else { return }
            try? await Commands.containerAction("delete", ids: [menuId])
            Store.shared.refresh()
        }
    }
}
