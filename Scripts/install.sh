#!/usr/bin/env bash
# Build release .app and install the single copy into ~/Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOME_APPS="${HOME}/Applications"
DEST="${HOME_APPS}/Kenglit.app"

cd "$ROOT"
./Scripts/pack-app.sh

mkdir -p "$HOME_APPS"
# Replace prior install without leaving a second searchable copy in dist/
if [[ -d "$DEST" ]]; then
  osascript -e "tell application \"Finder\" to delete (POSIX file \"$DEST\" as alias)" >/dev/null 2>&1 \
    || mv "$DEST" "/tmp/kenglit-old-install-$(date +%Y%m%d%H%M%S).app"
fi
cp -R "${ROOT}/dist/Kenglit.app" "$DEST"
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1 || true

# Keep only ~/Applications searchable as the live app
if [[ -d "${ROOT}/dist/Kenglit.app" ]]; then
  osascript -e "tell application \"Finder\" to delete (POSIX file \"${ROOT}/dist/Kenglit.app\" as alias)" >/dev/null 2>&1 \
    || mv "${ROOT}/dist/Kenglit.app" "/tmp/kenglit-dist-$(date +%Y%m%d%H%M%S).app"
fi

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREG" ]]; then
  "$LSREG" -f "$DEST" 2>/dev/null || true
fi

VER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
echo "Installed: $DEST"
echo "  version: $VER"
echo "  bundle:  $BID"
echo "Open: open \"$DEST\""
