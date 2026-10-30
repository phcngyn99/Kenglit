# Kenglit

Menu bar app. Terminal focus -> EN. Else -> VI.

## Need
- macOS 13+
- EN + VI keyboard on

## Build
    ./Scripts/pack-app.sh
    open dist/Kenglit.app

## Use
1. Menu ON
2. Terminal -> EN
3. Other app -> VI
4. Settings -> apps / login start

## Add app
Settings -> Add Apps… (browse /Applications)
List shows app icon + name.
Or Add front.

    osascript -e 'id of app "Cursor"'

## Test core
    swift run KenglitCoreChecks

## Default EN apps
Terminal, iTerm2, Warp, Alacritty, WezTerm, Ghostty, kitty, Hyper, Tabby, Rio
VS Code, Cursor, Zed, Nova, Sublime, CotEditor, BBEdit, TextMate, Xcode
JetBrains pack, Android Studio
GitHub Desktop, Fork, Tower, GitKraken, Docker, Postman

Upgrade merge new defaults. No wipe.

## Spec
docs/superpowers/specs/2026-10-29-kenglit-design.md
