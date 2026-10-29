import AppKit
import KenglishCore

@main
enum KenglishMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // menu-bar only, no Dock

        let model = AppModel()
        let status = StatusItemController(model: model)

        // Keep strong refs
        _ = status

        // Re-sync monitor when settings toggle Enabled without going through menu
        NotificationCenter.default.addObserver(
            forName: .kenglishPrefsChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if model.preferences.isEnabled {
                    model.monitor.start()
                } else {
                    model.monitor.stop()
                }
            }
        }

        app.run()
    }
}
