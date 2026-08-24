import AppKit

final class NetworksPage: PageViewController {
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
        let nets = Store.shared.networks
        if nets.isEmpty {
            grid.addArrangedSubview(EmptyStateView(symbol: "globe", title: L("net.empty"), hint: L("net.empty.hint"), actionTitle: L("net.new.title")) { [weak self] in self?.presentSheet(NewNetworkSheet()) })
        }
        for n in nets {
            grid.addArrangedSubview(NetworkCard(network: n) { [weak self] in self?.deleteNetwork(n) })
        }
    }

    override func makeToolbarItems() -> [NSView] {
        [makeButton(L("net.new.title"), symbol: "plus", primary: true) { [weak self] in self?.presentSheet(NewNetworkSheet()) }]
    }

    @discardableResult
    override func runPrimary() -> Bool {
        presentSheet(NewNetworkSheet())
        return true
    }

    private func deleteNetwork(_ n: NetworkResourceJSON) {
        Task { @MainActor in
            guard await ConfirmPanel.confirm(title: L("del.net.title", ["n": n.name]), message: L("del.net.msg"), confirm: L("confirm.yes"), on: view.window) else { return }
            try? await Commands.deleteNetworks([n.name])
            Store.shared.refresh()
        }
    }
}

final class NetworkCard: NSView {
    init(network n: NetworkResourceJSON, onDelete: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cardStyle()
        widthAnchor.constraint(equalToConstant: 460).isActive = true

        let title = stackH([
            sfIcon("globe", size: 13),
            makeLabel(n.name, font: .systemFont(ofSize: 14, weight: .semibold)),
            n.name == "default" ? Pill(text: L("net.default.tag"), color: .controlAccentColor) : nil,
            n.configuration.mode == "internal" ? Pill(text: L("net.internal"), color: .systemPurple) : nil,
        ].compactMap { $0 }, spacing: 8)

        let meta = stackV([
            makeMonoLabel("IPv4: \(n.status?.ipv4Subnet ?? "—")   gateway: \(n.status?.ipv4Gateway ?? "—")", size: 11),
            makeMonoLabel("IPv6: \(n.status?.ipv6Subnet ?? "—")", size: 11),
            makeMonoLabel("plugin: \(n.configuration.plugin ?? "—") · mode: \(n.configuration.mode ?? "—")", size: 11),
        ], spacing: 4)
        meta.alignment = .leading

        let col = stackV([title, meta], spacing: 10)
        col.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            col.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            col.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            col.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
        ])

        if !n.isSystem {
            let del = makeButton(L("act.delete"), symbol: "trash", danger: true, small: true)
            del.target = self
            del.action = #selector(tapDel)
            objc_setAssociatedObject(self, "cb", onDelete, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            del.translatesAutoresizingMaskIntoConstraints = false
            addSubview(del)
            NSLayoutConstraint.activate([
                del.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
                del.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            ])
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { cardStyle() }

    @objc private func tapDel() {
        (objc_getAssociatedObject(self, "cb") as? () -> Void)?()
    }
}

final class Pill: NSView {
    private let tintColor: NSColor

    init(text: String, color: NSColor) {
        tintColor = color
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        let l = makeLabel(text, font: .systemFont(ofSize: 10, weight: .semibold), color: color)
        l.translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        addSubview(l)
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            l.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            l.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            l.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
        apply()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { apply() }

    private func apply() {
        layer?.backgroundColor = tintColor.withAlphaComponent(0.14).cgColor
        layer?.borderColor = tintColor.withAlphaComponent(0.3).cgColor
    }
}
