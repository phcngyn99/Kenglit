# kenglit — Design Spec

**Date:** 2026-10-29  
**Status:** Approved for planning  
**Product:** macOS menu-bar app that forces English input when a terminal/coding app is focused.

## Problem

User switches keyboard between Vietnamese (Teams/chat) and English (terminal). Forgetting to switch to EN in the terminal causes bad commands and friction. Desire: auto-EN when focus enters a terminal-like or coding app; no auto-restore on leave.

## Goals

1. Force English keyboard when a watched app becomes frontmost.
2. Leave input source alone when leaving that app (user switches VI manually).
3. Menu-bar control: on/off, settings, quit; optional launch at login.
4. Editable watched-app list (bundle IDs), including whole Cursor/VS Code windows.

## Non-goals (v1)

- Pane-level detection inside IDEs (only whole-app focus).
- Auto-switch back to Vietnamese.
- Accessibility-permission features.
- Homebrew cask / notarized distribution (local ad-hoc sign is enough).
- Windows/Linux.

## Approach

**Native Swift menu-bar app** (single process). Observe `NSWorkspace.didActivateApplicationNotification`. On bundle-ID match, select an English Text Input Source via Carbon TIS APIs. No Accessibility permission required for whole-app path.

Rejected alternatives:
- Hammerspoon/im-select config — faster to setup, not a owned app, weaker login/menu UX.
- Electron/Tauri — heavy for a menu-bar toggle.

## Architecture

```
MenuBarExtra (on/off · Settings · Quit)
        │
AppFocusMonitor  ←  NSWorkspace.didActivateApplicationNotification
        │ bundleID ∈ watched?
InputSourceSwitcher  ←  TISCopyCurrentKeyboardInputSource / TISSelectInputSource
        │
PreferencesStore (UserDefaults) + LaunchAtLogin (SMAppService)
```

### Modules

| Module | Responsibility |
|--------|----------------|
| `KenglitApp` | `@main`, `MenuBarExtra`, app lifecycle |
| `AppFocusMonitor` | Subscribe/unsubscribe; debounce ~50–100ms |
| `InputSourceSwitcher` | Resolve EN source; select if not already EN |
| `PreferencesStore` | enabled, launchAtLogin, watched bundle IDs |
| `LaunchAtLogin` | `SMAppService.mainApp` register/unregister |

### English source resolution (stable order)

1. Prefer `com.apple.keylayout.ABC`
2. Else `com.apple.keylayout.US`
3. Else first enabled keyboard-layout source with language `en`
4. If none: show menu warning; do not crash; skip switch

### Default watched bundle IDs

- `com.apple.Terminal`
- `com.googlecode.iterm2`
- `dev.warp.Warp-Stable`
- `org.alacritty` / `io.alacritty`
- `com.github.wez.wezterm`
- `com.mitchellh.ghostty`
- `com.microsoft.VSCode`
- Cursor desktop bundle ID (verify on machine at implement time; seed known IDs)
- `com.apple.dt.Xcode`
- `com.jetbrains.intellij` / `com.jetbrains.WebStorm`

Settings must support: toggle defaults, add current front app, add/remove custom bundle ID, "Test switch to EN now".

## Behavior

| Event | Action |
|-------|--------|
| Watched app becomes frontmost, feature ON, current ≠ EN | Select EN |
| Watched app frontmost, already EN | No-op |
| Unwatched app becomes frontmost | No-op (leave EN or whatever is active) |
| Feature OFF | Ignore all focus events |
| EN source missing | Menu warning only |
| Rapid focus changes | Debounce; act on final front app |
| System wake | Re-evaluate frontmost app |

## UI

- Menu bar only (`MenuBarExtra`); no Dock icon (`LSUIElement` behavior via menu-bar-only app).
- SF Symbol `keyboard` (or similar); visual on/off state (e.g. color or badge).
- Settings: master enable, launch at login, app list, test button.

## Platform & packaging

- macOS 13+ (Ventura) for `MenuBarExtra` + `SMAppService`.
- Bundle ID: `dev.finn.kenglit`
- Ad-hoc code sign for local use; notarization optional later.
- Deliver as `.app` (Xcode project or SwiftPM + pack script).

## Permissions

None required for v1 (workspace activation notifications + TIS).

## Success criteria

1. Focus Terminal / Warp / Cursor → EN within ~100ms.
2. Switch to Teams → input stays EN until user changes it.
3. Menu Off stops auto-switching.
4. Launch at login survives reboot.
5. Custom bundle ID addable without rebuild.
6. No Accessibility prompt.

## Test plan (manual)

1. On → cycle Terminal, Cursor, Safari, Teams; confirm EN only on watched apps and sticky after leave.
2. Off mid-session → no further switches.
3. "Test switch to EN" while on VI.
4. Relaunch app; reboot with launch-at-login.
5. Temporarily disable EN layout → warning path, no crash.
6. Add custom bundle ID of a non-default app; verify match.

## Open implement-time checks

- Exact Cursor bundle ID(s) on the target Mac.
- Confirm ABC vs US presence on the user machine; wire resolution order as specified.

## Roadmap (post-v1, not scheduled)

- Pane-level IDE terminal (needs Accessibility / AX tree).
- Optional restore-previous-source on leave.
- Homebrew cask + notarization.
