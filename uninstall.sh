#!/usr/bin/env bash
# nw-omarchy uninstall entry point. Reads the manifest and undoes everything.
# Usage:
#   ./uninstall.sh           # dry run (default)
#   ./uninstall.sh --apply   # actually undo

set -euo pipefail

NW_OMARCHY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NW_OMARCHY_PATH

exec "$NW_OMARCHY_PATH/bin/nw-omarchy-uninstall" "$@"
