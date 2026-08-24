import AppKit

@MainActor
class InspectorViewController: NSViewController {
    weak var page: PageViewController?
    let headerTitle = makeLabel("", font: .systemFont(ofSize: 15, weight: .bold))
    let headerSub = makeMonoLabel("", size: 11, color: .secondaryLabelColor)
    let body = stackV([], spacing: 10)
    let closeButton: NSButton

    init() {
        closeButton = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!, target: nil, action: nil)
        super.init(nibName: nil, bundle: nil)
        closeButton.isBordered = false
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeRequested)
        preferredContentSize = NSSize(width: 420, height: 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()
        let head = stackH([stackV([headerTitle, headerSub], spacing: 2), NSView(), closeButton], spacing: 8)
        head.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.documentView = body
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        body.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        root.addSubview(head)
        root.addSubview(scroll)
        NSLayoutConstraint.activate([
            head.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            head.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            head.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scroll.topAnchor.constraint(equalTo: head.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
        ])
        view = root
        buildBody()
        NotificationCenter.default.addObserver(self, selector: #selector(closeRequested), name: .closeInspector, object: nil)
    }

    func buildBody() {}

    @objc func closeRequested() {
        NotificationCenter.default.removeObserver(self)
        if let split = view.superview as? NSSplitView {
            split.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    func kvRow(_ key: String, _ value: String) -> NSView {
        KVRow(key: key, value: value)
    }
}

// MARK: - Container inspector with tabs

final class ContainerInspector: InspectorViewController {
    private let containerID: String
    private var tabBar = NSSegmentedControl()
    private let tabBody = stackV([], spacing: 10)
    private var logHandle: ProcessHandle?
    private var statsTimer: Timer?
    private var cpuChart: ChartView?
    private var memChart: ChartView?
    private var netChart: ChartView?
    private var cpuValues: [Double] = []
    private var memValues: [Double] = []
    private var rxValues: [Double] = []
    private var txValues: [Double] = []
    private var terminalView: TerminalView?

    init(containerID: String) {
        self.containerID = containerID
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        headerTitle.stringValue = containerID
    }

    override func buildBody() {
        let labels = [L("ct.tab.info"), L("ct.tab.logs"), L("ct.tab.stats"), L("ct.tab.term")]
        tabBar = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: self, action: #selector(tabChanged))
        tabBar.segmentStyle = .rounded
        tabBar.segmentDistribution = .fillEqually
        tabBar.controlSize = .small
        tabBar.selectedSegment = 0
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(tabBar)
        tabBar.leadingAnchor.constraint(equalTo: body.leadingAnchor).isActive = true
        tabBar.trailingAnchor.constraint(equalTo: body.trailingAnchor).isActive = true

        body.addArrangedSubview(tabBody)
        tabBody.leadingAnchor.constraint(equalTo: body.leadingAnchor).isActive = true
        tabBody.trailingAnchor.constraint(equalTo: body.trailingAnchor).isActive = true

        showTab(0)
    }

    @objc private func tabChanged() { showTab(tabBar.selectedSegment) }

    private func showTab(_ idx: Int) {
        stopLoops()
        tabBody.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch idx {
        case 0: showInfo()
        case 1: showLogs()
        case 2: showStats()
        case 3: showTerminal()
        default: break
        }
    }

    private func stopLoops() {
        logHandle?.terminate()
        logHandle = nil
        statsTimer?.invalidate()
        statsTimer = nil
        terminalView = nil
    }

    private func showInfo() {
        guard let c = Store.shared.containers.first(where: { $0.id == containerID }) else { return }
        let card = CardView()
        let col = stackV([], spacing: 8)
        col.addArrangedSubview(kvRow(L("ct.d.id"), c.id))
        col.addArrangedSubview(kvRow(L("ct.image"), c.imageRef))
        col.addArrangedSubview(kvRow(L("ct.status"), c.status.state?.rawValue ?? "—"))
        col.addArrangedSubview(kvRow(L("ct.ip"), c.ip))
        if let p = c.configuration.platform { col.addArrangedSubview(kvRow(L("ct.d.arch"), "\(p.os)/\(p.architecture)")) }
        if let r = c.configuration.resources {
            col.addArrangedSubview(kvRow(L("run.res"), "\(r.cpus ?? 0) CPU · \(Fmt.bytes(r.memoryInBytes))"))
        }
        col.addArrangedSubview(kvRow(L("ct.created"), Fmt.dateTime(c.status.startedDate)))
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            col.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            col.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            col.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        tabBody.addArrangedSubview(card)
    }

    private func showLogs() {
        let scroll = NSScrollView()
        let tv = NSTextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.autoresizingMask = [.width]
        tv.isVerticallyResizable = true
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let card = CardView()
        card.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            card.heightAnchor.constraint(equalToConstant: 420),
        ])
        tv.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        tabBody.addArrangedSubview(card)

        let handle = CLIRunner.stream(["logs", "-f", containerID]) { [weak self, weak tv] line in
            DispatchQueue.main.async {
                tv?.textStorage?.append(NSAttributedString(string: line + "\n", attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.labelColor]))
                tv?.scrollRangeToVisible(NSRange(location: (tv?.string.count ?? 1) - 1, length: 1))
            }
            _ = self
        }
        logHandle = handle
    }

    private func showStats() {
        let cpuCard = chartCard(title: L("stats.cpu"), color: .controlAccentColor)
        let memCard = chartCard(title: L("stats.mem"), color: .systemPurple)
        let netCard = chartCard(title: L("stats.net"), color: .systemTeal)
        cpuChart = cpuCard.0
        memChart = memCard.0
        netChart = netCard.0
        tabBody.addArrangedSubview(cpuCard.1)
        tabBody.addArrangedSubview(memCard.1)
        tabBody.addArrangedSubview(netCard.1)

        statsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let snap = await Commands.stats(id: self.containerID) else { return }
                self.cpuValues.append(snap.cpuPercent)
                if self.cpuValues.count > 60 { self.cpuValues.removeFirst() }
                self.memValues.append(Double(snap.memoryUsageBytes ?? 0))
                if self.memValues.count > 60 { self.memValues.removeFirst() }
                self.rxValues.append(Double(snap.networkRxBytes ?? 0))
                if self.rxValues.count > 60 { self.rxValues.removeFirst() }
                self.txValues.append(Double(snap.networkTxBytes ?? 0))
                if self.txValues.count > 60 { self.txValues.removeFirst() }
                self.cpuChart?.update(self.cpuValues)
                self.memChart?.update(self.memValues)
                self.netChart?.update(self.rxValues + self.txValues)
            }
        }
    }

    private func chartCard(title: String, color: NSColor) -> (ChartView, NSView) {
        let chart = ChartView()
        chart.lineColor = color
        chart.translatesAutoresizingMaskIntoConstraints = false
        let card = CardView()
        let t = makeLabel(title, font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabelColor)
        card.addSubview(t)
        card.addSubview(chart)
        NSLayoutConstraint.activate([
            t.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            t.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            chart.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 6),
            chart.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            chart.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            chart.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            card.heightAnchor.constraint(equalToConstant: 110),
        ])
        chart.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -24).isActive = true
        return (chart, card)
    }

    private func showTerminal() {
        let term = TerminalView(command: ["exec", "-it", containerID, "/bin/sh"])
        term.heightAnchor.constraint(equalToConstant: 420).isActive = true
        tabBody.addArrangedSubview(term)
        terminalView = term
        DispatchQueue.main.async { term.focusInput() }
    }
}

// MARK: - Image inspector

final class ImageInspector: InspectorViewController {
    private let image: ImageResourceJSON

    init(image: ImageResourceJSON) {
        self.image = image
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        headerTitle.stringValue = image.ref
        headerSub.stringValue = String(image.id.prefix(19))
    }

    override func buildBody() {
        let actions = stackH([
            makeButton(L("act.runContainer"), symbol: "play.fill", small: true) { [weak self] in
                guard let self else { return }
                self.closeRequested()
                self.page?.presentSheet(RunContainerSheet(prefill: self.image.ref))
            },
            makeButton(L("act.tagNew"), symbol: "tag", small: true) { [weak self] in
                guard let self else { return }
                self.closeRequested()
                self.page?.presentSheet(TagImageSheet(source: self.image.ref))
            },
        ], spacing: 8)
        body.addArrangedSubview(actions)

        let card = CardView()
        let col = stackV([], spacing: 8)
        col.addArrangedSubview(kvRow("ID", String(image.id.prefix(24))))
        col.addArrangedSubview(kvRow(L("img.size"), Fmt.bytes(image.configuration.descriptor?.size)))
        col.addArrangedSubview(kvRow(L("img.osarch"), "linux/\(image.arch)"))
        col.addArrangedSubview(kvRow("digest", String(image.configuration.descriptor?.digest.prefix(31) ?? "—")))
        col.addArrangedSubview(kvRow(L("img.created"), Fmt.dateTime(image.configuration.creationDate)))
        if !image.cmdText.isEmpty { col.addArrangedSubview(kvRow("CMD", image.cmdText)) }
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            col.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            col.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            col.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        body.addArrangedSubview(card)
    }
}

// MARK: - System logs inspector

final class SystemLogsInspector: InspectorViewController {
    private var handle: ProcessHandle?

    override func loadView() {
        super.loadView()
        headerTitle.stringValue = L("syslog.title")
    }

    override func buildBody() {
        let scroll = NSScrollView()
        let tv = NSTextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        tv.autoresizingMask = [.width]
        tv.isVerticallyResizable = true
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let card = CardView()
        card.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            card.heightAnchor.constraint(equalToConstant: 480),
        ])
        tv.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        body.addArrangedSubview(card)

        handle = CLIRunner.stream(["system", "logs", "--last", "5m"]) { line in
            DispatchQueue.main.async {
                tv.textStorage?.append(NSAttributedString(string: line + "\n", attributes: [.font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]))
                tv.scrollRangeToVisible(NSRange(location: tv.string.count - 1, length: 1))
            }
        }
    }
}
