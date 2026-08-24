import AppKit

final class ImagesPage: PageViewController {
    private var search = ""
    private var table: NSTableView!
    private var scroll: NSScrollView!
    private var host: NSView!
    private var emptyView: EmptyStateView?

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

        table = NSTableView()
        table.headerView = nil
        table.rowHeight = 48
        table.gridStyleMask = [.solidHorizontalGridLineMask]
        table.gridColor = .separatorColor.withAlphaComponent(0.25)
        table.addTableColumn(NSTableColumn(identifier: .init("c")))
        table.dataSource = self
        table.delegate = self

        scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let card = CardView()
        card.addSubview(scroll)

        let header = TableHeaderBar(labels: [
            (L("img.ref"), 280), (L("img.size"), 80), (L("img.osarch"), 90), (L("img.created"), 90), ("", 30),
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

    private var filtered: [ImageResourceJSON] {
        var rows = Store.shared.images
        if !search.isEmpty {
            rows = rows.filter { $0.ref.lowercased().contains(search.lowercased()) }
        }
        return rows
    }

    override func reload() {
        guard table != nil else { return }
        table.reloadData()
        let rows = filtered
        if rows.isEmpty {
            if emptyView == nil {
                let e = Store.shared.images.isEmpty
                    ? EmptyStateView(symbol: "square.3.layers.3d", title: L("img.empty"), hint: L("img.empty.hint"), actionTitle: L("act.pull")) { [weak self] in self?.openPullSheet() }
                    : EmptyStateView(symbol: "magnifyingglass", title: L("img.nomatch"), hint: "")
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
        let field = NSSearchField()
        field.placeholderString = L("search.ph.images")
        field.controlSize = .small
        field.target = self
        field.action = #selector(searchChanged)
        field.widthAnchor.constraint(equalToConstant: 220).isActive = true
        searchField = field

        return [
            field,
            makeButton(L("act.build"), symbol: "hammer") { [weak self] in self?.presentSheet(BuildImageSheet()) },
            makeButton(L("act.pull"), symbol: "arrow.down", primary: true) { [weak self] in self?.openPullSheet() },
        ]
    }

    @discardableResult
    override func runPrimary() -> Bool {
        openPullSheet()
        return true
    }

    private func openPullSheet() { presentSheet(PullImageSheet()) }

    @objc private func searchChanged(_ sender: NSSearchField) {
        search = sender.stringValue
        table.reloadData()
    }

    @objc private func openDetail() {
        let row = table.clickedRow
        guard row >= 0, row < filtered.count else { return }
        let inspector = ImageInspector(image: filtered[row])
        presentInspector(inspector)
    }

    private func presentInspector(_ vc: InspectorViewController) {
        InspectorPresenter.present(vc, from: self)
    }
}

extension ImagesPage: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        ImageRowView(image: filtered[row], onMenu: { [weak self] img, anchor in self?.showMenu(img, anchor: anchor) })
    }

    private func showMenu(_ img: ImageResourceJSON, anchor: NSView) {
        let menu = NSMenu()
        menu.addItem(withTitle: L("act.runContainer"), action: #selector(mRun(_:)), keyEquivalent: "")
        menu.addItem(withTitle: L("act.push"), action: #selector(mPush(_:)), keyEquivalent: "")
        menu.addItem(withTitle: L("act.tagNew"), action: #selector(mTag(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("act.saveTar"), action: #selector(mSave(_:)), keyEquivalent: "")
        let del = menu.addItem(withTitle: L("act.delete"), action: #selector(mDelete(_:)), keyEquivalent: "")
        del.attributedTitle = NSAttributedString(string: L("act.delete"), attributes: [.foregroundColor: NSColor.systemRed])
        for item in menu.items { item.target = self; item.representedObject = img.ref }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height), in: anchor)
    }

    @objc private func mRun(_ sender: NSMenuItem) {
        if let ref = sender.representedObject as? String { presentSheet(RunContainerSheet(prefillImage: ref)) }
    }
    @objc private func mPush(_ sender: NSMenuItem) {
        guard let ref = sender.representedObject as? String else { return }
        Task { Toast.shared.show(L("push.title", ["ref": ref])); try? await Commands.pushImage(ref); Toast.shared.show(L("push.doneMsg", ["ref": ref])); Store.shared.refresh() }
    }
    @objc private func mTag(_ sender: NSMenuItem) {
        if let ref = sender.representedObject as? String { presentSheet(TagImageSheet(source: ref)) }
    }
    @objc private func mSave(_ sender: NSMenuItem) {
        guard let ref = sender.representedObject as? String else { return }
        Task { @MainActor [weak self] in
            guard let w = self?.view.window else { return }
            let dlg = NSSavePanel()
            dlg.nameFieldStringValue = ref.components(separatedBy: "/").last?.replacingOccurrences(of: ":", with: "_").appending(".tar") ?? "image.tar"
            dlg.beginSheetModal(for: w) { response in
                guard response == .OK, let url = dlg.url else { return }
                Task {
                    try? await Commands.saveImage(ref, to: url.path)
                    await MainActor.run { Toast.shared.show(L("saved.doneMsg", ["path": url.path])) }
                }
            }
        }
    }
    @objc private func mDelete(_ sender: NSMenuItem) {
        guard let ref = sender.representedObject as? String else { return }
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: L("del.img.title", ["ref": ref]), message: L("del.img.msg"), confirm: L("confirm.yes"), on: view.window) else { return }
            try? await Commands.deleteImages([ref])
            Store.shared.refresh()
        }
    }
}

final class ImageRowView: NSTableCellView {
    init(image img: ImageResourceJSON, onMenu: @escaping (ImageResourceJSON, NSView) -> Void) {
        super.init(frame: .zero)
        let ref = makeLabel(img.ref, font: .systemFont(ofSize: 13, weight: .semibold))
        ref.lineBreakMode = .byTruncatingTail
        let id = makeMonoLabel(String(img.id.prefix(12)), size: 11, color: .secondaryLabelColor)
        let refCol = stackV([ref, id], spacing: 3)
        refCol.alignment = .leading
        refCol.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let size = makeLabel(Fmt.bytes(img.configuration.descriptor?.size), font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        size.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let arch = makeMonoLabel("linux/\(img.arch)", size: 11)
        arch.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let created = makeLabel(Fmt.relTime(img.configuration.creationDate), font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        created.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let menu = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)!, target: self, action: #selector(menuTap))
        menu.isBordered = false
        menu.contentTintColor = .secondaryLabelColor
        menu.translatesAutoresizingMaskIntoConstraints = false
        menu.widthAnchor.constraint(equalToConstant: 30).isActive = true
        objc_setAssociatedObject(self, "img", img, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, "cb", onMenu, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        let row = stackH([refCol, size, arch, created, menu], spacing: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        menu.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func menuTap(_ sender: NSButton) {
        guard let img = objc_getAssociatedObject(self, "img") as? ImageResourceJSON,
              let cb = objc_getAssociatedObject(self, "cb") as? (ImageResourceJSON, NSView) -> Void else { return }
        cb(img, sender)
    }
}
