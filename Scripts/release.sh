#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/dist/Kenglit.app"
DMG="$ROOT/Kenglit.dmg"
ZIP="$ROOT/dist/Kenglit-notarize.zip"
IDENTITY="${SIGNING_IDENTITY:-}"
PROFILE="${NOTARY_PROFILE:-}"
TEAM="${SIGNING_TEAM_ID:-}"

fail() { echo "error: $*" >&2; exit 1; }

need_tools() {
  command -v codesign >/dev/null || fail "codesign missing"
  command -v ditto >/dev/null || fail "ditto missing"
  xcrun --find notarytool >/dev/null 2>&1 || fail "notarytool missing (install Xcode CLT/Xcode)"
  xcrun --find stapler >/dev/null 2>&1 || fail "stapler missing"
}

need_identity() {
  [[ -n "$IDENTITY" ]] || fail "SIGNING_IDENTITY is required (Developer ID Application: ...)"
  security find-identity -v -p codesigning | grep -F "$IDENTITY" >/dev/null \
    || fail "identity not found in keychain: $IDENTITY (0 valid identities found on this Mac)"
  if ! security find-identity -v -p codesigning | grep -F "$IDENTITY" | grep -qi "Developer ID Application"; then
    fail "SIGNING_IDENTITY must be a Developer ID Application certificate, not ad-hoc or Apple Development"
  fi
}

need_notary() {
  [[ -n "$PROFILE" ]] || fail "NOTARY_PROFILE is required (run: xcrun notarytool store-credentials)"
}

echo "==> Kenglit release gate"
need_tools
need_identity
need_notary

echo "==> Build + Developer ID sign app"
export KENGLIT_SIGN_MODE=developer-id
export SIGNING_IDENTITY
export KENGLIT_APP_OUT="$APP"
./Scripts/pack-app.sh

echo "==> Notarize app"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SUBMIT_JSON=$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait --output-format json)
echo "$SUBMIT_JSON"
STATUS=$(python3 -c "import json,sys; print(json.load(sys.stdin).get(\"status\",\"\"))" <<<"$SUBMIT_JSON")
SID=$(python3 -c "import json,sys; print(json.load(sys.stdin).get(\"id\",\"\"))" <<<"$SUBMIT_JSON")
[[ "$STATUS" == "Accepted" ]] || {
  echo "notarization failed status=$STATUS id=$SID" >&2
  xcrun notarytool log "$SID" --keychain-profile "$PROFILE" >&2 || true
  fail "app notarization not Accepted"
}
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type exec --verbose=4 "$APP" || true

echo "==> Build DMG from stapled app (no rebuild)"
export KENGLIT_SKIP_PACK_APP=1
export KENGLIT_APP_OUT="$APP"
export KENGLIT_DMG_BG=release
./Scripts/pack-dmg.sh

echo "==> Sign DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --verbose=2 "$DMG"

echo "==> Notarize DMG"
DMG_JSON=$(xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait --output-format json)
echo "$DMG_JSON"
DSTATUS=$(python3 -c "import json,sys; print(json.load(sys.stdin).get(\"status\",\"\"))" <<<"$DMG_JSON")
DID=$(python3 -c "import json,sys; print(json.load(sys.stdin).get(\"id\",\"\"))" <<<"$DMG_JSON")
[[ "$DSTATUS" == "Accepted" ]] || {
  xcrun notarytool log "$DID" --keychain-profile "$PROFILE" >&2 || true
  fail "DMG notarization not Accepted"
}
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG" || true

SHASUM=$(shasum -a 256 "$DMG" | awk "{print \$1}")
echo "RELEASE_OK"
echo "app=$APP"
echo "dmg=$DMG"
echo "sha256=$SHASUM"
echo "app_submission=$SID"
echo "dmg_submission=$DID"
[[ -n "$TEAM" ]] && echo "team=$TEAM"
