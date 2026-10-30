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

Share file: **`Kenglit.dmg`** at the repo root.

### A. Notarized release (when available)

Built with `make release` (Developer ID + notarize + staple). On a new Mac:

1. Open **Kenglit.dmg**
2. Drag **Kenglit** → **Applications**
3. Eject the disk
4. Double-click **Kenglit** in Applications
5. Menu bar → **On**

A normal “downloaded from the Internet” confirmation can still appear. That is not the malware-block dialog.

### B. Unnotarized beta (current default artifact)

This Mac has **no Developer ID certificate** (`0 valid identities`), so day-to-day `make dmg` produces an **ad-hoc** build. Recipients may see:

> Apple could not verify “Kenglit” is free of malware…

**That warning is expected** until a notarized release is published. Artwork cannot remove it.

1. Open **Kenglit.dmg** (manual-approval steps are on the window)
2. Drag **Kenglit** → **Applications**
3. Open the installed app **once**
4. **System Settings → Privacy & Security → Open Anyway** → confirm **Open**
5. Menu bar → **On**

Do not disable Gatekeeper. Prefer Apple’s Privacy & Security flow (Sequoia+).
Official steps: [If you want to open an app that hasn’t been notarized…](https://support.apple.com/en-gb/102445)

### From source (local ad-hoc)

    make reinstall

### Release build (Developer ID required)

    export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
    export NOTARY_PROFILE="Kenglit"   # from: xcrun notarytool store-credentials
    make release

`make release` **fails clearly** if the identity/profile is missing. It must not emit a silent ad-hoc DMG labeled as release.

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
