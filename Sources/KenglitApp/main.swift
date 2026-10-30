import AppKit
import KenglitCore

private let showUINotification = Notification.Name("dev.finn.kenglit.showUI")

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    let model: AppModel
    let status: StatusItemController
    private var prefsObserver: NSObjectProtocol?
    private var showUIObserver: NSObjectProtocol?

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

        showUIObserver = DistributedNotificationCenter.default().addObserver(
            forName: showUINotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showUI()
            }
        }
    }

    func showUI() {
        status.openSettings()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = ProcessInfo.processInfo.arguments
        let loginLaunch = args.contains("--as-login-item")
        if !loginLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                AppRuntime.shared.showUI()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppRuntime.shared.showUI()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
enum KenglitMain {
    static func main() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.finn.kenglit")
            .filter { $0.processIdentifier != myPID }
        if !others.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(
                showUINotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            usleep(150_000)
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        AppDelegateBox.shared.delegate = delegate

        app.setActivationPolicy(.accessory)

        _ = AppRuntime.shared

        app.run()
    }
}

private enum AppDelegateBox {
    static let shared = Holder()
    final class Holder {
        var delegate: AppDelegate?
    }
}
