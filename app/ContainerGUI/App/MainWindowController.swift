import AppKit

// Adaptive colors mirrored from design/assets/styles.css for the AppKit sidebar.
private extension NSColor {
    static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}

enum ACSidebarPalette {
    // Solid panel colour = blend of the prototype sidebar-tint over the window base
    // (opaque so it never shows a frosted-glass wash over the desktop behind the window).
    static let solid: NSColor = .adaptive(
        light: NSColor(calibratedRed: 246 / 255, green: 246 / 255, blue: 250 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 40 / 255, green: 40 / 255, blue: 43 / 255, alpha: 1))
}

final class MainWindowController: NSWindowController, NSWindowDelegate, NSSplitViewDelegate {
    private var splitView: NSSplitView!
    private var sidebarVC: SidebarViewController!
    private var contentVC: ContentViewController!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Container"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 980, height: 600)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        // Brand logo in the titlebar (design/ header: icon + "Container").
        if let url = Bundle.module.url(forResource: "logo", withExtension: "png"),
           let logo = NSImage(contentsOf: url) {
            let host = NSView(frame: NSRect(x: 0, y: 0, width: 30, height: 26))
            let iv = NSImageView(image: logo)
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.frame = NSRect(x: 0, y: 1, width: 22, height: 22)
            iv.wantsLayer = true
            iv.layer?.cornerRadius = 5
            iv.layer?.masksToBounds = true
            host.addSubview(iv)
            let accessory = NSTitlebarAccessoryViewController()
            accessory.layoutAttribute = .leading
            accessory.view = host
            window.addTitlebarAccessoryViewController(accessory)
        }

        let sidebarVC = SidebarViewController()
        let contentVC = ContentViewController()
        self.sidebarVC = sidebarVC
        self.contentVC = contentVC

        let sidebarHost = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 760))
        sidebarHost.wantsLayer = true
        sidebarHost.layer?.backgroundColor = ACSidebarPalette.solid.cgColor
        sidebarVC.view.frame = sidebarHost.bounds
        sidebarVC.view.autoresizingMask = [.width, .height]
        sidebarHost.addSubview(sidebarVC.view)

        let split = NSSplitView(frame: window.contentLayoutRect)
        split.isVertical = true
        split.dividerStyle = .thin
        split.delegate = self
        split.addArrangedSubview(sidebarHost)
        split.addArrangedSubview(contentVC.view)
        splitView = split
        window.contentView = split
        split.setPosition(240, ofDividerAt: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        dividerIndex == 0 ? 220 : proposedMinimumPosition
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        dividerIndex == 0 ? 300 : proposedMaximumPosition
    }

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        subview != splitView.arrangedSubviews.last
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

// MARK: - Inspector presentation helper

@MainActor
enum InspectorPresenter {
    static func present(_ vc: InspectorViewController, from page: PageViewController) {
        guard let split = page.view.window?.contentView as? NSSplitView else { return }
        if split.arrangedSubviews.count > 2 {
            let old = split.arrangedSubviews[2]
            split.removeArrangedSubview(old)
            old.removeFromSuperview()
        }
        vc.page = page
        split.addArrangedSubview(vc.view)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        vc.view.widthAnchor.constraint(equalToConstant: 420).isActive = true
    }
}

// MARK: - Sidebar

final class SidebarViewController: NSViewController {
    private var navButtons: [Route: NavButton] = [:]
    private var statusDot: DotView!
    private var statusLabel: NSTextField!

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 700))

        var items: [NSView] = []
        for route in Route.allCases {
            let b = NavButton(route: route)
            b.onSelect = { [weak self] in
                Store.shared.setRoute(route)
                self?.selectRoute(route)
            }
            navButtons[route] = b
            items.append(b)
            if route == .k8s {
                let sep = NSView()
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                sep.wantsLayer = true
                sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
                items.append(sep)
            }
        }
        let navStack = stackV(items, spacing: 2)
        navStack.alignment = .leading
        navStack.translatesAutoresizingMaskIntoConstraints = false

        statusDot = DotView(color: .systemGreen, pulsing: true)
        statusLabel = makeLabel(L("svc.running"), font: .systemFont(ofSize: 12), color: .secondaryLabelColor)

        let footRow = stackH([statusDot, statusLabel], spacing: 8)
        footRow.alignment = .centerY
        let footClick = NSClickGestureRecognizer(target: self, action: #selector(toggleServices))
        footRow.addGestureRecognizer(footClick)

        container.addSubview(navStack)
        container.addSubview(footRow)
        let safeTop = container.safeAreaLayoutGuide.topAnchor
        let safeBottom = container.safeAreaLayoutGuide.bottomAnchor
        NSLayoutConstraint.activate([
            navStack.topAnchor.constraint(equalTo: safeTop, constant: 10),
            navStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            navStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            footRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            footRow.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            footRow.bottomAnchor.constraint(equalTo: safeBottom, constant: -10),
            navStack.bottomAnchor.constraint(lessThanOrEqualTo: footRow.topAnchor, constant: -12),
        ])
        for case let b as NavButton in items {
            b.widthAnchor.constraint(equalTo: navStack.widthAnchor).isActive = true
        }
        view = container

        selectRoute(Store.shared.route)
        NotificationCenter.default.addObserver(self, selector: #selector(storeUpdated), name: .storeDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: .routeDidChange, object: nil)
    }

    func selectRoute(_ r: Route) {
        for (route, b) in navButtons { b.isSelected = (route == r) }
    }

    @objc private func routeChanged(_ note: Notification) {
        guard let route = note.object as? Route else { return }
        selectRoute(route)
    }

    @objc private func storeUpdated() {
        navButtons[.containers]?.badgeValue = Store.shared.runningCount
        statusDot.setColor(Store.shared.servicesRunning ? .systemGreen : .systemGray)
        statusLabel.stringValue = Store.shared.servicesRunning ? L("svc.running") : L("svc.stopped")
        navButtons.forEach { $0.value.refreshTitle() }
    }

    @objc private func toggleServices() {
        Task { @MainActor in
            if Store.shared.servicesRunning {
                guard await ConfirmPanel.confirm(
                    title: L("svc.stopWarnTitle"),
                    message: L("svc.stopWarnMsg"),
                    confirm: L("confirm.stop"), on: view.window) else { return }
                try? await Commands.systemStop()
                Toast.shared.show(L("svc.stopped"))
            } else {
                Toast.shared.show(L("svc.starting"))
                try? await Commands.systemStart()
                Toast.shared.show(L("svc.running"))
            }
            Store.shared.refresh()
        }
    }
}

// MARK: - Nav button

final class NavButton: NSView {
    var onSelect: (() -> Void)?
    var isSelected: Bool = false { didSet { updateLook() } }

    private let highlight = CALayer()
    private let icon = NSImageView()
    private let title = makeLabel("", font: .systemFont(ofSize: 13, weight: .medium))
    private let badge = makeLabel("", font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold), color: .secondaryLabelColor)
    private let route: Route

    var badgeValue: Int = 0 { didSet { badge.stringValue = "\(badgeValue)"; badge.isHidden = badgeValue == 0 } }

    func refreshTitle() { title.stringValue = route.title }

    init(route: Route) {
        self.route = route
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: 34).isActive = true

        highlight.cornerRadius = 7
        layer?.addSublayer(highlight)

        icon.image = NSImage(systemSymbolName: route.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        icon.imageAlignment = .alignLeft
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        title.stringValue = route.title
        title.translatesAutoresizingMaskIntoConstraints = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isHidden = true
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        badge.layer?.cornerRadius = 9
        badge.alignment = .center

        addSubview(icon)
        addSubview(title)
        addSubview(badge)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 9),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),
        ])
        let click = NSClickGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(click)
        updateLook()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateLook() {
        let selected = isSelected
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.88).cgColor
            : NSColor.clear.cgColor
        CATransaction.commit()
        title.textColor = selected ? .white : .labelColor
        icon.contentTintColor = selected ? .white : .systemBlue
        badge.textColor = selected ? .white : .secondaryLabelColor
        badge.layer?.backgroundColor = selected
            ? NSColor.white.withAlphaComponent(0.25).cgColor
            : NSColor.quaternaryLabelColor.cgColor
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() { updateLook() }

    @objc private func tapped() { onSelect?() }
}

// MARK: - Status dot

final class DotView: NSView {
    private var color: NSColor
    private var pulsing: Bool
    private let dot = CALayer()

    init(color: NSColor, pulsing: Bool = false) {
        self.color = color
        self.pulsing = pulsing
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.addSublayer(dot)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 8),
            heightAnchor.constraint(equalToConstant: 8),
        ])
        if pulsing {
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 1
            anim.toValue = 0.45
            anim.duration = 1.2
            anim.autoreverses = true
            anim.repeatCount = .infinity
            dot.add(anim, forKey: "pulse")
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func setColor(_ c: NSColor) {
        color = c
        dot.backgroundColor = c.cgColor
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dot.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        dot.cornerRadius = 4
        dot.backgroundColor = color.cgColor
        CATransaction.commit()
    }
}
