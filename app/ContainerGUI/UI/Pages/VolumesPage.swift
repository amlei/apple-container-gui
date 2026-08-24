import AppKit

final class VolumesPage: PageViewController {
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
        table.rowHeight = 44
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
            (L("vol.name"), 260), (L("vol.size"), 80), (L("vol.journal"), 90), (L("vol.created"), 90), ("", 30),
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

    private var filtered: [VolumeResourceJSON] {
        var rows = Store.shared.volumes
        if !search.isEmpty { rows = rows.filter { $0.name.lowercased().contains(search.lowercased()) } }
        return rows
    }

    override func reload() {
        guard table != nil else { return }
        table.reloadData()
        let rows = filtered
        if rows.isEmpty {
            if emptyView == nil {
                let e = Store.shared.volumes.isEmpty
                    ? EmptyStateView(symbol: "externaldrive", title: L("vol.empty"), hint: L("vol.empty.hint"), actionTitle: L("vol.new.title")) { [weak self] in self?.presentSheet(NewVolumeSheet()) }
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
        let field = NSSearchField()
        field.placeholderString = L("search.ph.volumes")
        field.controlSize = .small
        field.target = self
        field.action = #selector(searchChanged)
        field.widthAnchor.constraint(equalToConstant: 220).isActive = true
        searchField = field

        return [
            field,
            makeButton(L("vol.new.title"), symbol: "plus", primary: true) { [weak self] in self?.presentSheet(NewVolumeSheet()) },
        ]
    }

    @discardableResult
    override func runPrimary() -> Bool {
        presentSheet(NewVolumeSheet())
        return true
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        search = sender.stringValue
        table.reloadData()
    }

    private func deleteVolume(_ v: VolumeResourceJSON) {
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: L("del.vol.title", ["n": v.name]), message: L("del.vol.msg"), confirm: L("confirm.yes"), on: view.window) else { return }
            try? await Commands.deleteVolumes([v.name])
            Store.shared.refresh()
        }
    }
}

extension VolumesPage: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        VolumeRowView(volume: filtered[row]) { [weak self] v in self?.deleteVolume(v) }
    }
}

final class VolumeRowView: NSTableCellView {
    init(volume v: VolumeResourceJSON, onDelete: @escaping (VolumeResourceJSON) -> Void) {
        super.init(frame: .zero)
        let name = makeLabel(v.name, font: .systemFont(ofSize: 13, weight: .semibold))
        name.lineBreakMode = .byTruncatingTail
        name.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let size = makeLabel(v.configuration.sizeInBytes.map { Fmt.bytes($0) } ?? "—", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        size.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let journal = makeLabel(v.journalMode ?? "—", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        journal.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let created = makeLabel(Fmt.relTime(v.configuration.creationDate), font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        created.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let del = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: nil)!, target: self, action: #selector(tapDel))
        del.isBordered = false
        del.contentTintColor = .systemRed
        del.translatesAutoresizingMaskIntoConstraints = false
        del.widthAnchor.constraint(equalToConstant: 30).isActive = true
        objc_setAssociatedObject(self, "vol", v, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, "cb", onDelete, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        let row = stackH([name, size, journal, created, del], spacing: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        del.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapDel(_ sender: NSButton) {
        guard let v = objc_getAssociatedObject(self, "vol") as? VolumeResourceJSON,
              let cb = objc_getAssociatedObject(self, "cb") as? (VolumeResourceJSON) -> Void else { return }
        cb(v)
    }
}
