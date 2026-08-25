import Foundation

// MARK: - Machines

extension Commands {
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
