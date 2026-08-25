import Foundation

// MARK: - Containers

extension Commands {
    static func listContainers(all: Bool) async -> [ManagedContainer] {
        var args = ["list", "--format", "json"]
        if all { args.append("--all") }
        guard let out = try? await CLIRunner.run(args), let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([ManagedContainer].self, from: data)) ?? []
    }

    static func stats(id: String) async -> ContainerStatsSnapshot? {
        guard let out = try? await CLIRunner.run(["stats", "--no-stream", "--format", "json", id]),
              let data = out.data(using: .utf8) else { return nil }
        if let one = try? decoder.decode(ContainerStatsSnapshot.self, from: data) { return one }
        if let arr = try? decoder.decode([ContainerStatsSnapshot].self, from: data) { return arr.first }
        return nil
    }

    /// Stream a container's logs. `tail` > 0 limits to the last N lines, `boot` reads the
    /// boot log, and `follow` keeps the pipe open so the handler receives new lines.
    static func containerLogsStream(id: String, tail: Int?, boot: Bool, follow: Bool,
                                    onLine: @escaping (String) -> Void) -> ProcessHandle {
        var args = ["logs"]
        if boot { args.append("--boot") }
        if let t = tail, t > 0 { args += ["-n", "\(t)"] }
        if follow { args.append("-f") }
        args.append(id)
        return CLIRunner.stream(args, onLine: onLine)
    }

    static func containerAction(_ op: String, ids: [String], extra: [String] = []) async throws {
        try await CLIRunner.run([op] + extra + ids)
    }

    static func runContainer(_ spec: RunSpec) async throws {
        try await CLIRunner.run(spec.argv)
    }

    static func exportContainer(_ id: String, to path: String) async throws { try await CLIRunner.run(["export", "-o", path, id]) }
    static func pruneContainers() async throws { try await CLIRunner.run(["prune"]) }
}

struct RunSpec {
    var image: String
    var name: String?
    var cmd: String?
    var cpus: Int?
    var memory: String?
    var network: String?
    var ports: [(String, String)] = []
    var volumes: [(String, String)] = []
    var env: [(String, String)] = []
    var initProc = false
    var rosetta = false
    var readOnly = false
    var autoRemove = false
    var tty = false
    var workdir: String?

    var argv: [String] {
        var a = ["run", "-d"]
        if let name, !name.isEmpty { a += ["--name", name] }
        if let c = cpus { a += ["--cpus", "\(c)"] }
        if let m = memory, !m.isEmpty { a += ["--memory", m] }
        if let n = network, !n.isEmpty, n != "default" { a += ["--network", n] }
        if let w = workdir, !w.isEmpty { a += ["-w", w] }
        for (h, c) in ports { a += ["-p", "\(h):\(c)"] }
        for (s, d) in volumes { a += ["-v", "\(s):\(d)"] }
        for (k, v) in env { a += ["-e", "\(k)=\(v)"] }
        if initProc { a.append("--init") }
        if rosetta { a.append("--rosetta") }
        if readOnly { a.append("--read-only") }
        if autoRemove { a.append("--rm") }
        if tty { a += ["-i", "-t"] }
        a.append(image)
        if let cmd, !cmd.isEmpty { a += cmd.split(separator: " ").map(String.init) }
        return a
    }
}
