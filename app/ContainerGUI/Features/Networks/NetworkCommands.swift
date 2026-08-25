import Foundation

// MARK: - Networks

extension Commands {
    static func listNetworks() async -> [NetworkResourceJSON] {
        guard let out = try? await CLIRunner.run(["network", "list", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([NetworkResourceJSON].self, from: data)) ?? []
    }

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
}
