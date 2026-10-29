# Kenglit

Menu-bar macOS app: forces **English** keyboard when a terminal/coding app is focused.

## Requirements

- macOS 13+
- English keyboard layout installed (ABC or US)
- Xcode or Command Line Tools (`xcode-select --install`)

## Build and run

```bash
./Scripts/pack-app.sh
open dist/kenglit.app
```

Debug binary:

```bash
swift build --product Kenglit
```

## Use

1. Menu bar keyboard icon → **Enabled**
2. Focus Terminal / Warp / Cursor → input becomes EN
3. Leave to Teams / browser → auto Vietnamese
4. **Settings…** → add bundle IDs, launch at login, **Test switch to EN**

## Verify Cursor bundle ID

```bash
osascript -e 'id of app "Cursor"'
```

Add result in Settings if different from seed default.

## Core tests (no full Xcode)

```bash
swift run KenglitCoreChecks
```

## Design

See `docs/superpowers/specs/2026-10-29-kenglit-design.md`.

## Architecture note

App UI is **AppKit** menu bar (not SwiftUI) so it builds with Command Line Tools alone. Core logic lives in `KenglitCore` and is checked by `KenglitCoreChecks`.
