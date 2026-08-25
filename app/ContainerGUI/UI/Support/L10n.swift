import Foundation

/// In-app language override. `auto` follows the system; otherwise a specific
/// localization (e.g. "en", "zh-Hans") is forced regardless of OS settings.
enum AppLanguage {
    static let storageKey = "appLanguage"
    static let available = ["auto", "zh-Hans", "en"]

    static var current: String {
        let v = UserDefaults.standard.string(forKey: storageKey) ?? "auto"
        return v.isEmpty ? "auto" : v
    }

    static func set(_ code: String) {
        UserDefaults.standard.set(code, forKey: storageKey)
    }

    static var displayName: String {
        switch current {
        case "zh-Hans": return "简体中文"
        case "en": return "English"
        default: return L("set.language.system")
        }
    }
}

enum LocaleTable {
    private static var cache: [String: [String: String]] = [:]

    static func load(_ lang: String) -> [String: String]? {
        if let t = cache[lang] { return t }
        let loc = lang == "en" ? "en" : "zh-hans"
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "strings",
                                          subdirectory: nil, localization: loc),
              let d = NSDictionary(contentsOf: url) as? [String: String] else { return nil }
        cache[lang] = d
        return d
    }
}

func L(_ key: String, _ args: [String: String] = [:]) -> String {
    let lang = AppLanguage.current
    var s: String
    if lang == "auto" {
        s = Bundle.module.localizedString(forKey: key, value: key, table: nil)
        if s == key { s = LocaleTable.load("en")?[key] ?? key }
    } else if let table = LocaleTable.load(lang) {
        s = table[key] ?? Bundle.module.localizedString(forKey: key, value: key, table: nil)
    } else {
        s = Bundle.module.localizedString(forKey: key, value: key, table: nil)
    }
    for (k, v) in args { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
    return s
}

enum Fmt {
    static let GB: UInt64 = 1_073_741_824

    static func bytes(_ b: UInt64?) -> String {
        guard let b else { return "—" }
        let u: [String] = ["B", "KB", "MB", "GB", "TB"]
        var n = Double(b), i = 0
        while n >= 1024 && i < u.count - 1 { n /= 1024; i += 1 }
        return n >= 100 || i == 0 ? "\(Int(n.rounded())) \(u[i])" : String(format: "%.1f %@", n, u[i])
    }

    static func relTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        let m = Int(Date().timeIntervalSince(date) / 60)
        if m < 1 { return L("time.now") }
        if m < 60 { return L("time.min", ["n": "\(m)"]) }
        let h = m / 60
        if h < 24 { return L("time.hour", ["n": "\(h)"]) }
        return L("time.day", ["n": "\(h / 24)"])
    }

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    static func duration(seconds: TimeInterval) -> String {
        let s = max(1, Int(seconds))
        if s < 60 { return L("dur.s", ["n": "\(s)"]) }
        let m = s / 60
        if m < 60 { return L("dur.m", ["n": "\(m)", "s": "\(s % 60)"]) }
        let h = m / 60
        if h < 24 { return L("dur.h", ["n": "\(h)", "m": "\(m % 60)"]) }
        return L("dur.d", ["n": "\(h / 24)", "h": "\(h % 24)"])
    }
}
