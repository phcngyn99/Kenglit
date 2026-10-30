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

    store.removeWatchedBundleID("com.apple.Terminal")
    Check.expect(store.excludedBuiltInBundleIDs.contains("com.apple.Terminal"), "builtin excluded")
    Check.expect(!store.watchedBundleIDs.contains("com.apple.Terminal"), "excluded gone from effective")
    Check.expect(!store.activeBuiltInBundleIDs.contains("com.apple.Terminal"), "not in active builtin")

    let reloaded2 = PreferencesStore(defaults: defaults)
    Check.expect(reloaded2.excludedBuiltInBundleIDs.contains("com.apple.Terminal"), "exclusion persists")
    Check.expect(!reloaded2.watchedBundleIDs.contains("com.apple.Terminal"), "persisted exclusion effective")

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

do {
    var model = SettingsListModel()
    let custom = ["com.example.Chrome"]
    let builtIn = ["com.apple.Terminal", "com.microsoft.VSCode"]
    let name: (String) -> String = {
        switch $0 {
        case "com.example.Chrome": return "Google Chrome"
        case "com.apple.Terminal": return "Terminal"
        case "com.microsoft.VSCode": return "Visual Studio Code"
        default: return $0
        }
    }

    var rows = model.rows(customIDs: custom, builtInIDs: builtIn, name: name)
    Check.expect(
        rows.contains { if case .header(.custom, _, true) = $0 { return true }; return false },
        "User Apps expanded by default"
    )
    Check.expect(
        rows.contains { if case .header(.builtIn, _, true) = $0 { return true }; return false },
        "Built-in Apps expanded by default"
    )
    Check.expect(
        rows.contains { if case .app(let id) = $0 { return id == "com.example.Chrome" }; return false },
        "User Apps shows Chrome when expanded"
    )
    Check.expect(
        rows.contains { if case .app(let id) = $0 { return id == "com.apple.Terminal" }; return false },
        "Built-in shows Terminal when expanded"
    )

    model.toggle(.custom)
    rows = model.rows(customIDs: custom, builtInIDs: builtIn, name: name)
    Check.expect(!model.customExpanded, "User Apps collapsed flag")
    Check.expect(model.builtInExpanded, "Built-in still expanded after User collapse")
    Check.expect(
        rows.contains { if case .header(.custom, _, false) = $0 { return true }; return false },
        "User header shows collapsed"
    )
    Check.expect(
        !rows.contains { if case .app(let id) = $0 { return id == "com.example.Chrome" }; return false },
        "Chrome hidden when User collapsed"
    )
    Check.expect(
        rows.contains { if case .app(let id) = $0 { return id == "com.apple.Terminal" }; return false },
        "Terminal still visible"
    )

    model.toggle(.builtIn)
    rows = model.rows(customIDs: custom, builtInIDs: builtIn, name: name)
    Check.expect(!model.builtInExpanded, "Built-in collapsed flag")
    Check.expect(
        !rows.contains { if case .app = $0 { return true }; return false },
        "No app rows when both collapsed"
    )
    Check.equal(rows.count, 2, "only two headers when both collapsed")

    model.toggle(.custom)
    rows = model.rows(customIDs: custom, builtInIDs: builtIn, name: name)
    Check.expect(model.customExpanded, "User re-expanded")
    Check.expect(
        rows.contains { if case .app(let id) = $0 { return id == "com.example.Chrome" }; return false },
        "Chrome back after re-expand"
    )

    rows = model.rows(customIDs: [], builtInIDs: builtIn, name: name)
    Check.expect(
        rows.contains { if case .empty("No user apps added.") = $0 { return true }; return false },
        "empty User message when expanded and empty"
    )

    model.toggle(.custom)
    rows = model.rows(customIDs: [], builtInIDs: [], name: name)
    Check.expect(
        !rows.contains { if case .empty = $0 { return true }; return false },
        "no empty rows when sections collapsed"
    )

    model = SettingsListModel(customExpanded: true, builtInExpanded: true)
    rows = model.rows(customIDs: custom, builtInIDs: builtIn, name: name)
    Check.equal(SettingsListModel.handleRowClick(0, in: rows), .custom, "click User header")
    Check.equal(SettingsListModel.handleRowClick(1, in: rows), nil, "click app is not section")
    Check.equal(SettingsListModel.handleRowClick(2, in: rows), .builtIn, "click Built-in header")

    model = SettingsListModel(customExpanded: true, builtInExpanded: false)
    rows = model.rows(customIDs: [], builtInIDs: builtIn, name: name)
    Check.equal(SettingsListModel.handleRowClick(1, in: rows), .custom, "click empty User collapses section")
    Check.equal(SettingsListModel.handleRowClick(2, in: rows), .builtIn, "click collapsed Built-in header")

    model = SettingsListModel(customExpanded: false, builtInExpanded: false, filter: "term")
    model.expandSectionsMatching(customIDs: custom, builtInIDs: builtIn, name: name)
    Check.expect(!model.customExpanded, "search Term does not expand User (no match)")
    Check.expect(model.builtInExpanded, "search Term expands Built-in (Terminal match)")
    rows = model.rows(customIDs: custom, builtInIDs: builtIn, name: name)
    Check.expect(
        rows.contains { if case .app(let id) = $0 { return id == "com.apple.Terminal" }; return false },
        "Terminal visible under search"
    )
    Check.expect(
        !rows.contains { if case .app(let id) = $0 { return id == "com.microsoft.VSCode" }; return false },
        "VS Code filtered out by search"
    )
}

Check.finish()
