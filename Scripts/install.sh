#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/dist/Kenglit.app"
DEST="/Applications/Kenglit.app"

cd "$ROOT"
./Scripts/pack-app.sh
[[ -d "$SRC" ]] || { echo "error: missing $SRC" >&2; exit 1; }

trash_path() {
  local p="$1"
  [[ -e "$p" ]] || return 0
  osascript -e "tell application \"Finder\" to delete (POSIX file \"$p\" as alias)" >/dev/null 2>&1 \
    || mv "$p" "/tmp/kenglit-trash-$(date +%Y%m%d%H%M%S)-$(basename "$p")"
}

trash_path "${HOME}/Applications/Kenglit.app"
trash_path "$DEST"

if cp -R "$SRC" "$DEST" 2>/dev/null; then
  :
else
  echo "Need admin to write /Applications (macOS password prompt)…"
  osascript -e "do shell script \"ditto \" & quoted form of \"$SRC\" & \" \" & quoted form of \"$DEST\" with administrator privileges" \
    || { echo "error: install to $DEST failed (admin canceled or denied)" >&2; exit 1; }
fi

codesign --force --deep --sign - "$DEST" >/dev/null 2>&1 || true
trash_path "$SRC"

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREG" ]]; then
  "$LSREG" -f "$DEST" 2>/dev/null || true
fi

VER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
echo "Installed: $DEST"
echo "  version: $VER"
echo "  bundle:  $BID"
