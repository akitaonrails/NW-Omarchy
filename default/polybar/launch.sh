#!/usr/bin/env bash
# nw-omarchy default polybar launcher. The user's ~/.config/polybar/launch.sh
# shim execs this script.

set -euo pipefail

# Ensure polybar inherits a PATH that includes both bin dirs, so its click
# handlers (sh -c …) can find nw-omarchy-launch-* / nw-omarchy-menu / etc.
# Otherwise: if launch.sh is called from a shell that hasn't set this up
# (e.g. our refresh helpers or a manual reload), polybar gets a stripped
# PATH and clicks silently no-op.
export PATH="$HOME/.local/share/nw-omarchy/bin:$HOME/.local/share/omarchy/bin:$PATH"

CONFIG="${1:-$(dirname "$(readlink -f "$0")")/config.ini}"

pkill -x polybar >/dev/null 2>&1 || true
while pgrep -x polybar >/dev/null; do sleep 0.1; done

if command -v polybar >/dev/null; then
    if [ "$(polybar --list-monitors | wc -l)" -ge 1 ]; then
        for m in $(polybar --list-monitors | cut -d':' -f1); do
            MONITOR="$m" polybar --reload main --config="$CONFIG" >/dev/null 2>&1 &
        done
    else
        polybar --reload main --config="$CONFIG" >/dev/null 2>&1 &
    fi
fi
