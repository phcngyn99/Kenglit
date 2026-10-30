#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="${KENGLIT_SIGN_MODE:-adhoc}"
OUT="${KENGLIT_APP_OUT:-$ROOT/dist/Kenglit.app}"
IDENTITY="${SIGNING_IDENTITY:-}"

swift build -c release --product Kenglit
BIN=$(find .build -name Kenglit -type f -perm +111 | head -1)
[[ -n "$BIN" && -f "$BIN" ]] || { echo "error: Kenglit binary not found" >&2; exit 1; }

mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/Kenglit"
cp "$ROOT/Resources/Info.plist" "$OUT/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$OUT/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/Logo/kenglitTemplate.png" "$OUT/Contents/Resources/kenglitTemplate.png"
cp "$ROOT/Resources/Logo/kenglitTemplate@2x.png" "$OUT/Contents/Resources/walt.e@example.net"
chmod +x "$OUT/Contents/MacOS/Kenglit"

case "$MODE" in
  none)
    echo "Built (unsigned): $OUT"
    ;;
  adhoc)
    codesign --force --sign - "$OUT/Contents/MacOS/Kenglit"
    codesign --force --sign - "$OUT"
    codesign --verify --verbose=2 "$OUT"
    echo "Built (ad-hoc): $OUT"
    ;;
  developer-id)
    [[ -n "$IDENTITY" ]] || { echo "error: SIGNING_IDENTITY required for developer-id" >&2; exit 1; }
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$OUT/Contents/MacOS/Kenglit"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$OUT"
    codesign --verify --deep --strict --verbose=2 "$OUT"
    echo "Built (Developer ID): $OUT"
    echo "identity=$IDENTITY"
    ;;
  *)
    echo "error: unknown KENGLIT_SIGN_MODE=$MODE" >&2
    exit 1
    ;;
esac
