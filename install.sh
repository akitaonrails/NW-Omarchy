#!/usr/bin/env bash
# nw-omarchy bootstrap entry point. Thin wrapper around bin/nw-omarchy-install.
# Usage:
#   ./install.sh             # dry run (default)
#   ./install.sh --apply     # do it for real

set -euo pipefail

NW_OMARCHY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NW_OMARCHY_PATH

exec "$NW_OMARCHY_PATH/bin/nw-omarchy-install" "$@"
