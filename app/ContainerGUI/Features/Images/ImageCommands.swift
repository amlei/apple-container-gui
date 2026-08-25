import Foundation

// MARK: - Images

extension Commands {
    static func listImages() async -> [ImageResourceJSON] {
        guard let out = try? await CLIRunner.run(["image", "list", "--format", "json"]),
              let data = out.data(using: .utf8) else { return [] }
        return (try? decoder.decode([ImageResourceJSON].self, from: data)) ?? []
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
}

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
