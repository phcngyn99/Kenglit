# Kenglit

Menu bar app for macOS. Frontmost app drives keyboard layout:
listed apps → **English**, everything else → **Vietnamese**.

## Need
- macOS 13+
- English + Vietnamese input sources enabled

## Install (shared build)
Double-click **Kenglit-0.1.0.dmg** at the repo root → drag **Kenglit** into **Applications**.

First launch on another Mac: right-click app → **Open** (ad-hoc signed; Gatekeeper may warn).

Rebuild / refresh the DMG:

    ./Scripts/pack-dmg.sh
    # → ./Kenglit-0.1.0.dmg

App-only package (no DMG):

    ./Scripts/pack-app.sh
    open dist/Kenglit.app

## Use
1. Menu bar icon → **On**
2. Focus a listed app → English
3. Focus anything else → Vietnamese
4. Menu → **Settings…**

### Settings
- **General:** Enable Kenglit · Launch at Login
- **Applications:** search, **User Apps** / **Built-in Apps**
- **Add** — pick apps that should stay English
- **−** on a row — remove (built-in removals persist)
- **Restore Default** — factory app list; keeps General toggles

## Test

    swift run KenglitCoreChecks

## Default English apps
Terminals (Terminal, iTerm2, Warp, Alacritty, WezTerm, Ghostty, kitty, Hyper, Tabby, Rio),
editors/IDEs (VS Code, Cursor, Zed, Xcode, JetBrains, …),
git/clients (GitHub Desktop, Fork, Tower, GitKraken), Docker, Postman, and more.

## Spec
docs/superpowers/specs/2026-10-29-kenglit-design.md
