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
- Live install path: **`/Applications/Kenglit.app`** (`make install` / `make reinstall`)
- `/Applications` write may prompt admin password via osascript
- Rebuild DMG: `make dmg` → `Kenglit.dmg` (install window layout + guide + AppIcon)
- DMG assets: `Resources/dmg/background.png`, `Resources/dmg/1. READ ME FIRST.txt` (auto-opens)
- Finder file icon uses a resource fork (not stored by git). After checkout/merge: `make dmg-icon`
- Gatekeeper: ad-hoc beta — first launch needs right-click Open / Open Anyway (see README)
- Do not put release DMGs under `dist/` (gitignored)
- Uninstall also clears stale `~/Applications/Kenglit.app`

## Commands

    make check
    make icons
    make reinstall
    make dmg
    make dmg-icon
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
