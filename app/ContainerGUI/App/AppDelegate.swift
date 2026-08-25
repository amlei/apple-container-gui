import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController?
    private var routeMenuItems: [Route: NSMenuItem] = [:]
    private var primaryMenuItem: NSMenuItem?
    private var findMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = nil  // follow system
        applyStoredTheme()
        if let url = Bundle.module.url(forResource: "logo", withExtension: "png"),
           let logo = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = logo
            logo.size = NSSize(width: 512, height: 512)
            NSApp.applicationIconImage = logo
        }
        setupMainMenu()
        let wc = MainWindowController()
        windowController = wc
        wc.window?.center()
        wc.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(self, selector: #selector(applyKeymap), name: .keymapChanged, object: nil)
        Store.shared.start()
    }

    private func applyStoredTheme() {
        let mode = UserDefaults.standard.string(forKey: "theme") ?? "auto"
        switch mode {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    // MARK: Main menu

    private func setupMainMenu() {
        let main = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "Container")
        appMenu.addItem(withTitle: L("menu.about"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: L("menu.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // File menu
        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: L("menu.file"))
        let newAction = fileMenu.addItem(withTitle: L("act.primary"), action: #selector(primaryAction), keyEquivalent: Keymap.menuKeyEquivalent(Keymap.combo("primary.action")).key)
        newAction.target = self
        newAction.keyEquivalentModifierMask = Keymap.menuKeyEquivalent(Keymap.combo("primary.action")).flags
        primaryMenuItem = newAction
        let find = fileMenu.addItem(withTitle: L("act.search"), action: #selector(findAction), keyEquivalent: Keymap.menuKeyEquivalent(Keymap.combo("focus.search")).key)
        find.target = self
        find.keyEquivalentModifierMask = Keymap.menuKeyEquivalent(Keymap.combo("focus.search")).flags
        findMenuItem = find
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu

        // Edit menu (required for copy/paste in text fields)
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: L("menu.edit"))
        editMenu.addItem(withTitle: L("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L("menu.redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        // View menu — route navigation ⌘1…⌘8
        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: L("menu.view"))
        for (i, r) in Route.allCases.enumerated() {
            let combo = Keymap.combo("nav.\(r.rawValue)")
            let it = viewMenu.addItem(withTitle: r.title, action: #selector(goRoute(_:)), keyEquivalent: Keymap.menuKeyEquivalent(combo).key)
            it.target = self
            it.representedObject = r.rawValue
            it.keyEquivalentModifierMask = Keymap.menuKeyEquivalent(combo).flags
            routeMenuItems[r] = it
        }
        viewItem.submenu = viewMenu

        // Window menu
        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(withTitle: L("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: L("menu.zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu

        NSApp.mainMenu = main
    }

    @objc private func applyKeymap() {
        let primary = Keymap.menuKeyEquivalent(Keymap.combo("primary.action"))
        primaryMenuItem?.keyEquivalent = primary.key
        primaryMenuItem?.keyEquivalentModifierMask = primary.flags
        let find = Keymap.menuKeyEquivalent(Keymap.combo("focus.search"))
        findMenuItem?.keyEquivalent = find.key
        findMenuItem?.keyEquivalentModifierMask = find.flags
        for (route, item) in routeMenuItems {
            let e = Keymap.menuKeyEquivalent(Keymap.combo("nav.\(route.rawValue)"))
            item.keyEquivalent = e.key
            item.keyEquivalentModifierMask = e.flags
            item.title = route.title
        }
    }

    @MainActor @objc private func goRoute(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let r = Route(rawValue: raw) else { return }
        Store.shared.setRoute(r)
    }

    @MainActor @objc private func primaryAction() {
        NotificationCenter.default.post(name: .runPrimaryAction, object: nil)
    }

    @MainActor @objc private func findAction() {
        NotificationCenter.default.post(name: .focusSearchAction, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { windowController?.showWindow(nil) }
        return true
    }
}
