#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Kenglit.app"
STALE=(
  "${HOME}/Applications/Kenglit.app"
)

cd "$ROOT"
./Scripts/pack-app.sh

for p in "${STALE[@]}"; do
  if [[ -d "$p" ]]; then
    osascript -e "tell application \"Finder\" to delete (POSIX file \"$p\" as alias)" >/dev/null 2>&1 \
      || mv "$p" "/tmp/kenglit-stale-$(date +%Y%m%d%H%M%S).app"
  fi
done

if [[ -d "$DEST" ]]; then
  osascript -e "tell application \"Finder\" to delete (POSIX file \"$DEST\" as alias)" >/dev/null 2>&1 \
    || mv "$DEST" "/tmp/kenglit-old-install-$(date +%Y%m%d%H%M%S).app"
fi
cp -R "${ROOT}/dist/Kenglit.app" "$DEST"
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1 || true

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
