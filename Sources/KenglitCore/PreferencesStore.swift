import Foundation
import Combine

public final class PreferencesStore: ObservableObject {
    private enum Key {
        static let enabled = "isEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let watchedLegacy = "watchedBundleIDs"
        static let userExtras = "userWatchedBundleIDs"
        static let excludedBuiltIn = "excludedBuiltInBundleIDs"
    }

    private let defaults: UserDefaults

    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published public private(set) var userWatchedBundleIDs: [String] {
        didSet { defaults.set(userWatchedBundleIDs, forKey: Key.userExtras) }
    }

    @Published public private(set) var excludedBuiltInBundleIDs: [String] {
        didSet { defaults.set(excludedBuiltInBundleIDs, forKey: Key.excludedBuiltIn) }
    }

    public var activeBuiltInBundleIDs: [String] {
        let excluded = Set(excludedBuiltInBundleIDs)
        return WatchedApps.defaults.filter { !excluded.contains($0) }
    }

    public var watchedBundleIDs: [String] {
        WatchedApps.normalized(activeBuiltInBundleIDs + userWatchedBundleIDs)
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
            let builtin = Set(WatchedApps.defaults)
            let onlyUser = Self.sanitizeExtras(legacy.filter { !builtin.contains($0) })
            self.userWatchedBundleIDs = onlyUser
        } else {
            self.userWatchedBundleIDs = []
        }

        if let excluded = defaults.array(forKey: Key.excludedBuiltIn) as? [String] {
            self.excludedBuiltInBundleIDs = Self.sanitizeExclusions(excluded)
        } else {
            self.excludedBuiltInBundleIDs = []
        }

        defaults.set(userWatchedBundleIDs, forKey: Key.userExtras)
        defaults.set(excludedBuiltInBundleIDs, forKey: Key.excludedBuiltIn)
    }

    public func setUserWatchedBundleIDs(_ ids: [String]) {
        userWatchedBundleIDs = Self.sanitizeExtras(ids)
        objectWillChange.send()
    }

    public func setExcludedBuiltInBundleIDs(_ ids: [String]) {
        excludedBuiltInBundleIDs = Self.sanitizeExclusions(ids)
        objectWillChange.send()
    }

    public func addWatchedBundleID(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if WatchedApps.defaults.contains(trimmed) {
            if excludedBuiltInBundleIDs.contains(trimmed) {
                setExcludedBuiltInBundleIDs(excludedBuiltInBundleIDs.filter { $0 != trimmed })
            }
            return
        }
        setUserWatchedBundleIDs(userWatchedBundleIDs + [trimmed])
    }

    public func removeWatchedBundleID(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if WatchedApps.defaults.contains(trimmed) {
            setExcludedBuiltInBundleIDs(excludedBuiltInBundleIDs + [trimmed])
            if userWatchedBundleIDs.contains(trimmed) {
                setUserWatchedBundleIDs(userWatchedBundleIDs.filter { $0 != trimmed })
            }
            return
        }
        setUserWatchedBundleIDs(userWatchedBundleIDs.filter { $0 != trimmed })
    }

    public func restoreDefaultApplications() {
        setUserWatchedBundleIDs([])
        setExcludedBuiltInBundleIDs([])
    }

    public func resetUserExtras() {
        restoreDefaultApplications()
    }

    public func mergeMissingDefaults() {}

    private static func sanitizeExtras(_ ids: [String]) -> [String] {
        let builtin = Set(WatchedApps.defaults)
        return WatchedApps.normalized(ids).filter { !builtin.contains($0) }
    }

    private static func sanitizeExclusions(_ ids: [String]) -> [String] {
        let builtin = Set(WatchedApps.defaults)
        return WatchedApps.normalized(ids).filter { builtin.contains($0) }
    }
}
