#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${1:-$ROOT/Kenglit.dmg}"
ICON="${2:-$ROOT/Resources/AppIcon.icns}"
STAMP="$(date +%Y%m%d%H%M%S)"

[[ -f "$DMG_PATH" ]] || { echo "error: missing $DMG_PATH" >&2; exit 1; }
[[ -f "$ICON" ]] || { echo "error: missing $ICON" >&2; exit 1; }

ICON_TMP="/tmp/kenglit-dmg-icon-$STAMP.icns"
RSRC="/tmp/kenglit-dmg-icon-$STAMP.rsrc"
cp "$ICON" "$ICON_TMP"
sips -i "$ICON_TMP" >/dev/null
DeRez -only icns "$ICON_TMP" > "$RSRC"
Rez -append "$RSRC" -o "$DMG_PATH"
SetFile -a C "$DMG_PATH"
echo "Finder icon applied: $DMG_PATH"
