import AppKit

/// Captures one key-combo for a keymap action using a transient event monitor.
enum ShortcutRecorder {
    /// Returns a monitor token (pass to `stop`). `onCapture` fires with the canonical
    /// combo string, `onCancel` when the user presses Escape, and `onInvalid` when a
    /// key is pressed that lacks a required modifier (⌘/⌃/⌥ or an F-key).
    @discardableResult
    static func start(onCapture: @escaping (String) -> Void, onCancel: @escaping () -> Void,
                      onInvalid: @escaping () -> Void) -> Any? {
        var token: Any?
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                if let t = token { NSEvent.removeMonitor(t) }
                onCancel()
                return nil
            }
            guard let combo = combo(from: event) else { return nil }
            if !isAcceptable(combo) {
                if let t = token { NSEvent.removeMonitor(t) }
                onInvalid()
                return nil
            }
            if let t = token { NSEvent.removeMonitor(t) }
            onCapture(combo)
            return nil
        }
        return token
    }

    static func stop(_ token: Any?) {
        if let t = token { NSEvent.removeMonitor(t) }
    }

    private static func combo(from event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        var parts: [String] = []
        if flags.contains(.command) { parts.append("Mod") }
        if flags.contains(.control) { parts.append("Ctrl") }
        if flags.contains(.option) { parts.append("Alt") }
        if flags.contains(.shift) { parts.append("Shift") }
        let key = keyString(event)
        let hasModifier = flags.contains(.command) || flags.contains(.control) || flags.contains(.option)
        let isFKey = key.hasPrefix("F")
        guard hasModifier || isFKey else { return nil }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    private static func isAcceptable(_ combo: String) -> Bool {
        let parts = combo.split(separator: "+").map(String.init)
        let key = parts.last ?? ""
        let hasRequired = parts.dropLast().contains { ["Mod", "Ctrl", "Alt"].contains($0) }
        return hasRequired || key.hasPrefix("F")
    }

    private static func keyString(_ event: NSEvent) -> String {
        let fcodes: [UInt16: String] = [
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        if let f = fcodes[event.keyCode] { return f }
        let chars = event.charactersIgnoringModifiers ?? ""
        guard chars.count == 1, let c = chars.first else { return "?" }
        return c.uppercased()
    }
}
