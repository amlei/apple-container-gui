import Foundation

/// K8s cluster row parsed from `container k8s ls` table output.
struct K8sCluster {
    var name: String
    var state: String      // running / stopped / exited
    var nodeImage: String
    var nodes: Int
    var isRunning: Bool { state.lowercased().contains("running") }
}

enum Commands {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let dt = frac.date(from: s) ?? plain.date(from: s) { return dt }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "bad date \(s)"))
        }
        return d
    }()

    // MARK: Reads

    static func listContainers(all: Bool) async -> [ManagedContainer] {
        var args = ["list", "--format", "json"]
        if all { args.append("--all") }
        guard let out = try? await CLIRunner.run(args), let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([ManagedContainer].self, from: data)) ?? []
    }

    static func listImages() async -> [ImageResourceJSON] {
        guard let out = try? await CLIRunner.run(["image", "list", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([ImageResourceJSON].self, from: data)) ?? []
    }

    static func listVolumes() async -> [VolumeResourceJSON] {
        guard let out = try? await CLIRunner.run(["volume", "list", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([VolumeResourceJSON].self, from: data)) ?? []
    }

    static func listNetworks() async -> [NetworkResourceJSON] {
        guard let out = try? await CLIRunner.run(["network", "list", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([NetworkResourceJSON].self, from: data)) ?? []
    }

    static func listMachines() async -> [MachineResourceJSON] {
        guard let out = try? await CLIRunner.run(["machine", "list", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([MachineResourceJSON].self, from: data)) ?? []
    }

    static func inspectMachine(_ name: String) async -> MachineResourceJSON? {
        guard let out = try? await CLIRunner.run(["machine", "inspect", name]),
              let data = out.data(using: .utf8) else { return nil }
        if let one = try? decoder.decode(MachineResourceJSON.self, from: data) { return one }
        if let arr = try? decoder.decode([MachineResourceJSON].self, from: data) { return arr.first }
        return nil
    }

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

    /// Stream `container system logs` with an optional `--last` window (e.g. "5m",
    /// "1h", "1d").
    static func systemLogsStream(last: String?, follow: Bool,
                                 onLine: @escaping (String) -> Void) -> ProcessHandle {
        var args = ["system", "logs"]
        if let l = last, !l.isEmpty { args += ["--last", l] }
        if follow { args.append("-f") }
        return CLIRunner.stream(args, onLine: onLine)
    }

    static func k8sClusters() async -> [K8sCluster] {
        guard let out = try? await CLIRunner.run(["k8s", "ls"]) else { return [] }
        return parseK8sTable(out)
    }

    static func parseK8sTable(_ text: String) -> [K8sCluster] {
        var clusters: [K8sCluster] = []
        var headerCols: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let cols = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if headerCols.isEmpty {
                headerCols = cols.map { $0.uppercased() }
                continue
            }
            guard cols.count >= 2 else { continue }
            let lower = cols.map { $0.lowercased() }
            // Identify status column value
            let state = lower.first(where: { ["running", "stopped", "exited", "created"].contains($0) }) ?? "unknown"
            // Node image: token containing ":" and "/" or "kindest"
            let image = cols.first(where: { $0.contains("/") && $0.contains(":") }) ?? "—"
            let nameIdx = headerCols.firstIndex(where: { $0.contains("CLUSTER") || $0 == "NAME" }) ?? 0
            guard nameIdx < cols.count else { continue }
            let clusterName = cols[nameIdx]
            guard let existing = clusters.firstIndex(where: { $0.name == clusterName }) else {
                clusters.append(K8sCluster(name: clusterName, state: state, nodeImage: image, nodes: 1))
                continue
            }
            clusters[existing].nodes += 1
            if clusters[existing].state == "unknown" { clusters[existing].state = state }
        }
        return clusters
    }

    // MARK: Actions

    static func containerAction(_ op: String, ids: [String], extra: [String] = []) async throws {
        try await CLIRunner.run([op] + extra + ids)
    }

    static func runContainer(_ spec: RunSpec) async throws {
        try await CLIRunner.run(spec.argv)
    }

    static func pullImage(_ ref: String, platform: String?) async throws {
        var args = ["image", "pull", "--progress", "plain"]
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(ref)
        try await CLIRunner.run(args)
    }

    static func pullImageStream(_ ref: String, platform: String?,
                                onLine: @escaping (String) -> Void,
                                onExit: @escaping (Bool) -> Void) -> ProcessHandle {
        var args = ["image", "pull", "--progress", "plain"]
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(ref)
        return CLIRunner.stream(args, onLine: onLine, onExit: onExit)
    }

    static func buildImage(_ spec: BuildSpec) async throws {
        try await CLIRunner.run(spec.argv)
    }

    static func buildImageStream(_ spec: BuildSpec,
                                 onLine: @escaping (String) -> Void,
                                 onExit: @escaping (Bool) -> Void) -> ProcessHandle {
        CLIRunner.stream(spec.argv, onLine: onLine, onExit: onExit)
    }

    static func pushImage(_ ref: String) async throws { try await CLIRunner.run(["image", "push", ref]) }
    static func tagImage(_ source: String, _ target: String) async throws { try await CLIRunner.run(["image", "tag", source, target]) }
    static func saveImage(_ ref: String, to path: String) async throws { try await CLIRunner.run(["image", "save", "-o", path, ref]) }
    static func loadImage(from path: String) async throws { try await CLIRunner.run(["image", "load", "-i", path]) }
    static func deleteImages(_ refs: [String]) async throws { try await CLIRunner.run(["image", "delete"] + refs) }
    static func pruneImages(all: Bool) async throws { try await CLIRunner.run(["image", "prune"] + (all ? ["--all"] : [])) }
    static func exportContainer(_ id: String, to path: String) async throws { try await CLIRunner.run(["export", "-o", path, id]) }
    static func pruneContainers() async throws { try await CLIRunner.run(["prune"]) }

    static func createVolume(name: String, size: String?, journal: String?) async throws {
        var args = ["volume", "create"]
        if let size, !size.isEmpty { args += ["-s", size] }
        if let journal, !journal.isEmpty { args += ["--opt", "journal=\(journal)"] }
        args.append(name)
        try await CLIRunner.run(args)
    }

    static func deleteVolumes(_ names: [String]) async throws { try await CLIRunner.run(["volume", "delete"] + names) }
    static func pruneVolumes() async throws { try await CLIRunner.run(["volume", "prune"]) }

    static func createNetwork(name: String, subnet4: String?, subnet6: String?, internalOnly: Bool) async throws {
        var args = ["network", "create"]
        if let s4 = subnet4, !s4.isEmpty { args += ["--subnet", s4] }
        if let s6 = subnet6, !s6.isEmpty { args += ["--subnet-v6", s6] }
        if internalOnly { args.append("--internal") }
        args.append(name)
        try await CLIRunner.run(args)
    }

    static func deleteNetworks(_ names: [String]) async throws { try await CLIRunner.run(["network", "delete"] + names) }
    static func pruneNetworks() async throws { try await CLIRunner.run(["network", "prune"]) }

    static func createMachine(_ spec: MachineSpec) async throws { try await CLIRunner.run(spec.argv) }
    static func machineSet(name: String?, settings: [String]) async throws {
        var args = ["machine", "set"]
        if let name { args += ["-n", name] }
        try await CLIRunner.run(args + settings)
    }
    static func machineSetDefault(_ name: String) async throws { try await CLIRunner.run(["machine", "set-default", name]) }
    static func machineStop(_ name: String?) async throws {
        try await CLIRunner.run(["machine", "stop"] + (name.map { [$0] } ?? []))
    }
    static func machineDelete(_ name: String) async throws { try await CLIRunner.run(["machine", "delete", name]) }
    static func machineLogs(_ name: String) async -> String {
        (try? await CLIRunner.run(["machine", "logs", name])) ?? ""
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

    static func k8sCreate(_ spec: K8sSpec) async throws { try await CLIRunner.run(spec.argv) }
    static func k8sStart(_ name: String) async throws { try await CLIRunner.run(["k8s", "start", "--name", name]) }
    static func k8sDelete(_ name: String) async throws { try await CLIRunner.run(["k8s", "delete", "--name", name]) }
    static func k8sLoadImage(_ name: String, image: String) async throws {
        try await CLIRunner.run(["k8s", "load-image", "--name", name, image])
    }
    static func k8sWriteConfig(_ name: String) async throws { try await CLIRunner.run(["k8s", "write-config", "--name", name]) }
}

// MARK: - Specs

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
    }}

struct BuildSpec {
    var dockerfile: String
    var context: String
    var tags: [String]
    var buildArgs: [(String, String)] = []
    var target: String?
    var noCache = false
    var pull = false

    var argv: [String] {
        var a = ["build"]
        if !dockerfile.isEmpty { a += ["-f", dockerfile] }
        for t in tags { a += ["-t", t] }
        for (k, v) in buildArgs { a += ["--build-arg", "\(k)=\(v)"] }
        if let target, !target.isEmpty { a += ["--target", target] }
        if noCache { a.append("--no-cache") }
        if pull { a.append("--pull") }
        a.append(context.isEmpty ? "." : context)
        return a
    }
}

struct MachineSpec {
    var image: String
    var name: String?
    var cpus: Int?
    var memory: String?
    var homeMount: String?
    var virtualization = false
    var setDefault = false
    var kernelPath: String?

    var argv: [String] {
        var a = ["machine", "create"]
        if let name, !name.isEmpty { a += ["--name", name] }
        if let c = cpus { a += ["--cpus", "\(c)"] }
        if let m = memory, !m.isEmpty { a += ["--memory", m] }
        if let h = homeMount, h != "rw" { a += ["--home-mount", h] }
        if virtualization { a.append("--virtualization") }
        if setDefault { a.append("--set-default") }
        if let k = kernelPath, !k.isEmpty { a += ["--kernel", k] }
        a.append(image)
        return a
    }
}

struct K8sSpec {
    var name: String
    var nodeImage: String?
    var cpus: Int?
    var memory: String?
    var autoRemove = false

    var argv: [String] {
        var a = ["k8s", "create", "--name", name]
        if let n = nodeImage, !n.isEmpty { a += ["--node-image", n] }
        if let c = cpus { a += ["--cpus", "\(c)"] }
        if let m = memory, !m.isEmpty { a += ["--memory", m] }
        if autoRemove { a.append("--rm") }
        return a
    }
}

extension CLIRunner {
    static func runWithStdin(_ args: [String], stdin: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: binaryPath())
                p.arguments = args
                let out = Pipe(), err = Pipe(), input = Pipe()
                p.standardOutput = out
                p.standardError = err
                p.standardInput = input
                do { try p.run() } catch { cont.resume(throwing: CLIError(message: error.localizedDescription)); return }
                input.fileHandleForWriting.write(stdin.data(using: .utf8)!)
                input.fileHandleForWriting.closeFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                if p.terminationStatus != 0 {
                    let msg = String(data: errData, encoding: .utf8) ?? "exit \(p.terminationStatus)"
                    cont.resume(throwing: CLIError(message: msg.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
}
