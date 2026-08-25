import AppKit
import SwiftUI

/// Hosts the SwiftUI content root inside the split view.
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
