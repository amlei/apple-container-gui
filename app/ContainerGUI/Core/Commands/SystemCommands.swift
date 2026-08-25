import Foundation

// MARK: - System / registry / daemon commands

extension Commands {
    static func systemStatus() async -> SystemStatusJSON? {
        guard let out = try? await CLIRunner.run(["system", "status", "--format", "json"]) else { return nil }
        if let data = out.data(using: .utf8), let s = try? decoder.decode(SystemStatusJSON.self, from: data) { return s }
        return SystemStatusJSON(status: out.lowercased().contains("running") ? "running" : "stopped",
                                appRoot: nil, installRoot: nil, logRoot: nil)
    }

    static func version() async -> [VersionEntryJSON] {
        guard let out = try? await CLIRunner.run(["system", "version", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([VersionEntryJSON].self, from: data)) ?? []
    }

    static func df() async -> DfReportJSON? {
        guard let out = try? await CLIRunner.run(["system", "df", "--format", "json"]),
              let data = out.data(using: .utf8) else { return nil }
        return try? decoder.decode(DfReportJSON.self, from: data)
    }

    static func properties() async -> [(key: String, value: String)] {
        guard let out = try? await CLIRunner.run(["system", "property", "list"]) else { return [] }
        var result: [(String, String)] = []
        var section = ""
        for line in out.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[") && t.hasSuffix("]") { section = String(t.dropFirst().dropLast()); continue }
            guard let eq = t.firstIndex(of: "=") else { continue }
            let k = String(t[t.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            var v = String(t[t.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if v.hasPrefix("\"") && v.hasSuffix("\"") && v.count >= 2 { v = String(v.dropFirst().dropLast()) }
            result.append((section.isEmpty ? k : "\(section).\(k)", v))
        }
        return result
    }

    static func dnsDomains() async -> [String] {
        guard let out = try? await CLIRunner.run(["system", "dns", "list", "--format", "json"]) else { return [] }
        if let data = out.data(using: .utf8), let arr = try? decoder.decode([String].self, from: data) { return arr }
        return out.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0 != "DOMAIN" }
    }

    static func registries() async -> [String] {
        guard let out = try? await CLIRunner.run(["registry", "list", "--quiet"]) else { return [] }
        return out.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Stream `container system logs` with an optional `--last` window (e.g. "5m", "1h", "1d").
    static func systemLogsStream(last: String?, follow: Bool,
                                 onLine: @escaping (String) -> Void) -> ProcessHandle {
        var args = ["system", "logs"]
        if let l = last, !l.isEmpty { args += ["--last", l] }
        if follow { args.append("-f") }
        return CLIRunner.stream(args, onLine: onLine)
    }

    static func registryLogin(server: String, user: String?, password: String) async throws {
        var args = ["registry", "login", "--password-stdin"]
        if let user, !user.isEmpty { args += ["--username", user] }
        args.append(server)
        try await CLIRunner.runWithStdin(args, stdin: password + "\n")
    }
    static func registryLogout(_ server: String) async throws { try await CLIRunner.run(["registry", "logout", server]) }

    static func systemStart() async throws { try await CLIRunner.run(["system", "start", "--enable-kernel-install", "--timeout", "60"]) }
    static func systemStop() async throws { try await CLIRunner.run(["system", "stop"]) }
    static func kernelSetRecommended() async throws { try await CLIRunner.run(["system", "kernel", "set", "--recommended", "--force"]) }
    static func kernelSetBinary(_ path: String) async throws { try await CLIRunner.run(["system", "kernel", "set", "--binary", path, "--force"]) }
    static func dnsCreate(_ domain: String) async throws { try await CLIRunner.run(["system", "dns", "create", domain]) }
    static func dnsDelete(_ domain: String) async throws { try await CLIRunner.run(["system", "dns", "delete", domain]) }
}
