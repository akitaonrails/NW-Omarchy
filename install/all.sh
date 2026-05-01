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
step session
step sddm-picker
step config
step themed
step gestures
step alacritty
# xlibre last: it's the only step that does a system-wide pacman-managed
# swap (xorg-server → xlibre-xserver). Run it after everything else is
# laid down so a failure here doesn't leave the bspwm session half-set-up.
step xlibre

echo
echo "==> nw-omarchy: install pipeline complete"
if [ "$DRY_RUN" = "1" ]; then
    echo "==> this was a dry run. Re-run with --apply to commit changes."
else
    echo "==> manifest: $NW_OMARCHY_STATE/manifest.tsv"
    echo "==> log out and pick 'nw-bspwm' from the SDDM session menu on next login."
fi
