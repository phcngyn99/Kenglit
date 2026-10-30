import Foundation

/// Remember display names for apps the user adds by file pick / frontmost.
public enum WatchedAppsUserNames {
    private static let key = "watchedAppDisplayNames"
    private static var defaults: UserDefaults { .standard }

    public static func set(_ name: String, for bundleID: String) {
        var map = load()
        map[bundleID] = name
        defaults.set(map, forKey: key)
    }

    public static func displayName(for bundleID: String) -> String {
        if let builtIn = WatchedApps.displayNames[bundleID] {
            return builtIn
        }
        if let custom = load()[bundleID], !custom.isEmpty {
            return custom
        }
        return bundleID
    }

    private static func load() -> [String: String] {
        (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
    }
}
