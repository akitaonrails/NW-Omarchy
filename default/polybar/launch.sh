#!/usr/bin/env bash
# nw-omarchy default polybar launcher. The user's ~/.config/polybar/launch.sh
# shim execs this script.

set -euo pipefail

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
