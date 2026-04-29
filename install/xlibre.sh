#!/usr/bin/env bash
# XLibre is intentionally NOT installed by default. This step is just a
# diagnostic / informational note. See packages/nw-omarchy.packages and
# docs/README.md for the rationale.

set -euo pipefail

if pacman -Qq xlibre-xserver-git >/dev/null 2>&1; then
    echo "xlibre: xlibre-xserver-git installed (manually) — bspwm session will use it."
    if pacman -Qq hyprland >/dev/null 2>&1; then
        echo "xlibre: WARNING — hyprland is also installed. Sessions may conflict."
    fi
else
    echo "xlibre: skipped (not in default package list)."
    echo "        Reason: xlibre-xserver-common-git Conflicts=xorg-server-common"
    echo "        without Provides=, so installing it would force-remove"
    echo "        xorg-xwayland → hyprland."
    echo "        bspwm runs fine on stock Xorg. See docs/README.md."
fi
