#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release --product Kenglit
BIN=$(find .build -name Kenglit -type f -perm +111 | head -1)
OUT="$ROOT/dist/kenglit.app"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/Kenglit"
cp "$ROOT/Resources/Info.plist" "$OUT/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$OUT/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/Logo/kenglitTemplate.png" "$OUT/Contents/Resources/kenglitTemplate.png"
cp "$ROOT/Resources/Logo/kenglitTemplate@2x.png" "$OUT/Contents/Resources/walt.e@example.net"
chmod +x "$OUT/Contents/MacOS/Kenglit"
codesign --force --deep --sign - "$OUT" 2>/dev/null || true
echo "Built: $OUT"
echo "Run: open \"$OUT\""
