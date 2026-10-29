import AppKit
import Combine
import KenglitCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

    init(model: AppModel) {
        self.model = model
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.menuBarImage(enabled: model.preferences.isEnabled)
            button.toolTip = "kenglit"
        }
        rebuildMenu()
        model.preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        model.monitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        updateIcon()
    }

    private func updateIcon() {
        statusItem.button?.image = Self.menuBarImage(enabled: model.preferences.isEnabled)
    }

    private static func menuBarImage(enabled: Bool) -> NSImage {
        if let img = NSImage(named: "kenglitTemplate") {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            // Dim when disabled via template + lower alpha layer is awkward; use system symbol fallback look
            if !enabled {
                img.accessibilityDescription = "kenglit (off)"
            }
            return img
        }
        let name = enabled ? "keyboard" : "keyboard.chevron.compact.down"
        return NSImage(systemSymbolName: name, accessibilityDescription: "kenglit") ?? NSImage()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let enabledItem = NSMenuItem(
            title: model.preferences.isEnabled ? "Enabled ✓" : "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        menu.addItem(enabledItem)

        if let warning = model.monitor.lastWarning {
            let w = NSMenuItem(title: warning, action: nil, keyEquivalent: "")
            w.isEnabled = false
            menu.addItem(w)
        }

        menu.addItem(.separator())

        let test = NSMenuItem(title: "Test switch to EN", action: #selector(testEnglish), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateIcon()
    }

    @objc private func toggleEnabled() {
        model.preferences.isEnabled.toggle()
        if model.preferences.isEnabled {
            model.monitor.start()
        } else {
            model.monitor.stop()
        }
        rebuildMenu()
    }

    @objc private func testEnglish() {
        if !model.switcher.selectEnglish() {
            model.monitor.lastWarning = "No English keyboard found"
        } else {
            model.monitor.lastWarning = nil
        }
        rebuildMenu()
    }

    @objc private func openSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = SettingsWindowController(preferences: model.preferences)
        settingsWindow = controller.window
        controller.window?.delegate = self
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension StatusItemController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}
