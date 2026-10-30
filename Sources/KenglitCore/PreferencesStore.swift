import Foundation
import Combine

public final class PreferencesStore: ObservableObject {
    private enum Key {
        static let enabled = "isEnabled"
        static let launchAtLogin = "launchAtLogin"
        /// Legacy full list (pre-split). Migrated once into user extras.
        static let watchedLegacy = "watchedBundleIDs"
        /// User-added only (shown in Settings). Defaults always apply separately.
        static let userExtras = "userWatchedBundleIDs"
    }

    private let defaults: UserDefaults

    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    /// User-added EN apps only (Settings list).
    @Published public private(set) var userWatchedBundleIDs: [String] {
        didSet { defaults.set(userWatchedBundleIDs, forKey: Key.userExtras) }
    }

    /// Effective EN set: built-in defaults ∪ user extras. Used by focus monitor.
    public var watchedBundleIDs: [String] {
        WatchedApps.normalized(WatchedApps.defaults + userWatchedBundleIDs)
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.enabled) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: Key.enabled)
        }
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)

        if let extras = defaults.array(forKey: Key.userExtras) as? [String] {
            self.userWatchedBundleIDs = Self.sanitizeExtras(extras)
        } else if let legacy = defaults.array(forKey: Key.watchedLegacy) as? [String] {
            // One-shot migration: only keep ids that are NOT built-in defaults.
            let builtin = Set(WatchedApps.defaults)
            let onlyUser = legacy.filter { !builtin.contains($0) }
            self.userWatchedBundleIDs = Self.sanitizeExtras(onlyUser)
            defaults.set(self.userWatchedBundleIDs, forKey: Key.userExtras)
        } else {
            self.userWatchedBundleIDs = []
        }
    }

    public func setUserWatchedBundleIDs(_ ids: [String]) {
        userWatchedBundleIDs = Self.sanitizeExtras(ids)
        objectWillChange.send()
    }

    public func addWatchedBundleID(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Defaults already covered — no need to store again.
        if WatchedApps.defaults.contains(trimmed) { return }
        setUserWatchedBundleIDs(userWatchedBundleIDs + [trimmed])
    }

    public func removeWatchedBundleID(_ id: String) {
        setUserWatchedBundleIDs(userWatchedBundleIDs.filter { $0 != id })
    }

    /// Clear user extras only. Built-in defaults stay active.
    public func resetUserExtras() {
        setUserWatchedBundleIDs([])
    }

    /// No-op kept for callers; defaults always apply, nothing to merge into storage.
    public func mergeMissingDefaults() {}

    private static func sanitizeExtras(_ ids: [String]) -> [String] {
        let builtin = Set(WatchedApps.defaults)
        return WatchedApps.normalized(ids).filter { !builtin.contains($0) }
    }
}
