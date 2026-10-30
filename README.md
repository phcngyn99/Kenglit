# Kenglit

Menu bar app for macOS. Frontmost app drives keyboard layout:
listed apps to **English**, everything else to **Vietnamese**.

**Status:** **Beta** (0.1.0-beta)
**Repository:** https://github.com/phcngyn99/Kenglit
**Default branch:** main
**Author:** Finn Nguyen × Hawking

## Version

| | |
|--|--|
| **Channel** | **beta** |
| **App** | **0.1.0-beta** |
| **Build** | 2 |
| **Bundle ID** | `dev.finn.kenglit` |
| **macOS** | **13.0+** |
| **Arch** | Apple Silicon + Intel |

    make version

## Install

### Click to install (DMG)

Repo root file (version is inside the app / About, not the filename):

    Kenglit.dmg

    open /Users/FinNguyen/Work/not-finn/kenglish/Kenglit.dmg

1. Double-click **`Kenglit.dmg`** (window + **1. READ ME FIRST.txt** open)
2. Drag **Kenglit** → **Applications**
3. Eject the DMG
4. First launch (see Gatekeeper below) — **right-click Open**, not double-click
5. Menu bar icon → **On**

Install location: **`/Applications/Kenglit.app`**. Version: Settings → ⓘ.

### Gatekeeper (“Apple could not verify…”)

Beta builds are **ad-hoc signed**, not Apple-notarized. First open often shows:

> Apple could not verify “Kenglit” is free of malware that may harm your Mac or compromise your privacy.

**Fix (pick one):**

1. Finder → Applications → **right-click Kenglit** → **Open** → **Open**
2. Or: System Settings → **Privacy & Security** → scroll to Security → **Open Anyway** → confirm
3. If it was blocked after a browser download:

       xattr -cr /Applications/Kenglit.app

   Then right-click → **Open** again.

This is expected until a Developer ID + notarized release ships.

### From source

    make reinstall

Target: **`/Applications/Kenglit.app`**. May prompt for admin password.
Also removes stale `~/Applications/Kenglit.app`.

## Use

1. Focus a listed app → English
2. Focus anything else → Vietnamese
3. Menu → **Settings…** (ⓘ for About)

### Settings

- **General:** Enable Kenglit · Launch at Login
- **Applications:** Search enforced apps · User Apps / Built-in Apps
- **Enforce English App** — add EN apps
- **−** — remove (built-in removals persist)
- **Restore Default** — factory app list; keeps General toggles

## Develop

    git clone https://github.com/phcngyn99/Kenglit.git
    cd Kenglit
    git checkout main
    make check
    make reinstall

    make help
    make build | check | pack | dmg | install | uninstall | reinstall | open | version | clean

## Spec

docs/superpowers/specs/2026-10-29-kenglit-design.md
