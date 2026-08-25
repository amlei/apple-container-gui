import Foundation

// MARK: - Volumes

extension Commands {
    static func listVolumes() async -> [VolumeResourceJSON] {
        guard let out = try? await CLIRunner.run(["volume", "list", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([VolumeResourceJSON].self, from: data)) ?? []
    }

    static func createVolume(name: String, size: String?, journal: String?) async throws {
        var args = ["volume", "create"]
        if let size, !size.isEmpty { args += ["-s", size] }
        if let journal, !journal.isEmpty { args += ["--opt", "journal=\(journal)"] }
        args.append(name)
        try await CLIRunner.run(args)
    }

    static func deleteVolumes(_ names: [String]) async throws { try await CLIRunner.run(["volume", "delete"] + names) }
    static func pruneVolumes() async throws { try await CLIRunner.run(["volume", "prune"]) }
}
