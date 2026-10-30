# Kenglit

Menu bar app for macOS. Frontmost app drives keyboard layout:
listed apps to **English**, everything else to **Vietnamese**.

**Repository:** https://github.com/phcngyn99/Kenglit
**Default branch:** develop
**Author:** Finn Nguyen × Hawking

## Version

| | |
|--|--|
| **App** | **0.1.0** (CFBundleShortVersionString) |
| **Build** | 1 (CFBundleVersion) |
| **Bundle ID** | dev.finn.kenglit |
| **macOS** | **13.0 Ventura** and later |
| **Architectures** | Apple Silicon + Intel |
| **UI language** | English |
| **Layouts** | English + Vietnamese input sources |

    make version

## Install

### Makefile (recommended)

    make install      # pack + install to ~/Applications (one copy)
    make open         # launch
    make uninstall    # quit + remove all Kenglit.app copies
    make reinstall    # uninstall + install + launch

Avoids Spotlight doubles from leftover dist/ or worktree build products.

### DMG share

    make dmg
    # -> ./Kenglit-0.1.0.dmg at repo root

Double-click DMG, drag Kenglit into Applications.
First launch on another Mac: right-click then Open (ad-hoc signed).

### Scripts

    ./Scripts/pack-app.sh
    ./Scripts/install.sh
    ./Scripts/uninstall-all.sh
    ./Scripts/reinstall.sh
    ./Scripts/pack-dmg.sh

## Use

1. Menu bar icon -> On
2. Focus a listed app -> English
3. Focus anything else -> Vietnamese
4. Menu -> Settings (info button for About + version)

### Settings

- General: Enable Kenglit · Launch at Login
- Applications: search (Search enforced apps), User Apps / Built-in Apps
- Enforce English App — pick apps that should stay English
- minus on a row — remove (built-in removals persist)
- Restore Default — factory app list; keeps General toggles

## Develop

    git clone https://github.com/phcngyn99/Kenglit.git
    cd Kenglit
    git checkout develop
    make check
    make reinstall

### Make targets

    make help
    make build
    make check
    make pack
    make dmg
    make install
    make uninstall
    make reinstall
    make open
    make version
    make clean

## Spec

docs/superpowers/specs/2026-10-29-kenglit-design.md
