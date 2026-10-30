# AGENTS.md — Kenglit

Guidance for coding agents working in this repository.

## Project

- **Name:** Kenglit (dev.finn.kenglit)
- **Remote:** https://github.com/phcngyn99/Kenglit
- **Primary branch:** develop
- **Stack:** SwiftPM · AppKit menu-bar app · macOS 13+
- **Layout policy:** listed apps → English input; all others → Vietnamese

## Workspace policy

- Feature work only in a **linked git worktree** on a non-protected branch.
- Protected: develop, main, master, release/* — merge-land only, no dirty status.
- Do not force-push, amend shared history, or bypass hooks.

## Layout

- Sources/KenglitApp/ — AppKit UI (settings, status item, focus monitor)
- Sources/KenglitCore/ — preferences, watched-app defaults
- Sources/KenglitCoreChecks/ — unit-style checks (swift run KenglitCoreChecks)
- Resources/ — Info.plist, icons
- Scripts/pack-app.sh — release .app under dist/
- Scripts/pack-dmg.sh — shareable Kenglit-*.dmg at repo root
- docs/superpowers/ — design + plan

## Commands

    make help
    make check
    make reinstall
    make version

    swift build --product Kenglit
    swift run KenglitCoreChecks
    ./Scripts/pack-app.sh
    ./Scripts/pack-dmg.sh
    ./Scripts/uninstall-all.sh
    ./Scripts/install.sh

## Code intelligence

CodeGraph index lives in .codegraph/ (gitignored). Rebuild after large refactors:

    codegraph init -i
    # or: codegraph sync

## Preferences model

- userWatchedBundleIDs — user-added EN apps
- excludedBuiltInBundleIDs — removed factory apps (persist across restart)
- watchedBundleIDs — effective set for the focus monitor
- restoreDefaultApplications() clears custom + exclusions; keeps Enable / Login

## UI conventions

- Settings: compact macOS utility, HIG spacing, NSSwitch toggles
- App rows: icon · name · trailing − (remove)
- Search placeholder: Search enforced apps
- Add action label: Enforce English App

## Do not

- Commit dist/, Kenglit-*.dmg, .build/, tmp/, or CodeGraph DB blobs
- Store secrets or Apple notarization credentials in-repo
- Expand scope beyond the requested Settings/core behavior without asking
