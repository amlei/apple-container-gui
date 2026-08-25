import AppKit

extension Notification.Name {
    static let keymapChanged = Notification.Name("keymapChanged")
}

/// In-app shortcut map. Combo strings are canonical, e.g. "Mod+1", "Ctrl+Alt+8".
enum Keymap {
    static let defaults: [String: String] = [
        "nav.overview": "Mod+1",
        "nav.containers": "Mod+2",
        "nav.images": "Mod+3",
        "nav.volumes": "Mod+4",
        "nav.networks": "Mod+5",
        "nav.machines": "Mod+6",
        "nav.k8s": "Mod+7",
        "nav.settings": "Mod+8",
        "focus.search": "Mod+F",
        "primary.action": "Mod+N",
    ]

    static let order: [String] = [
        "nav.overview", "nav.containers", "nav.images", "nav.volumes",
        "nav.networks", "nav.machines", "nav.k8s", "nav.settings",
        "focus.search", "primary.action",
    ]

    private static let storageKey = "appKeymap"

    static var map: [String: String] {
        var m = defaults
        if let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] {
            for (k, v) in saved where defaults[k] != nil && !v.isEmpty { m[k] = v }
        }
        return m
    }

    static func combo(_ action: String) -> String { map[action] ?? "" }

    static func set(_ action: String, _ combo: String) {
        var saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
        for k in saved.keys where saved[k] == combo && k != action { saved[k] = "" }
        saved[action] = combo
        UserDefaults.standard.set(saved, forKey: storageKey)
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: storageKey) }

    static func pretty(_ combo: String) -> String {
        guard !combo.isEmpty else { return "—" }
        return combo.split(separator: "+").map { piece -> String in
            switch piece {
            case "Mod": return "⌘"
            case "Ctrl": return "⌃"
            case "Alt": return "⌥"
            case "Shift": return "⇧"
            case "Esc": return "Esc"
            default: return String(piece)
            }
        }.joined(separator: "")
    }

    static func menuKeyEquivalent(_ combo: String) -> (key: String, flags: NSEvent.ModifierFlags) {
        guard !combo.isEmpty else { return ("", []) }
        let parts = combo.split(separator: "+").map(String.init)
        let key = parts.last ?? ""
        var flags: NSEvent.ModifierFlags = []
        for p in parts.dropLast() {
            switch p {
            case "Mod": flags.insert(.command)
            case "Ctrl": flags.insert(.control)
            case "Alt": flags.insert(.option)
            case "Shift": flags.insert(.shift)
            default: break
            }
        }
        return (keyEquivalent(for: key), flags)
    }

    private static func keyEquivalent(for key: String) -> String {
        if key.count == 1 { return key.lowercased() }
        let fkeys: [String: String] = [
            "F1": "\u{F704}", "F2": "\u{F705}", "F3": "\u{F706}", "F4": "\u{F707}",
            "F5": "\u{F708}", "F6": "\u{F709}", "F7": "\u{F70A}", "F8": "\u{F70B}",
            "F9": "\u{F70C}", "F10": "\u{F70D}", "F11": "\u{F70E}", "F12": "\u{F70F}",
        ]
        return fkeys[key] ?? key.lowercased()
    }
}
