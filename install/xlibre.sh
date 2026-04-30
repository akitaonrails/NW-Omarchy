#!/usr/bin/env bash
# Diagnostic stub. The actual XLibre migration is opt-in and lives in
# bin/nw-omarchy-xlibre-migrate — see docs/xlibre.md for the full story.
#
# Replacing the X server is riskier than anything else in this install
# pipeline, so it's intentionally NOT auto-run. This step just reports
# the current state of the X server choice.

set -euo pipefail

if pacman -Qq xlibre-xserver >/dev/null 2>&1; then
    echo "xlibre: xlibre-xserver installed — your bspwm session will use XLibre."
elif pacman -Qq xlibre-xserver-git >/dev/null 2>&1; then
    echo "xlibre: xlibre-xserver-git (AUR) installed — your bspwm session will use XLibre."
else
    echo "xlibre: not installed (default). bspwm session uses xorg-server."
    echo "        To switch to XLibre, run:"
    echo "          nw-omarchy-xlibre-migrate            # preview"
    echo "          nw-omarchy-xlibre-migrate --apply    # commit"
    echo "        See docs/xlibre.md for the full rationale and revert recipe."
fi
