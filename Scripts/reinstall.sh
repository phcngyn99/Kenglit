#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./Scripts/uninstall-all.sh
./Scripts/install.sh
open "/Applications/Kenglit.app"
sleep 0.8
pgrep -x Kenglit >/dev/null || { echo "warning: Kenglit did not stay running" >&2; exit 1; }
