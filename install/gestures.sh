#!/usr/bin/env bash
# Symlink ~/.config/libinput-gestures.conf to our default. libinput-gestures
# has no native include directive, so we can't ship a layered shim — users
# who want to diverge replace the symlink with their own copy.
#
# Tracked as a `symlink` action so uninstall removes it (and restores any
# prior file via the backup column).

set -euo pipefail

: "${NW_OMARCHY_PATH:?}"
: "${NW_OMARCHY_STATE:?}"
: "${DRY_RUN:?}"

SRC="$NW_OMARCHY_PATH/default/libinput-gestures/libinput-gestures.conf"
DST="$HOME/.config/libinput-gestures.conf"

[ -f "$SRC" ] || { echo "gestures: missing $SRC" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] '; printf '%q ' "$@"; printf '\n'
    else
        printf '+ '; printf '%q ' "$@"; printf '\n'
        "$@"
    fi
}

mkdir -p "$(dirname "$DST")"

# Already our symlink → just record + skip
if [ -L "$DST" ] && [ "$(readlink "$DST")" = "$SRC" ]; then
    echo "  up-to-date: $DST"
    run nw-omarchy-track record symlink "$DST"
    exit 0
fi

backup="-"
if [ -e "$DST" ] || [ -L "$DST" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    sanitized="${DST#/}"; sanitized="${sanitized//\//_}"
    backup="$NW_OMARCHY_STATE/backups/${sanitized}.${ts}"
    mkdir -p "$NW_OMARCHY_STATE/backups"
    run mv "$DST" "$backup"
fi

run ln -s "$SRC" "$DST"
run nw-omarchy-track record symlink "$DST" "$backup"

# Soft-warn if the user isn't in the input group — libinput-gestures will
# refuse to read /dev/input/event* without it.
if ! groups | grep -qw input; then
    echo
    echo "gestures: ⚠  user '$USER' is NOT in the 'input' group."
    echo "          libinput-gestures needs read access to /dev/input/event*."
    echo "          Add yourself and re-login:"
    echo "              sudo gpasswd -a \"\$USER\" input"
fi

echo "gestures: done."
