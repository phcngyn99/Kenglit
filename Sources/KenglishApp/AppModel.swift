import Foundation
import Combine
import KenglishCore

@MainActor
final class AppModel: ObservableObject {
    let preferences: PreferencesStore
    let switcher: CarbonInputSourceSwitcher
    let monitor: AppFocusMonitor

    init() {
        let preferences = PreferencesStore()
        let switcher = CarbonInputSourceSwitcher()
        self.preferences = preferences
        self.switcher = switcher
        self.monitor = AppFocusMonitor(preferences: preferences, switcher: switcher)
        // Reflect SMAppService state into prefs without writing back through didSet loop issues:
        // LaunchAtLogin reads system; assign only if different.
        let systemLogin = LaunchAtLogin.isEnabled
        if preferences.launchAtLogin != systemLogin {
            preferences.launchAtLogin = systemLogin
        }
        if preferences.isEnabled {
            monitor.start()
        }
    }
}
