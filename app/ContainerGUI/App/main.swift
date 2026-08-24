import AppKit

NSSetUncaughtExceptionHandler { ex in
    NSLog("CGUI EXCEPTION: %@ — %@\n%@", ex.name.rawValue, ex.reason ?? "", ex.callStackSymbols.prefix(15).joined(separator: "\n"))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
