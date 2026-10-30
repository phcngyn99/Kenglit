#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo 0.1.0)"
APP_NAME="Kenglit"
DMG_NAME="${APP_NAME}-${VERSION}"
STAGE="$ROOT/dist/dmg-stage"
DMG_PATH="$ROOT/${DMG_NAME}.dmg"

./Scripts/pack-app.sh

APP="$ROOT/dist/${APP_NAME}.app"
[[ -d "$APP" ]] || { echo "error: missing $APP" >&2; exit 1; }

if [[ -d "$STAGE" ]]; then mv "$STAGE" "/tmp/kenglit-dmg-stage-$(date +%Y%m%d%H%M%S)"; fi
if [[ -f "$DMG_PATH" ]]; then mv "$DMG_PATH" "/tmp/kenglit-old-$(basename "$DMG_PATH")-$(date +%Y%m%d%H%M%S)"; fi
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

mv "$STAGE" "/tmp/kenglit-dmg-stage-done-$(date +%Y%m%d%H%M%S)"
echo "DMG: $DMG_PATH"
