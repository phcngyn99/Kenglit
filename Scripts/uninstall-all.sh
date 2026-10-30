#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pkill -x Kenglit 2>/dev/null || true
sleep 0.3

paths=(
  "/Applications/Kenglit.app"
  "${HOME}/Applications/Kenglit.app"
  "${ROOT}/dist/Kenglit.app"
)

while IFS= read -r p; do
  paths+=("$p")
done < <(find "${ROOT}/.worktrees" -type d -name 'Kenglit.app' 2>/dev/null || true)

removed=0
for p in "${paths[@]}"; do
  if [[ -d "$p" ]]; then
    if osascript -e "tell application \"Finder\" to delete (POSIX file \"$p\" as alias)" >/dev/null 2>&1; then
      removed=$((removed + 1))
    else
      stamp="$(date +%Y%m%d%H%M%S)"
      dest="/tmp/kenglit-uninstall-${stamp}-$(basename "$(dirname "$p")")-Kenglit.app"
      mv "$p" "$dest"
      removed=$((removed + 1))
    fi
  fi
done

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREG" ]]; then
  "$LSREG" -u "/Applications/Kenglit.app" 2>/dev/null || true
  "$LSREG" -u "${HOME}/Applications/Kenglit.app" 2>/dev/null || true
fi

echo "Uninstalled (${removed})"
