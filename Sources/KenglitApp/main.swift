import AppKit
import KenglitCore

private let showUINotification = Notification.Name("dev.finn.kenglit.showUI")

/// Owns long-lived objects so menu bar status item never deallocates.
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

        // Another process asked us to show UI (user clicked Kenglit.app again).
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

/// Finder / Applications click opens Settings so user can reach app
/// even when menu-bar icon is hidden/crowded.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always show Settings on manual launch from Applications/Finder.
        // Login-item launches include --as-login-item arg (set via LaunchAtLogin wrapper if any).
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
        // Single instance: if already running, ask it to show UI and exit.
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
            // Give peer a moment to receive.
            usleep(150_000)
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        AppDelegateBox.shared.delegate = delegate

        app.setActivationPolicy(.accessory)

        // Permanent retain — DO NOT drop this reference.
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
