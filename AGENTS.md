# AGENTS.md — Kenglit

## Project

- **Name:** Kenglit (`dev.finn.kenglit`)
- **Remote:** https://github.com/phcngyn99/Kenglit
- **Default branch (GitHub):** main
- **Integration branch:** develop
- **Release channel:** beta (0.1.0-beta)
- **Stack:** SwiftPM · AppKit menu-bar · macOS 13+
- **Policy:** listed apps → English; all others → Vietnamese

## Workspace policy

- Feature work only in a linked git worktree on a non-protected branch.
- Protected: develop, main, master, release/* — merge-land only, no dirty status.
- Do not force-push, amend shared history, or bypass hooks.

## Layout

- `Sources/KenglitApp/` — AppKit UI
- `Sources/KenglitCore/` — preferences, watched-app defaults
- `Sources/KenglitCoreChecks/` — checks (`make check`)
- `Resources/` — Info.plist, icons
- `Scripts/` — pack / install / dmg helpers
- `Kenglit.dmg` — tracked release image (repo root; version in Info.plist / About)
- `docs/superpowers/` — design + plan

## Install artifact

- Click-install file: **`Kenglit.dmg`** at repository root
- Live install path: **`/Applications/Kenglit.app`**
- `make dmg` — local/testing ad-hoc DMG (background-manual; Gatekeeper warning on new Macs)
- `make release` — Developer ID sign + notarize + staple app and DMG (background-release)
- DMG assets: `Resources/dmg/background-manual.*`, `background-release.*`, `layout.json`
- Background DPI must be 72 (1× 760×600) / 144 (2× 1520×1200) → logical 760×600 pt. Run `make dmg-bg-dpi`.
- Visible root items only: `Kenglit.app`, `Applications` (no Install Guide.txt)
- Finder DMG icon is a resource fork — re-run `make dmg-icon` after checkout if needed
- Do not commit `dist/`

## Signing

- Ad-hoc (default `make pack` / `make dmg`): not notarized; recipient sees verify warning
- Release requires `SIGNING_IDENTITY` (Developer ID Application) + `NOTARY_PROFILE`
- `make release` must fail if prerequisites missing — never ship ad-hoc as release

## Commands

    make check
    make icons
    make dmg-bg-dpi
    make dmg
    make dmg-icon
    make release
    make reinstall
    make version

## Branding assets

- Masters: `Resources/Logo/kenglit-app-icon.svg`, `kenglit-mark.svg`, `kenglit-mark-mono.svg`, `kenglit-menubar-template.svg`
- App / DMG: colored mint keycap → `Resources/AppIcon.icns`
- Menu bar: monochrome template PNGs `kenglitTemplate.png` / `@2x` (runtime loads these)
- Regenerate: `make icons` (`Scripts/generate-icons.py`)
- Previews: `docs/branding/`

## Code style

- **No comments in code.** No `//`, `/* */`, or `#` narrative comments in Swift/shell/Make.
- Prefer clear names and small functions over explanatory comments.
- Docs live in `README.md` / `AGENTS.md` / `docs/`, not inline.

## Preferences model

- `userWatchedBundleIDs` — user-added EN apps
- `excludedBuiltInBundleIDs` — removed factory apps
- `watchedBundleIDs` — effective set for the focus monitor
- `restoreDefaultApplications()` clears custom + exclusions; keeps Enable / Login

## UI conventions

- Settings: compact macOS utility, HIG spacing, NSSwitch toggles
- App rows: icon · name · trailing −
- Search placeholder: Search enforced apps
- Add action label: Enforce English App

## Do not

- Add comments to source (see Code style)
- Commit `dist/`, `.build/`, `tmp/`, or CodeGraph DB blobs
- Store secrets or Apple notarization credentials in-repo
- Expand scope beyond the requested change without asking
