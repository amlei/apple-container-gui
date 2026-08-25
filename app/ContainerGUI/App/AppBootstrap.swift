import AppKit

/// Application entry point. Kept as a plain function so the module stays an
/// importable library (testable), while the thin `ContainerApp` executable
/// target only calls this.
public func runContainerGUI() {
    NSSetUncaughtExceptionHandler { ex in
        NSLog("CGUI EXCEPTION: %@ — %@\n%@", ex.name.rawValue, ex.reason ?? "", ex.callStackSymbols.prefix(15).joined(separator: "\n"))
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
