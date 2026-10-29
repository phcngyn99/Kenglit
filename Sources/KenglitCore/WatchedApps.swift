import Foundation

public enum WatchedApps {
    public static let defaults: [String] = normalized([
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "org.alacritty",
        "io.alacritty",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92", // Cursor (verify later)
        "com.apple.dt.Xcode",
        "com.jetbrains.intellij",
        "com.jetbrains.WebStorm",
    ])

    public static func normalized(_ ids: [String]) -> [String] {
        let cleaned = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(cleaned)).sorted()
    }
}
