#!/usr/bin/env bash
# Full clean reinstall: uninstall all copies, pack, install one, launch.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./Scripts/uninstall-all.sh
./Scripts/install.sh
open "${HOME}/Applications/Kenglit.app"
sleep 0.8
if pgrep -x Kenglit >/dev/null; then
  echo "Running: Kenglit"
else
  echo "warning: Kenglit did not stay running" >&2
  exit 1
fi
