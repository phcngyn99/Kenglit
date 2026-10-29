import Foundation
import KenglitCore

enum Check {
    private static var failures = 0

    static func expect(_ cond: @autoclosure () -> Bool, _ msg: String, file: StaticString = #fileID, line: UInt = #line) {
        if !cond() {
            failures += 1
            fputs("FAIL \(file):\(line): \(msg)\n", stderr)
        }
    }

    static func equal<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: StaticString = #fileID, line: UInt = #line) {
        expect(a == b, "\(msg) — got \(String(describing: a)), want \(String(describing: b))", file: file, line: line)
    }

    static func finish() {
        if failures == 0 {
            print("All checks passed")
            exit(0)
        } else {
            fputs("\(failures) check(s) failed\n", stderr)
            exit(1)
        }
    }
}

// --- WatchedApps ---
do {
    let set = Set(WatchedApps.defaults)
    Check.expect(set.contains("com.apple.Terminal"), "defaults contain Terminal")
    Check.expect(set.contains("com.microsoft.VSCode"), "defaults contain VSCode")
    Check.expect(set.contains("dev.warp.Warp-Stable"), "defaults contain Warp")
    Check.equal(
        WatchedApps.normalized(["  com.b ", "com.a", "com.a", "", "  "]),
        ["com.a", "com.b"],
        "normalized"
    )
}

// --- PreferencesStore ---
do {
    let suite = "dev.finn.kenglit.tests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        Check.expect(false, "suite defaults")
        Check.finish()
        fatalError()
    }
    defaults.removePersistentDomain(forName: suite)
    let store = PreferencesStore(defaults: defaults)
    Check.expect(store.isEnabled, "default enabled")
    Check.expect(!store.launchAtLogin, "default launchAtLogin false")
    Check.equal(store.watchedBundleIDs, WatchedApps.defaults, "watched seeded")

    store.isEnabled = false
    let reloaded = PreferencesStore(defaults: defaults)
    Check.expect(!reloaded.isEnabled, "persists enabled")

    store.addWatchedBundleID("com.example.App")
    Check.expect(store.watchedBundleIDs.contains("com.example.App"), "add bundle")
    store.removeWatchedBundleID("com.example.App")
    Check.expect(!store.watchedBundleIDs.contains("com.example.App"), "remove bundle")

    store.setWatchedBundleIDs([" com.z ", "com.a", "com.a"])
    Check.equal(store.watchedBundleIDs, ["com.a", "com.z"], "set normalizes")
    defaults.removePersistentDomain(forName: suite)
}

// --- FocusPolicy ---
do {
    let watched: Set<String> = ["com.apple.Terminal", "com.microsoft.VSCode"]
    Check.expect(
        !FocusPolicy.decide(isEnabled: false, frontBundleID: "com.apple.Terminal", watched: watched, currentIsEnglish: false).shouldSwitchToEnglish,
        "disabled never switches"
    )
    Check.expect(
        !FocusPolicy.decide(isEnabled: true, frontBundleID: "com.microsoft.teams2", watched: watched, currentIsEnglish: false).shouldSwitchToEnglish,
        "unwatched never switches"
    )
    Check.expect(
        FocusPolicy.decide(isEnabled: true, frontBundleID: "com.apple.Terminal", watched: watched, currentIsEnglish: false).shouldSwitchToEnglish,
        "watched not EN switches"
    )
    Check.expect(
        !FocusPolicy.decide(isEnabled: true, frontBundleID: "com.apple.Terminal", watched: watched, currentIsEnglish: true).shouldSwitchToEnglish,
        "already EN no-op"
    )
    Check.expect(
        !FocusPolicy.decide(isEnabled: true, frontBundleID: nil, watched: watched, currentIsEnglish: false).shouldSwitchToEnglish,
        "nil front no-op"
    )
}

// --- EnglishSourceResolver ---
do {
    Check.equal(
        EnglishSourceResolver.resolvePreferredID(
            availableIDs: ["com.apple.keylayout.US", "com.apple.keylayout.ABC", "com.apple.inputmethod.Vietnamese"],
            languagesByID: [:]
        ),
        "com.apple.keylayout.ABC",
        "prefer ABC"
    )
    Check.equal(
        EnglishSourceResolver.resolvePreferredID(
            availableIDs: ["com.apple.keylayout.US", "com.apple.inputmethod.Vietnamese"],
            languagesByID: [:]
        ),
        "com.apple.keylayout.US",
        "fallback US"
    )
    Check.equal(
        EnglishSourceResolver.resolvePreferredID(
            availableIDs: ["com.example.CustomEN", "com.apple.inputmethod.Vietnamese"],
            languagesByID: ["com.example.CustomEN": ["en"], "com.apple.inputmethod.Vietnamese": ["vi"]]
        ),
        "com.example.CustomEN",
        "fallback language en"
    )
    Check.equal(
        EnglishSourceResolver.resolvePreferredID(
            availableIDs: ["com.apple.inputmethod.Vietnamese"],
            languagesByID: ["com.apple.inputmethod.Vietnamese": ["vi"]]
        ),
        nil as String?,
        "nil when nothing english"
    )
}

Check.finish()
