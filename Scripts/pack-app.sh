#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release --product Kenglish
BIN=$(find .build -name Kenglish -type f -perm +111 | head -1)
OUT="$ROOT/dist/kenglish.app"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/Kenglish"
cp "$ROOT/Resources/Info.plist" "$OUT/Contents/Info.plist"
chmod +x "$OUT/Contents/MacOS/Kenglish"
codesign --force --deep --sign - "$OUT" 2>/dev/null || true
echo "Built: $OUT"
echo "Run: open "$OUT""
