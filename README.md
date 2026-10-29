# kenglish

Menu-bar macOS app: forces **English** keyboard when a terminal/coding app is focused.

## Requirements

- macOS 13+
- English keyboard layout installed (ABC or US)
- Xcode or Command Line Tools (`xcode-select --install`)

## Build and run

```bash
./Scripts/pack-app.sh
open dist/kenglish.app
```

Debug binary:

```bash
swift build --product Kenglish
```

## Use

1. Menu bar keyboard icon → **Enabled**
2. Focus Terminal / Warp / Cursor → input becomes EN
3. Leave to Teams → stays EN (switch VI yourself)
4. **Settings…** → add bundle IDs, launch at login, **Test switch to EN**

## Verify Cursor bundle ID

```bash
osascript -e 'id of app "Cursor"'
```

Add result in Settings if different from seed default.

## Core tests (no full Xcode)

```bash
swift run KenglishCoreChecks
```

## Design

See `docs/superpowers/specs/2026-10-29-kenglish-design.md`.

## Architecture note

App UI is **AppKit** menu bar (not SwiftUI) so it builds with Command Line Tools alone. Core logic lives in `KenglishCore` and is checked by `KenglishCoreChecks`.
