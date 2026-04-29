#!/usr/bin/env bash
# Orchestrator. Runs each install step in order. Honours $DRY_RUN from caller.

set -euo pipefail

: "${NW_OMARCHY_PATH:?must be set by caller}"
: "${NW_OMARCHY_STATE:?must be set by caller}"
DRY_RUN="${DRY_RUN:-1}"

step() {
    local name="$1"
    echo
    echo "──────── ${name} ────────"
    bash "$NW_OMARCHY_PATH/install/${name}.sh"
}

step preflight
step packages
step xlibre
step session
step sddm-picker
step config
step themed
step gestures
step alacritty

echo
echo "==> nw-omarchy: install pipeline complete"
if [ "$DRY_RUN" = "1" ]; then
    echo "==> this was a dry run. Re-run with --apply to commit changes."
else
    echo "==> manifest: $NW_OMARCHY_STATE/manifest.tsv"
    echo "==> log out and pick 'nw-bspwm' from the SDDM session menu on next login."
fi
