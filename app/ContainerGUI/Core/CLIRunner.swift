import Foundation

struct CLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Runs the `container` CLI in child processes.
enum CLIRunner {
    static func binaryPath() -> String {
        let candidates = ["/usr/local/bin/container", "/opt/homebrew/bin/container", "/usr/bin/container"]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? "/usr/local/bin/container"
    }

    static var available: Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath())
    }

    /// Run a command and capture output. Throws on non-zero exit.
    @discardableResult
    static func run(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: binaryPath())
                p.arguments = args
                let out = Pipe(), err = Pipe()
                p.standardOutput = out
                p.standardError = err
                do { try p.run() } catch { cont.resume(throwing: CLIError(message: error.localizedDescription)); return }
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let code = p.terminationStatus
                if code != 0 {
                    let msg = String(data: errData, encoding: .utf8).flatMap(parseCLIError) ?? "exit \(code)"
                    cont.resume(throwing: CLIError(message: msg))
                } else {
                    cont.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                }
            }
        }
    }

    /// Best-effort run that ignores failures.
    @discardableResult
    static func tryRun(_ args: [String]) async -> String? {
        try? await run(args)
    }

    /// Run with a line handler for streaming output (logs, pull progress).
    static func stream(_ args: [String], onLine: @escaping (String) -> Void) -> ProcessHandle {
        let handle = ProcessHandle()
        DispatchQueue.global().async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: binaryPath())
            p.arguments = args
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            do { try p.run() } catch { onLine(error.localizedDescription); return }
            handle.process = p
            for pipe in [out, err] {
                pipe.fileHandleForReading.readabilityHandler = { fh in
                    let data = fh.availableData
                    guard !data.isEmpty else { fh.readabilityHandler = nil; return }
                    let text = String(data: data, encoding: .utf8) ?? ""
                    for chunk in text.split(separator: "\n", omittingEmptySubsequences: true) {
                        onLine(String(chunk))
                    }
                }
            }
            p.waitUntilExit()
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            handle.finished = true
        }
        return handle
    }

    private static func parseCLIError(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // "Error: failed to ..." → keep last meaningful line
        let lines = trimmed.components(separatedBy: "\n").filter { !$0.isEmpty }
        return lines.last.map { $0.replacingOccurrences(of: "Error: ", with: "") }
    }
}

final class ProcessHandle {
    fileprivate(set) var process: Process?
    fileprivate(set) var finished = false
    func terminate() { process?.terminate() }
}
