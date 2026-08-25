import AppKit

// MARK: - AppKit layout helpers (used by the sidebar, toast, and confirmation panel)

func makeLabel(_ text: String = "", font: NSFont = .systemFont(ofSize: 13), color: NSColor = .labelColor) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = font
    l.textColor = color
    l.translatesAutoresizingMaskIntoConstraints = false
    return l
}

func makeMonoLabel(_ text: String = "", size: CGFloat = 12, color: NSColor = .secondaryLabelColor) -> NSTextField {
    let l = NSTextField(wrappingLabelWithString: text)
    l.font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    l.textColor = color
    l.drawsBackground = false
    l.isBezeled = false
    l.translatesAutoresizingMaskIntoConstraints = false
    return l
}

func sfIcon(_ name: String, size: CGFloat = 15, weight: NSFont.Weight = .regular) -> NSImageView {
    let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: size, weight: weight))
    let v = NSImageView(image: img ?? NSImage())
    v.translatesAutoresizingMaskIntoConstraints = false
    v.contentTintColor = .secondaryLabelColor
    return v
}

func makeButton(_ title: String, symbol: String? = nil, primary: Bool = false, danger: Bool = false, small: Bool = false) -> NSButton {
    let b = NSButton(title: title, target: nil, action: nil)
    b.bezelStyle = small ? .rounded : .regularSquare
    b.controlSize = small ? .small : .regular
    b.setButtonType(.momentaryPushIn)
    b.translatesAutoresizingMaskIntoConstraints = false
    b.contentTintColor = danger ? .systemRed : nil
    if let sym = symbol {
        b.image = NSImage(systemSymbolName: sym, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: small ? 11 : 13, weight: .medium))
        b.imagePosition = .imageLeading
    }
    return b
}

final class ButtonTrampoline: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func fire() { action() }
}

func makeButton(_ title: String, symbol: String? = nil, primary: Bool = false, danger: Bool = false, small: Bool = false,
                action: @escaping () -> Void) -> NSButton {
    let b = makeButton(title, symbol: symbol, primary: primary, danger: danger, small: small)
    let trampoline = ButtonTrampoline(action)
    b.target = trampoline
    b.action = #selector(ButtonTrampoline.fire)
    objc_setAssociatedObject(b, "trampoline", trampoline, .OBJC_ASSOCIATION_RETAIN)
    return b
}

func stackV(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
    let s = NSStackView(views: views)
    s.orientation = .vertical
    s.spacing = spacing
    s.alignment = .leading
    s.translatesAutoresizingMaskIntoConstraints = false
    return s
}

func stackH(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
    let s = NSStackView(views: views)
    s.spacing = spacing
    s.alignment = .centerY
    s.translatesAutoresizingMaskIntoConstraints = false
    return s
}
