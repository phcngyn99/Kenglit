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
    Check.expect(set.contains("com.todesktop.230313mzl4w4u92"), "defaults contain Cursor")
    Check.expect(set.contains("dev.zed.Zed"), "defaults contain Zed")
    Check.expect(set.contains("net.kovidgoyal.kitty"), "defaults contain kitty")
    Check.expect(set.contains("com.jetbrains.pycharm"), "defaults contain PyCharm")
    Check.expect(set.contains("com.docker.docker"), "defaults contain Docker")
    Check.equal(WatchedApps.displayName(for: "com.apple.Terminal"), "Terminal", "display name Terminal")
    Check.equal(WatchedApps.displayName(for: "com.unknown.app"), "com.unknown.app", "unknown display = id")
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
    Check.equal(store.userWatchedBundleIDs, [], "user extras empty")
    Check.equal(store.excludedBuiltInBundleIDs, [], "exclusions empty")
    Check.equal(store.watchedBundleIDs, WatchedApps.defaults, "effective = defaults")

    store.isEnabled = false
    let reloaded = PreferencesStore(defaults: defaults)
    Check.expect(!reloaded.isEnabled, "persists enabled")

    store.addWatchedBundleID("com.example.App")
    Check.expect(store.userWatchedBundleIDs.contains("com.example.App"), "user list has add")
    Check.expect(store.watchedBundleIDs.contains("com.example.App"), "effective has add")

    store.addWatchedBundleID("com.apple.Terminal")
    Check.expect(!store.userWatchedBundleIDs.contains("com.apple.Terminal"), "default not in user list")
    Check.expect(store.watchedBundleIDs.contains("com.apple.Terminal"), "default still effective")

    store.removeWatchedBundleID("com.example.App")
    Check.expect(!store.userWatchedBundleIDs.contains("com.example.App"), "remove user extra")
    Check.expect(!store.watchedBundleIDs.contains("com.example.App"), "gone from effective")

    // Built-in removal persists as exclusion
    store.removeWatchedBundleID("com.apple.Terminal")
    Check.expect(store.excludedBuiltInBundleIDs.contains("com.apple.Terminal"), "builtin excluded")
    Check.expect(!store.watchedBundleIDs.contains("com.apple.Terminal"), "excluded gone from effective")
    Check.expect(!store.activeBuiltInBundleIDs.contains("com.apple.Terminal"), "not in active builtin")

    let reloaded2 = PreferencesStore(defaults: defaults)
    Check.expect(reloaded2.excludedBuiltInBundleIDs.contains("com.apple.Terminal"), "exclusion persists")
    Check.expect(!reloaded2.watchedBundleIDs.contains("com.apple.Terminal"), "persisted exclusion effective")

    // Re-add restores membership without duplicate
    store.addWatchedBundleID("com.apple.Terminal")
    Check.expect(!store.excludedBuiltInBundleIDs.contains("com.apple.Terminal"), "re-add clears exclusion")
    Check.expect(store.watchedBundleIDs.contains("com.apple.Terminal"), "re-add effective")

    store.setUserWatchedBundleIDs([" com.z ", "com.a", "com.a", "com.apple.Terminal"])
    Check.equal(store.userWatchedBundleIDs, ["com.a", "com.z"], "extras sanitize+dedupe, drop defaults")
    Check.expect(store.watchedBundleIDs.contains("com.a"), "effective has user a")

    store.isEnabled = true
    store.launchAtLogin = true
    store.removeWatchedBundleID("com.apple.Terminal")
    store.addWatchedBundleID("com.example.Other")
    store.restoreDefaultApplications()
    Check.equal(store.userWatchedBundleIDs, [], "restore clears custom")
    Check.equal(store.excludedBuiltInBundleIDs, [], "restore clears exclusions")
    Check.equal(store.watchedBundleIDs, WatchedApps.defaults, "restore full factory list")
    Check.expect(store.isEnabled, "restore keeps enabled")
    Check.expect(store.launchAtLogin, "restore keeps launchAtLogin")

    defaults.removePersistentDomain(forName: suite)
}

// --- FocusPolicy two-way ---
do {
    let watched: Set<String> = ["com.apple.Terminal", "com.microsoft.VSCode"]

    Check.equal(
        FocusPolicy.decide(isEnabled: false, frontBundleID: "com.apple.Terminal", watched: watched, currentIsEnglish: false, currentIsVietnamese: true).action,
        .none,
        "disabled none"
    )
    Check.equal(
        FocusPolicy.decide(isEnabled: true, frontBundleID: "com.apple.Terminal", watched: watched, currentIsEnglish: false, currentIsVietnamese: true).action,
        .switchToEnglish,
        "watched needs EN"
    )
    Check.equal(
        FocusPolicy.decide(isEnabled: true, frontBundleID: "com.apple.Terminal", watched: watched, currentIsEnglish: true, currentIsVietnamese: false).action,
        .none,
        "watched already EN"
    )
    Check.equal(
        FocusPolicy.decide(isEnabled: true, frontBundleID: "com.microsoft.teams2", watched: watched, currentIsEnglish: true, currentIsVietnamese: false).action,
        .switchToVietnamese,
        "unwatched needs VI"
    )
    Check.equal(
        FocusPolicy.decide(isEnabled: true, frontBundleID: "com.microsoft.teams2", watched: watched, currentIsEnglish: false, currentIsVietnamese: true).action,
        .none,
        "unwatched already VI"
    )
    Check.equal(
        FocusPolicy.decide(isEnabled: true, frontBundleID: nil, watched: watched, currentIsEnglish: false, currentIsVietnamese: false).action,
        .none,
        "nil front none"
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
}

// --- VietnameseSourceResolver ---
do {
    Check.equal(
        VietnameseSourceResolver.resolvePreferredID(
            availableIDs: [
                "com.apple.keylayout.ABC",
                "com.apple.inputmethod.VietnameseIM.VietnameseSimpleTelex",
            ],
            languagesByID: [:]
        ),
        "com.apple.inputmethod.VietnameseIM.VietnameseSimpleTelex",
        "prefer SimpleTelex"
    )
    Check.equal(
        VietnameseSourceResolver.resolvePreferredID(
            availableIDs: ["com.example.OtherVI"],
            languagesByID: ["com.example.OtherVI": ["vi-VN"]]
        ),
        "com.example.OtherVI",
        "fallback language vi"
    )
    Check.expect(
        VietnameseSourceResolver.isVietnameseID("com.apple.inputmethod.VietnameseIM.VietnameseTelex"),
        "isVietnamese known id"
    )
    Check.expect(
        !VietnameseSourceResolver.isVietnameseID("com.apple.keylayout.ABC"),
        "ABC not vietnamese"
    )
}

Check.finish()
