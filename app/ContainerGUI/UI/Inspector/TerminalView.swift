import AppKit
import Darwin

/// Embedded terminal that runs a `container` subcommand behind a real PTY.
final class TerminalView: NSView, NSTextViewDelegate {
    private let output: NSTextView
    private let input: NSTextField
    private let scroll: NSScrollView
    private let command: [String]
    private var masterFD: Int32 = -1
    private var childPID: pid_t = 0
    private var pendingLine = ""
    private let outQueue = DispatchQueue(label: "terminal.out")

    init(command: [String]) {
        self.command = command
        output = NSTextView()
        output.isEditable = false
        output.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        output.autoresizingMask = [.width]
        output.isVerticallyResizable = true
        output.drawsBackground = false

        input = NSTextField()
        input.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        input.placeholderString = L("term.ph")

        scroll = NSScrollView()

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cardStyle()

        scroll.documentView = output
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let prompt = makeMonoLabel("sh ❯", size: 12, color: .controlAccentColor)
        input.target = self
        input.action = #selector(runCommand)
        input.translatesAutoresizingMaskIntoConstraints = false

        let inputRow = stackH([prompt, input], spacing: 8)
        inputRow.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scroll)
        addSubview(inputRow)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            inputRow.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            inputRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            inputRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            inputRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            output.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        appendSystemLine("$ container " + command.joined(separator: " "))
        appendSystemLine(L("term.help"))
        spawn()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { cardStyle() }

    deinit {
        if masterFD >= 0 { close(masterFD) }
        if childPID > 0 { kill(childPID, SIGHUP) }
    }

    func focusInput() { window?.makeFirstResponder(input) }

    // MARK: PTY

    private func spawn() {
        var master: Int32 = 0
        var slave: Int32 = 0
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            appendSystemLine("pty error"); return
        }
        masterFD = master

        let p = Process()
        p.executableURL = URL(fileURLWithPath: CLIRunner.binaryPath())
        p.arguments = command
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        p.environment = env
        // Put the child in its own session and wire stdio to the slave.
        let stdinFH = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        p.standardInput = stdinFH
        p.standardOutput = stdinFH
        p.standardError = stdinFH
        do { try p.run() } catch {
            appendSystemLine(error.localizedDescription)
            close(slave); return
        }
        childPID = p.processIdentifier
        close(slave)  // parent only keeps master

        let fh = FileHandle(fileDescriptor: master, closeOnDealloc: false)
        fh.readabilityHandler = { [weak self] (handle: FileHandle) in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(data: data, encoding: .utf8) ?? ""
            self?.outQueue.async { [weak self] in self?.ingest(text) }
        }
    }

    /// Accumulate chunks and emit whole lines (PTY output arrives in pieces).
    private func ingest(_ chunk: String) {
        pendingLine += chunk
        while let nl = pendingLine.firstIndex(of: "\n") {
            let line = String(pendingLine[pendingLine.startIndex..<nl])
            pendingLine = String(pendingLine[pendingLine.index(after: nl)...])
            DispatchQueue.main.async { [weak self] in self?.appendLine(line) }
        }
    }

    private func appendLine(_ line: String) {
        appendAttr(line + "\n", color: .labelColor)
    }

    private func appendSystemLine(_ line: String) {
        appendAttr(line + "\n", color: .tertiaryLabelColor)
    }

    private func appendErrorLine(_ line: String) {
        appendAttr(line + "\n", color: .systemRed)
    }

    private func appendAttr(_ text: String, color: NSColor) {
        output.textStorage?.append(NSAttributedString(
            string: text,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular), .foregroundColor: color]))
        output.scrollRangeToVisible(NSRange(location: output.string.count - 1, length: 1))
    }

    @objc private func runCommand() {
        let raw = input.stringValue
        input.stringValue = ""
        appendAttr("sh ❯ \(raw)\n", color: .controlAccentColor)
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard masterFD >= 0 else { appendErrorLine("session closed"); return }
        let data = Data((trimmed + "\n").utf8)
        write(masterFD, (data as NSData).bytes, data.count)
    }
}
