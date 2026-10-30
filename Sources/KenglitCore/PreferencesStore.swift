import Foundation
import Combine

public final class PreferencesStore: ObservableObject {
    private enum Key {
        static let enabled = "isEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let watched = "watchedBundleIDs"
    }

    private let defaults: UserDefaults

    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published public private(set) var watchedBundleIDs: [String] {
        didSet { defaults.set(watchedBundleIDs, forKey: Key.watched) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.enabled) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: Key.enabled)
        }
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        if let saved = defaults.array(forKey: Key.watched) as? [String] {
            self.watchedBundleIDs = WatchedApps.normalized(saved)
        } else {
            self.watchedBundleIDs = WatchedApps.defaults
        }
    }

    public func setWatchedBundleIDs(_ ids: [String]) {
        watchedBundleIDs = WatchedApps.normalized(ids)
    }

    public func addWatchedBundleID(_ id: String) {
        setWatchedBundleIDs(watchedBundleIDs + [id])
    }

    public func removeWatchedBundleID(_ id: String) {
        setWatchedBundleIDs(watchedBundleIDs.filter { $0 != id })
    }

    /// Add any newly shipped default bundle IDs the user doesn't already have.
    public func mergeMissingDefaults() {
        let current = Set(watchedBundleIDs)
        let missing = WatchedApps.defaults.filter { !current.contains($0) }
        guard !missing.isEmpty else { return }
        setWatchedBundleIDs(watchedBundleIDs + missing)
    }
}
