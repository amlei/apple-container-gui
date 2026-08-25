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
        stream(args, onLine: onLine, onExit: { _ in })
    }

    /// Stream output line-by-line, calling `onExit(success)` once the process ends.
    static func stream(_ args: [String], onLine: @escaping (String) -> Void,
                       onExit: @escaping (Bool) -> Void) -> ProcessHandle {
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
                var lineBuffer = Data()
                pipe.fileHandleForReading.readabilityHandler = { fh in
                    let data = fh.availableData
                    guard !data.isEmpty else { fh.readabilityHandler = nil; return }
                    lineBuffer.append(data)
                    while let nl = lineBuffer.firstIndex(of: 0x0A) {
                        let buf = lineBuffer
                        let lineData = buf[buf.startIndex..<nl]
                        lineBuffer = Data(buf[buf.index(after: nl)...])
                        let line = lineData.dropLast(lineData.last == 0x0D ? 1 : 0)
                        let s = String(decoding: line, as: UTF8.self)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !s.isEmpty { onLine(s) }
                    }
                }
            }
            p.waitUntilExit()
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            handle.finished = true
            let ok = p.terminationStatus == 0
            DispatchQueue.main.async { onExit(ok) }
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
