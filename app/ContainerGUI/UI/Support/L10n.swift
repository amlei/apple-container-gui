import Foundation

func L(_ key: String, _ args: [String: String] = [:]) -> String {
    var s = Bundle.module.localizedString(forKey: key, value: key, table: nil)
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
