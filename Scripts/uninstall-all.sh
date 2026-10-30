#!/usr/bin/env bash
# Quit Kenglit and remove every known .app copy (install + build products).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOME_APPS="${HOME}/Applications"

echo "==> Stopping Kenglit (if running)"
pkill -x Kenglit 2>/dev/null || true
sleep 0.3

paths=(
  "${HOME_APPS}/Kenglit.app"
  "/Applications/Kenglit.app"
  "${ROOT}/dist/Kenglit.app"
)

# Worktree build products (Spotlight also indexes these)
while IFS= read -r p; do
  paths+=("$p")
done < <(find "${ROOT}/.worktrees" -type d -name 'Kenglit.app' 2>/dev/null || true)

removed=0
for p in "${paths[@]}"; do
  if [[ -d "$p" ]]; then
    echo "  trash: $p"
    # Prefer Finder Trash when available (recoverable).
    if osascript -e "tell application \"Finder\" to delete (POSIX file \"$p\" as alias)" >/dev/null 2>&1; then
      removed=$((removed + 1))
    else
      # Fallback: move under /tmp (dcg-safe literal tmp path)
      stamp="$(date +%Y%m%d%H%M%S)"
      dest="/tmp/kenglit-uninstall-${stamp}-$(basename "$(dirname "$p")")-Kenglit.app"
      mv "$p" "$dest"
      echo "  moved: $dest"
      removed=$((removed + 1))
    fi
  fi
done

# Drop Launch Services registration for stale copies when possible
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREG" ]]; then
  "$LSREG" -u "${HOME_APPS}/Kenglit.app" 2>/dev/null || true
fi

echo "==> Uninstall done (${removed} app bundle(s) removed)"
mdfind 'kMDItemCFBundleIdentifier == "dev.finn.kenglit"' 2>/dev/null | sed 's/^/  still-indexed: /' || true
