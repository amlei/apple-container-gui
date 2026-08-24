import AppKit

enum Theme {
    static var isDark: Bool { NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }

    enum Color {
        static let accent = NSColor.controlAccentColor
        static let green = NSColor(srgbRed: 0.18, green: 0.80, blue: 0.44, alpha: 1)
        static let red = NSColor.systemRed
        static let orange = NSColor.systemOrange
        static let purple = NSColor.systemPurple
        static let teal = NSColor.systemTeal
        static let label2 = NSColor.secondaryLabelColor
        static let label3 = NSColor.tertiaryLabelColor
        static func cardBg(for appearance: NSAppearance?) -> NSColor {
            appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.13, alpha: 1)
                : NSColor.white
        }

        static func cardBorder(for appearance: NSAppearance?) -> NSColor {
            appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.09)
                : NSColor(white: 0, alpha: 0.10)
        }
        static let canvasBg = NSColor.clear
        static let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        static let monoSmall = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    }
}

extension NSView {
    func cardStyle() -> Self {
        applyCardTheme()
        return self
    }

    func applyCardTheme() {
        let appearance = NSApp?.effectiveAppearance ?? effectiveAppearance
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = Theme.Color.cardBg(for: appearance).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Theme.Color.cardBorder(for: appearance).cgColor
    }
}

/// Card whose layer colors re-resolve when the effective appearance changes.
class CardView: NSView {
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        applyCardTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { applyCardTheme() }
}

/// Vertical stack for use as a scroll-view documentView (top-anchored content).
final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

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
