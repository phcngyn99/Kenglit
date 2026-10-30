# Kenglit

Menu bar app for macOS. Frontmost app drives keyboard layout:
listed apps to **English**, everything else to **Vietnamese**.

**Status:** **Beta** (0.1.0-beta)
**Repository:** https://github.com/phcngyn99/Kenglit
**Default branch:** develop
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

Repo root file:

    Kenglit-0.1.0-beta.dmg

On this machine:

    /Users/FinNguyen/Work/not-finn/kenglish/Kenglit-0.1.0-beta.dmg

    open /Users/FinNguyen/Work/not-finn/kenglish/Kenglit-0.1.0-beta.dmg

1. Double-click **`Kenglit-0.1.0-beta.dmg`**
2. Drag **Kenglit** → **Applications** (`/Applications` — Finder sidebar)
3. Eject the DMG
4. First launch elsewhere: right-click Kenglit → **Open** (ad-hoc signed)
5. Menu bar icon → **On**

Install location: **`/Applications/Kenglit.app`** (shows under Finder → Applications).

### From source

    make reinstall

Target: **`/Applications/Kenglit.app`** (Finder → Applications).
May prompt once for **admin password** (account is not in `admin` group).
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
    git checkout develop
    make check
    make reinstall

    make help
    make build | check | pack | dmg | install | uninstall | reinstall | open | version | clean

## Spec

docs/superpowers/specs/2026-10-29-kenglit-design.md
