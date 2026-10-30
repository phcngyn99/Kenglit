# Kenglit

Menu bar app for macOS. Frontmost app drives keyboard layout:
listed apps to **English**, everything else to **Vietnamese**.

**Repository:** https://github.com/phcngyn99/Kenglit
**Default branch:** develop

## Supported versions

| | |
|--|--|
| **macOS** | **13.0 Ventura** and later |
| **Architectures** | Apple Silicon + Intel |
| **App version** | 0.1.0 |
| **Languages** | English UI; EN / VI input sources |

Requires English and Vietnamese keyboard layouts enabled in System Settings → Keyboard.

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
- **Applications:** search (**Search enforced apps**), **User Apps** / **Built-in Apps**
- **Enforce English App** — pick apps that should stay English
- **−** on a row — remove (built-in removals persist)
- **Restore Default** — factory app list; keeps General toggles

## Develop

Clone and work on develop:

    git clone https://github.com/phcngyn99/Kenglit.git
    cd Kenglit
    git checkout develop
    swift run KenglitCoreChecks
    ./Scripts/pack-app.sh

## Spec

docs/superpowers/specs/2026-10-29-kenglit-design.md
