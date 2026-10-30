#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Kenglit"
STAGE="$ROOT/dist/dmg-stage"
RW_DMG="$ROOT/dist/${APP_NAME}-rw.dmg"
DMG_PATH="$ROOT/${APP_NAME}.dmg"
ICON="$ROOT/Resources/AppIcon.icns"
BG="$ROOT/Resources/dmg/background.png"
GUIDE="$ROOT/Resources/dmg/Install Guide.txt"
STAMP="$(date +%Y%m%d%H%M%S)"

./Scripts/pack-app.sh

APP="$ROOT/dist/${APP_NAME}.app"
[[ -d "$APP" ]] || { echo "error: missing $APP" >&2; exit 1; }
[[ -f "$ICON" ]] || { echo "error: missing $ICON" >&2; exit 1; }
[[ -f "$BG" ]] || { echo "error: missing $BG" >&2; exit 1; }
[[ -f "$GUIDE" ]] || { echo "error: missing $GUIDE" >&2; exit 1; }

if [[ -d "$STAGE" ]]; then mv "$STAGE" "/tmp/kenglit-dmg-stage-$STAMP"; fi
if [[ -f "$RW_DMG" ]]; then mv "$RW_DMG" "/tmp/kenglit-rw-$STAMP.dmg"; fi
if [[ -f "$DMG_PATH" ]]; then mv "$DMG_PATH" "/tmp/kenglit-old-$STAMP.dmg"; fi

mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"
cp "$GUIDE" "$STAGE/Install Guide.txt"
cp "$BG" "$STAGE/.background/background.png"
cp "$ICON" "$STAGE/.VolumeIcon.icns"
SetFile -c icnC "$STAGE/.VolumeIcon.icns" 2>/dev/null || true

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  -fs HFS+ \
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

osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, 760, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    try
      set background picture of opts to file ".background:background.png"
    end try
    set position of item "$APP_NAME.app" of container window to {160, 220}
    set position of item "Applications" of container window to {480, 220}
    set position of item "Install Guide.txt" of container window to {320, 360}
    update without registering applications
    delay 1
    close
    open
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_POINT" >/dev/null
sleep 0.5

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
mv "$RW_DMG" "/tmp/kenglit-rw-done-$STAMP.dmg"
mv "$STAGE" "/tmp/kenglit-dmg-stage-done-$STAMP"

"$ROOT/Scripts/apply-dmg-icon.sh" "$DMG_PATH" "$ICON"
echo "DMG: $DMG_PATH"
