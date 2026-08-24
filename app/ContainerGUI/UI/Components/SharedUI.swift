import AppKit
import ExceptionCatcher
import SwiftUI

/// Hosts the page header (title + actions) and swaps page view controllers by route.
final class ContentViewController: NSViewController {
    static weak var current: ContentViewController?
    private let host = NSHostingView(rootView: ContentRootView())

    override func loadView() {
        let root = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: root.topAnchor),
            host.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])
        view = root
        Self.current = self
    }
}

// MARK: - Page base class

@MainActor
class PageViewController: NSViewController {
    let content = NSView()
    weak var searchField: NSSearchField?

    override func loadView() {
        let root = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: root.topAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])
        view = root
        buildContent()
        NotificationCenter.default.addObserver(self, selector: #selector(storeUpdated), name: .storeDidUpdate, object: nil)
    }

    func buildContent() {}
    func reload() {}
    func makeToolbarItems() -> [NSView] { [] }

    func focusSearch() {
        guard let s = searchField else { return }
        view.window?.makeFirstResponder(s)
        s.currentEditor()?.selectAll(nil)
    }

    @discardableResult
    func runPrimary() -> Bool { false }

    @objc private func storeUpdated() {
        if let err = ObjCExceptionCatcher.try { reload() } {
            NSLog("CGUI reload exception:\n%@", err)
        }
    }

    func presentSheet(_ vc: NSViewController) {
        guard let w = view.window else { NSLog("CGUI presentSheet: no window"); return }
        let sheet = NSWindow(contentViewController: vc)
        sheet.styleMask = [.titled, .closable]
        sheet.titleVisibility = .hidden
        sheet.titlebarAppearsTransparent = true
        sheet.standardWindowButton(.closeButton)?.isHidden = true
        sheet.standardWindowButton(.miniaturizeButton)?.isHidden = true
        sheet.standardWindowButton(.zoomButton)?.isHidden = true
        NSLog("CGUI presentSheet frame=%@ content=%@", NSStringFromRect(sheet.frame), String(describing: sheet.contentView))
        let failed = ObjCExceptionCatcher.try {
            w.beginSheet(sheet) { _ in
                Store.shared.refresh()
            }
        }
        if let failed {
            NSLog("CGUI beginSheet exception:\n%@", failed)
        }
    }
}

// MARK: - Toast

@MainActor
final class Toast {
    static let shared = Toast()
    private var window: NSWindow?
    private var hideWork: DispatchWorkItem?

    func show(_ message: String, isError: Bool = false) {
        hideWork?.cancel()
        let w: NSWindow
        if let window { w = window } else {
            w = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = .floating
            w.isOpaque = false
            w.backgroundColor = .clear
            window = w
        }
        let icon = NSImageView(image: NSImage(systemSymbolName: isError ? "xmark.circle.fill" : "checkmark.circle.fill", accessibilityDescription: nil)!)
        icon.contentTintColor = isError ? .systemRed : .systemGreen
        let label = makeLabel(message, font: .systemFont(ofSize: 13, weight: .medium))
        let row = stackH([icon, label], spacing: 8)
        let host = NSView()
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        host.layer?.cornerRadius = 10
        host.layer?.borderWidth = 1
        host.layer?.borderColor = NSColor.separatorColor.cgColor
        host.layer?.shadowOpacity = 0.25
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        w.contentView = host
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: host.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -16),
        ])
        w.setContentSize(host.fittingSize)
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            w.setFrameOrigin(NSPoint(x: f.midX - w.frame.width / 2, y: f.maxY - w.frame.height - 48))
        }
        w.orderFrontRegardless()
        let work = DispatchWorkItem { [weak w] in w?.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: work)
    }
}

// MARK: - Confirmation panel

enum ConfirmPanel {
    @MainActor
    static func confirm(title: String, message: String = "", confirm: String, on window: NSWindow?) async -> Bool {
        let a = NSAlert()
        a.messageText = title
        if !message.isEmpty { a.informativeText = message }
        a.addButton(withTitle: confirm)
        a.addButton(withTitle: L("act.cancel"))
        a.alertStyle = .critical
        guard let w = window else { return a.runModal() == .alertFirstButtonReturn }
        return await withCheckedContinuation { cont in
            a.beginSheetModal(for: w) { resp in
                cont.resume(returning: resp == .alertFirstButtonReturn)
            }
        }
    }
}

// MARK: - Empty state

final class EmptyStateView: NSView {
    private let actionHandler: (() -> Void)?

    init(symbol: String, title: String, hint: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        actionHandler = action
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let baseIcon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()
        let iconImg = baseIcon.withSymbolConfiguration(.init(pointSize: 40, weight: .light)) ?? baseIcon
        let icon = NSImageView(image: iconImg)
        icon.contentTintColor = .tertiaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        let t = makeLabel(title, font: .systemFont(ofSize: 15, weight: .semibold), color: .secondaryLabelColor)
        let h = makeLabel(hint, font: .systemFont(ofSize: 12), color: .tertiaryLabelColor)

        let col = stackV([icon, t, h], spacing: 10)
        col.alignment = .centerX
        col.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col)

        var constraints = [
            col.centerXAnchor.constraint(equalTo: centerXAnchor),
            col.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            heightAnchor.constraint(equalToConstant: 320),
        ]
        if let actionTitle, actionHandler != nil {
            let b = makeButton(actionTitle, symbol: "plus", primary: true)
            b.bezelStyle = .rounded
            b.action = #selector(tap)
            b.target = self
            b.tag = 0
            col.addArrangedSubview(b)
        }
        NSLayoutConstraint.activate(constraints)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tap(_ sender: NSButton) {
        actionHandler?()
    }
}

// MARK: - Table header bar (single-column custom-row tables)

final class TableHeaderBar: NSView {
    /// labels: (title, width); nil width = flexible column
    init(labels: [(String, CGFloat?)]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        var views: [NSView] = []
        for (title, width) in labels {
            let l = makeLabel(title, font: .systemFont(ofSize: 11, weight: .medium), color: .tertiaryLabelColor)
            if let width {
                l.widthAnchor.constraint(equalToConstant: width).isActive = true
            } else {
                l.setContentHuggingPriority(.defaultLow, for: .horizontal)
                l.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
            }
            views.append(l)
        }
        let row = stackH(views, spacing: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Line chart

final class ChartView: NSView {
    private let line = CAShapeLayer()
    private let fill = CAShapeLayer()
    var lineColor: NSColor = .controlAccentColor
    private(set) var values: [Double] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        line.fillColor = nil
        line.lineWidth = 1.8
        line.lineJoin = .round
        fill.opacity = 0.12
        layer?.addSublayer(fill)
        layer?.addSublayer(line)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(_ newValues: [Double]) {
        values = newValues
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        guard w > 4, h > 4 else { return }
        let maxV = max((values.max() ?? 0.0001) * 1.15, 0.0001)
        func pt(_ i: Int) -> NSPoint {
            let x = CGFloat(i) / CGFloat(max(values.count - 1, 1)) * w
            let y = h - CGFloat(values[i] / maxV) * (h - 4) - 2
            return NSPoint(x: x, y: y)
        }
        let path = NSBezierPath()
        for (i, _) in values.enumerated() {
            i == 0 ? path.move(to: pt(i)) : path.line(to: pt(i))
        }
        line.path = path.cgPath
        line.strokeColor = lineColor.cgColor
        let fp = path.copy() as! NSBezierPath
        fp.line(to: NSPoint(x: w, y: 0))
        fp.line(to: NSPoint(x: 0, y: 0))
        fp.close()
        fill.path = fp.cgPath
        fill.fillColor = lineColor.cgColor
    }
}

// MARK: - KV editor (rows of two text fields + delete)

final class KVEditor: NSView {
    private let stack = stackV([], spacing: 6)
    var placeholder1 = "key"
    var placeholder2 = "value"

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        let add = NSButton(title: L("act.add"), target: self, action: #selector(addRow))
        add.isBordered = false
        add.font = .systemFont(ofSize: 12)
        add.contentTintColor = .controlAccentColor
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
        add.imagePosition = .imageLeading
        add.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        addSubview(add)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            add.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 4),
            add.leadingAnchor.constraint(equalTo: leadingAnchor),
            add.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setPlaceholders(_ p1: String, _ p2: String) {
        placeholder1 = p1
        placeholder2 = p2
    }

    func addRow(v1: String = "", v2: String = "") {
        let f1 = NSTextField(string: v1)
        f1.placeholderString = placeholder1
        f1.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let f2 = NSTextField(string: v2)
        f2.placeholderString = placeholder2
        f2.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let del = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!, target: self, action: #selector(delRow(_:)))
        del.isBordered = false
        del.contentTintColor = .tertiaryLabelColor
        let row = stackH([f1, f2, del], spacing: 6)
        row.distribution = .fill
        f1.setContentHuggingPriority(.defaultLow, for: .horizontal)
        f2.setContentHuggingPriority(.defaultLow, for: .horizontal)
        f1.widthAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
        f2.widthAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
        stack.addArrangedSubview(row)
    }

    @objc private func delRow(_ sender: NSButton) {
        guard let row = sender.superview as? NSStackView else { return }
        stack.removeArrangedSubview(row)
        row.removeFromSuperview()
    }

    @objc private func addRow() { addRow() }

    func collect() -> [(String, String)] {
        stack.arrangedSubviews.compactMap { row in
            let fields = row.subviews.compactMap { $0 as? NSTextField }
            guard fields.count >= 2 else { return nil }
            let a = fields[0].stringValue.trimmingCharacters(in: .whitespaces)
            let b = fields[1].stringValue.trimmingCharacters(in: .whitespaces)
            guard !a.isEmpty || !b.isEmpty else { return nil }
            return (a, b)
        }
    }
}
