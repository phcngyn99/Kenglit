import Foundation
import Combine
import KenglitCore

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
        preferences.mergeMissingDefaults()
        let systemLogin = LaunchAtLogin.isEnabled
        if preferences.launchAtLogin != systemLogin {
            preferences.launchAtLogin = systemLogin
        }
        if preferences.isEnabled {
            monitor.start()
        }
    }
}
