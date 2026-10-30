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

1. Open **`Kenglit.dmg`** — window shows steps 1–3
2. Drag **Kenglit** → **Applications**
3. First open: **right-click Kenglit → Open → Open** (see window / **Install Guide.txt**)
4. Menu bar → **On**

### Gatekeeper (new Mac)

Ad-hoc beta — not notarized. Warning is normal.

- **Right-click** Applications → Kenglit → **Open** → **Open**
- Or Privacy & Security → **Open Anyway**
- After download, if stuck: `xattr -cr /Applications/Kenglit.app` then right-click Open

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
