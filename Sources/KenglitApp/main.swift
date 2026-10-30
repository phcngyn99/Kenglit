import AppKit
import KenglitCore

/// Owns long-lived objects so menu bar status item never deallocates.
@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    let model: AppModel
    let status: StatusItemController
    private var prefsObserver: NSObjectProtocol?

    private init() {
        let model = AppModel()
        self.model = model
        self.status = StatusItemController(model: model)

        prefsObserver = NotificationCenter.default.addObserver(
            forName: .kenglitPrefsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.model.preferences.isEnabled {
                    self.model.monitor.start()
                } else {
                    self.model.monitor.stop()
                }
            }
        }
    }
}

@main
enum KenglitMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // Permanent retain — DO NOT drop this reference.
        _ = AppRuntime.shared

        app.run()
    }
}
