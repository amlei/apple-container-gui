import AppKit

final class OverviewPage: PageViewController {
    private var tilesStack: NSStackView!
    private var dfStack: NSStackView!
    private var serviceStack: NSStackView!

    override func buildContent() {
        let tilesRow = NSStackView()
        tilesRow.spacing = 12
        tilesRow.translatesAutoresizingMaskIntoConstraints = false

        let dfCard = CardView()
        let svcCard = CardView()

        let dfTitle = makeLabel(L("ov.disk"), font: .systemFont(ofSize: 14, weight: .semibold))
        let dfSub = makeLabel(L("ov.disk.sub"), font: .systemFont(ofSize: 11), color: .tertiaryLabelColor)
        let maintainBtn = makeButton(L("act.maintain"), symbol: "arrow.3.trianglepath", small: true)
        maintainBtn.target = self
        maintainBtn.action = #selector(showMaintainMenu(_:))
        dfStack = stackV([], spacing: 12)
        dfStack.translatesAutoresizingMaskIntoConstraints = false

        let svcTitle = makeLabel(L("ov.service"), font: .systemFont(ofSize: 14, weight: .semibold))
        serviceStack = stackV([], spacing: 8)
        serviceStack.translatesAutoresizingMaskIntoConstraints = false

        for card in [dfCard, svcCard] {
            card.translatesAutoresizingMaskIntoConstraints = false
        }

        content.addSubview(tilesRow)
        content.addSubview(dfCard)
        content.addSubview(svcCard)
        dfCard.addSubview(dfTitle); dfCard.addSubview(dfSub); dfCard.addSubview(dfStack); dfCard.addSubview(maintainBtn)
        svcCard.addSubview(svcTitle); svcCard.addSubview(serviceStack)

        NSLayoutConstraint.activate([
            tilesRow.topAnchor.constraint(equalTo: content.topAnchor),
            tilesRow.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tilesRow.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor),
            dfCard.topAnchor.constraint(equalTo: tilesRow.bottomAnchor, constant: 14),
            dfCard.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            dfCard.widthAnchor.constraint(equalTo: content.widthAnchor, multiplier: 0.55),
            dfCard.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            svcCard.topAnchor.constraint(equalTo: dfCard.topAnchor),
            svcCard.leadingAnchor.constraint(equalTo: dfCard.trailingAnchor, constant: 14),
            svcCard.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            svcCard.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            dfTitle.topAnchor.constraint(equalTo: dfCard.topAnchor, constant: 16),
            dfTitle.leadingAnchor.constraint(equalTo: dfCard.leadingAnchor, constant: 18),
            dfSub.centerYAnchor.constraint(equalTo: dfTitle.centerYAnchor),
            dfSub.leadingAnchor.constraint(equalTo: dfTitle.trailingAnchor, constant: 8),
            maintainBtn.centerYAnchor.constraint(equalTo: dfTitle.centerYAnchor),
            maintainBtn.trailingAnchor.constraint(equalTo: dfCard.trailingAnchor, constant: -14),
            dfStack.topAnchor.constraint(equalTo: dfTitle.bottomAnchor, constant: 14),
            dfStack.leadingAnchor.constraint(equalTo: dfCard.leadingAnchor, constant: 18),
            dfStack.trailingAnchor.constraint(lessThanOrEqualTo: maintainBtn.leadingAnchor, constant: -12),

            svcTitle.topAnchor.constraint(equalTo: svcCard.topAnchor, constant: 16),
            svcTitle.leadingAnchor.constraint(equalTo: svcCard.leadingAnchor, constant: 18),
            serviceStack.topAnchor.constraint(equalTo: svcTitle.bottomAnchor, constant: 12),
            serviceStack.leadingAnchor.constraint(equalTo: svcCard.leadingAnchor, constant: 18),
            serviceStack.trailingAnchor.constraint(lessThanOrEqualTo: svcCard.trailingAnchor, constant: -18),
        ])
        tilesStack = tilesRow
        reload()
    }

    @objc private func showMaintainMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let items: [(String, String, Bool)] = [
            (L("act.pruneContainers"), "containers", false),
            ("", "", false),
            (L("act.pruneDangling"), "dangling", false),
            (L("act.pruneUnusedImages"), "unusedImages", true),
            ("", "", false),
            (L("act.pruneVolumes"), "volumes", true),
            (L("act.pruneNetworks"), "networks", true),
        ]
        for (title, tag, _) in items {
            if title.isEmpty { menu.addItem(.separator()); continue }
            let it = menu.addItem(withTitle: title, action: #selector(maintainTap(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = tag
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func maintainTap(_ sender: NSMenuItem) {
        guard let kind = sender.representedObject as? String else { return }
        Task { @MainActor in
            let needsConfirm = ["unusedImages", "volumes", "networks"].contains(kind)
            if needsConfirm {
                let msg: String = switch kind {
                case "unusedImages": L("prune.imga.title")
                case "volumes": L("prune.vol.title")
                default: L("prune.net.title")
                }
                guard await ConfirmPanel.confirm(title: msg, confirm: L("confirm.prune"), on: view.window) else { return }
            }
            do {
                switch kind {
                case "containers": try await Commands.pruneContainers()
                case "dangling": try await Commands.pruneImages(all: false)
                case "unusedImages": try await Commands.pruneImages(all: true)
                case "volumes": try await Commands.pruneVolumes()
                case "networks": try await Commands.pruneNetworks()
                default: break
                }
                Toast.shared.show(L("prune.done"))
                Store.shared.refresh()
                Store.shared.refreshSystemInfo()
            } catch {
                Toast.shared.show(error.localizedDescription, isError: true)
            }
        }
    }

    override func reload() {
        let s = Store.shared
        // tiles
        tilesStack?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let tileDefs: [(String, String, String, Route)] = [
            (L("ov.tiles.containers"), "\(s.runningCount)", "/ \(s.containers.count)", .containers),
            (L("ov.tiles.images"), "\(s.images.count)", "", .images),
            (L("ov.tiles.volumes"), "\(s.volumes.count)", "", .volumes),
            (L("ov.tiles.networks"), "\(s.networks.filter { !$0.isSystem }.count)", "", .networks),
        ]
        for (title, value, sub, route) in tileDefs {
            let tile = StatTile(title: title, value: value, sub: sub) { Store.shared.setRoute(route) }
            tile.widthAnchor.constraint(equalToConstant: 215).isActive = true
            tilesStack.addArrangedSubview(tile)
        }
        // disk usage rows
        dfStack?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let df = s.df {
            let rows: [(String, DfSection?)] = [
                (L("ov.disk.images"), df.images),
                (L("ov.disk.containers"), df.containers),
                (L("ov.disk.volumes"), df.volumes),
            ]
            for (label, sec) in rows {
                dfStack.addArrangedSubview(DiskRow(label: label, section: sec))
            }
        } else if !s.servicesRunning {
            dfStack.addArrangedSubview(makeLabel(L("svc.notRunning.banner.msg"), font: .systemFont(ofSize: 12), color: .tertiaryLabelColor))
        }
        // service info
        serviceStack?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let state = stackH([
            DotView(color: s.servicesRunning ? .systemGreen : .systemGray, pulsing: s.servicesRunning),
            makeLabel(s.servicesRunning ? L("st.running") : L("st.exited"), font: .systemFont(ofSize: 12, weight: .medium)),
        ], spacing: 6)
        serviceStack.addArrangedSubview(state)
        let kv: [(String, String)] = [
            (L("ov.service.version.cli"), "container " + s.cliVersion),
            (L("ov.service.version.api"), s.apiVersion),
            (L("ov.service.registry"), s.registries.first ?? "docker.io"),
            (L("ov.service.dns"), s.dnsDomains.first.map { ".\($0)" } ?? "—"),
        ]
        for (k, v) in kv {
            let row = KVRow(key: k, value: v)
            serviceStack.addArrangedSubview(row)
            row.leadingAnchor.constraint(equalTo: serviceStack.leadingAnchor).isActive = true
        }
    }
}

// MARK: - Tile

final class StatTile: NSView {
    private let valueLabel = makeLabel("", font: .systemFont(ofSize: 26, weight: .bold))
    private let subLabel = makeLabel("", font: .systemFont(ofSize: 13, weight: .regular), color: .tertiaryLabelColor)

    init(title: String, value: String, sub: String, action: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cardStyle()
        let t = makeLabel(title, font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor)
        valueLabel.stringValue = value
        subLabel.stringValue = sub
        subLabel.isHidden = sub.isEmpty
        let col = stackV([t, stackH([valueLabel, subLabel], spacing: 4)], spacing: 6)
        col.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            col.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            col.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 86),
        ])
        let click = NSClickGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(click)
        objc_setAssociatedObject(self, "action", action, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() { cardStyle() }
    @objc private func tapped() {
        if let a = objc_getAssociatedObject(self, "action") as? () -> Void { a() }
    }
}

// MARK: - Disk usage row

final class DiskRow: NSView {
    init(label: String, section: DfSection?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let lab = makeLabel(label, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        lab.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let bar = DiskBar(section: section)
        let meta = makeLabel(metaText(section), font: .systemFont(ofSize: 11), color: .tertiaryLabelColor)
        let row = stackV([
            stackH([lab], spacing: 8),
            bar,
            meta,
        ], spacing: 4)
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func metaText(_ s: DfSection?) -> String {
        guard let s else { return "—" }
        let rec = s.reclaimable ?? 0
        let active = s.sizeInBytes.map { $0 >= rec ? $0 - rec : 0 } ?? 0
        return "\(Fmt.bytes(active)) + \(Fmt.bytes(rec)) \(L("ov.disk.reclaimable")) · \(Fmt.bytes(s.sizeInBytes))"
    }
}

final class DiskBar: NSView {
    private let used = CALayer()
    private let reclaim = CALayer()
    private let section: DfSection?

    init(section: DfSection?) {
        self.section = section
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: 8).isActive = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
        layer?.addSublayer(used)
        layer?.addSublayer(reclaim)
        applyColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { applyColors() }

    private func applyColors() {
        layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        used.backgroundColor = NSColor.controlAccentColor.cgColor
        reclaim.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.7).cgColor
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let total = Double(section?.sizeInBytes ?? 0)
        let recPct = total > 0 ? Double(section?.reclaimable ?? 0) / total : 0
        let usedPct = total > 0 ? min(1, (total - Double(section?.reclaimable ?? 0)) / total) : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        used.frame = CGRect(x: 0, y: 0, width: w * CGFloat(usedPct), height: 8)
        reclaim.frame = CGRect(x: used.frame.width, y: 0, width: w * CGFloat(recPct), height: 8)
        CATransaction.commit()
    }
}

// MARK: - KV row (settings/overview)

final class KVRow: NSView {
    init(key: String, value: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let k = makeLabel(key, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        k.widthAnchor.constraint(equalToConstant: 130).isActive = true
        let v = makeMonoLabel(value, size: 11.5, color: .labelColor)
        let row = stackH([k, v], spacing: 12)
        row.alignment = .firstBaseline
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}
