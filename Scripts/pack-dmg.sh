#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Kenglit"
STAGE="$ROOT/dist/dmg-stage"
RW_DMG="$ROOT/dist/${APP_NAME}-rw.dmg"
DMG_PATH="$ROOT/${APP_NAME}.dmg"
ICON="$ROOT/Resources/AppIcon.icns"
STAMP="$(date +%Y%m%d%H%M%S)"

./Scripts/pack-app.sh

APP="$ROOT/dist/${APP_NAME}.app"
[[ -d "$APP" ]] || { echo "error: missing $APP" >&2; exit 1; }
[[ -f "$ICON" ]] || { echo "error: missing $ICON" >&2; exit 1; }

if [[ -d "$STAGE" ]]; then mv "$STAGE" "/tmp/kenglit-dmg-stage-$STAMP"; fi
if [[ -f "$RW_DMG" ]]; then mv "$RW_DMG" "/tmp/kenglit-rw-$STAMP.dmg"; fi
if [[ -f "$DMG_PATH" ]]; then mv "$DMG_PATH" "/tmp/kenglit-old-$STAMP.dmg"; fi

mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"
cp "$ICON" "$STAGE/.VolumeIcon.icns"
SetFile -c icnC "$STAGE/.VolumeIcon.icns" 2>/dev/null || true

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$RW_DMG" >/dev/null

MOUNT_DIR="/Volumes/${APP_NAME}"
if [[ -d "$MOUNT_DIR" ]]; then
  hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
  sleep 0.3
fi

ATTACH_OUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
echo "$ATTACH_OUT"
MOUNT_POINT="$(echo "$ATTACH_OUT" | awk '/\/Volumes\// {print $NF; exit}')"
[[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]] || { echo "error: mount failed" >&2; exit 1; }

if [[ -f "$MOUNT_POINT/.VolumeIcon.icns" ]]; then
  SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
  SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
fi

hdiutil detach "$MOUNT_POINT" >/dev/null
sleep 0.3

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
mv "$RW_DMG" "/tmp/kenglit-rw-done-$STAMP.dmg"
mv "$STAGE" "/tmp/kenglit-dmg-stage-done-$STAMP"

ICON_TMP="/tmp/kenglit-dmg-icon-$STAMP.icns"
RSRC="/tmp/kenglit-dmg-icon-$STAMP.rsrc"
cp "$ICON" "$ICON_TMP"
sips -i "$ICON_TMP" >/dev/null
DeRez -only icns "$ICON_TMP" > "$RSRC"
Rez -append "$RSRC" -o "$DMG_PATH"
SetFile -a C "$DMG_PATH"

echo "DMG: $DMG_PATH"
