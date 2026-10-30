import Foundation

public enum WatchedApps {
    /// Terminals, IDEs, and coding tools that should force English.
    public static let defaults: [String] = normalized([
        // Apple
        "com.apple.Terminal",
        "com.apple.dt.Xcode",

        // Terminals
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "dev.warp.Warp-Preview",
        "org.alacritty",
        "io.alacritty",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "co.zeit.hyper",
        "org.tabby",
        "ai.tabby.desktop",
        "com.github.raphamorim.rio",
        "com.rio-labs.rio",

        // Editors / IDEs
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "dev.zed.Zed",
        "dev.zed.Zed-Preview",
        "com.panic.Nova",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.coteditor.CotEditor",
        "com.barebones.bbedit",
        "com.macromates.TextMate",

        // JetBrains family
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce",
        "com.jetbrains.AppCode",
        "com.jetbrains.CLion",
        "com.jetbrains.WebStorm",
        "com.jetbrains.PhpStorm",
        "com.jetbrains.pycharm",
        "com.jetbrains.pycharm.ce",
        "com.jetbrains.GoLand",
        "com.jetbrains.rubymine",
        "com.jetbrains.datagrip",
        "com.jetbrains.rider",
        "com.jetbrains.RustRover",
        "com.google.android.studio",

        // Git clients (often type EN commands/messages)
        "com.github.GitHubClient",
        "com.DanPristupov.Fork",
        "com.git-tower.Tower",
        "com.axosoft.gitkraken",

        // Dev tooling with command/input focus
        "com.docker.docker",
        "com.electron.dockerdesktop",
        "com.postmanlabs.mac",
    ])

    /// Friendly labels for known bundle IDs (settings UI).
    public static let displayNames: [String: String] = [
        "com.apple.Terminal": "Terminal",
        "com.apple.dt.Xcode": "Xcode",
        "com.googlecode.iterm2": "iTerm2",
        "dev.warp.Warp-Stable": "Warp",
        "dev.warp.Warp": "Warp",
        "dev.warp.Warp-Preview": "Warp Preview",
        "org.alacritty": "Alacritty",
        "io.alacritty": "Alacritty",
        "com.github.wez.wezterm": "WezTerm",
        "com.mitchellh.ghostty": "Ghostty",
        "net.kovidgoyal.kitty": "kitty",
        "co.zeit.hyper": "Hyper",
        "org.tabby": "Tabby",
        "ai.tabby.desktop": "Tabby",
        "com.github.raphamorim.rio": "Rio",
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.microsoft.VSCodeInsiders": "VS Code Insiders",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "dev.zed.Zed": "Zed",
        "dev.zed.Zed-Preview": "Zed Preview",
        "com.panic.Nova": "Nova",
        "com.sublimetext.4": "Sublime Text 4",
        "com.sublimetext.3": "Sublime Text 3",
        "com.coteditor.CotEditor": "CotEditor",
        "com.barebones.bbedit": "BBEdit",
        "com.macromates.TextMate": "TextMate",
        "com.jetbrains.intellij": "IntelliJ IDEA",
        "com.jetbrains.intellij.ce": "IntelliJ IDEA CE",
        "com.jetbrains.AppCode": "AppCode",
        "com.jetbrains.CLion": "CLion",
        "com.jetbrains.WebStorm": "WebStorm",
        "com.jetbrains.PhpStorm": "PhpStorm",
        "com.jetbrains.pycharm": "PyCharm",
        "com.jetbrains.pycharm.ce": "PyCharm CE",
        "com.jetbrains.GoLand": "GoLand",
        "com.jetbrains.rubymine": "RubyMine",
        "com.jetbrains.datagrip": "DataGrip",
        "com.jetbrains.rider": "Rider",
        "com.jetbrains.RustRover": "RustRover",
        "com.google.android.studio": "Android Studio",
        "com.google.Chrome": "Google Chrome",
        "com.google.Chrome.canary": "Chrome Canary",
        "com.google.Chrome.beta": "Chrome Beta",
        "company.thebrowser.Browser": "Arc",
        "com.brave.Browser": "Brave",
        "com.microsoft.edgemac": "Microsoft Edge",
        "org.mozilla.firefox": "Firefox",
        "com.apple.Safari": "Safari",

        "com.github.GitHubClient": "GitHub Desktop",
        "com.DanPristupov.Fork": "Fork",
        "com.git-tower.Tower": "Tower",
        "com.axosoft.gitkraken": "GitKraken",
        "com.docker.docker": "Docker Desktop",
        "com.electron.dockerdesktop": "Docker Desktop",
        "com.postmanlabs.mac": "Postman",
    ]

    public static func displayName(for bundleID: String) -> String {
        displayNames[bundleID] ?? bundleID
    }

    public static func normalized(_ ids: [String]) -> [String] {
        let cleaned = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(cleaned)).sorted()
    }
}
