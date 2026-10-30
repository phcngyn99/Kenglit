#!/usr/bin/env bash
# Build Kenglit.app (release) and wrap it in a shareable DMG.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo 0.1.0)"
APP_NAME="Kenglit"
DMG_NAME="${APP_NAME}-${VERSION}"
STAGE="$ROOT/dist/dmg-stage"
# Share artifact at repo root.
DMG_PATH="$ROOT/${DMG_NAME}.dmg"  # repo root — easy to share

./Scripts/pack-app.sh

APP="$ROOT/dist/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP" >&2
  exit 1
fi

rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"

# UDZO = zlib-compressed read-only disk image (good for AirDrop / download).
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGE"

echo
echo "DMG: $DMG_PATH"
echo "Share that file. Receiver: open DMG → drag Kenglit to Applications."
echo
echo "Note: ad-hoc codesign (sign -). Other Macs may Gatekeeper-block."
echo "  First open: right-click Kenglit → Open  (or System Settings → Privacy & Security)."
echo "Public release needs Apple Developer ID + notarization."
