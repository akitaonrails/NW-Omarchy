#!/usr/bin/env bash
# Drop the SDDM session entry so 'nw-bspwm' shows up in the session selector.
# We never touch /etc/sddm.conf — only add a file under /usr/share/xsessions/.

set -euo pipefail

: "${NW_OMARCHY_PATH:?}"
: "${NW_OMARCHY_STATE:?}"
: "${DRY_RUN:?}"

SRC="$NW_OMARCHY_PATH/default/xsessions/nw-bspwm.desktop"
DST="/usr/share/xsessions/nw-bspwm.desktop"

[ -f "$SRC" ] || { echo "missing source $SRC" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] '; printf '%q ' "$@"; printf '\n'
    else
        printf '+ '; printf '%q ' "$@"; printf '\n'
        "$@"
    fi
}

# Idempotent
if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
    echo "session: $DST already up to date"
    run nw-omarchy-track record xsession "$DST"
    exit 0
fi

# Back up if a non-ours file already lives at DST
BACKUP="-"
if [ -e "$DST" ]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    BACKUP="$NW_OMARCHY_STATE/backups/usr_share_xsessions_nw-bspwm.desktop.$ts"
    run sudo cp -a "$DST" "$BACKUP"
fi

run sudo install -m 0644 "$SRC" "$DST"
run nw-omarchy-track record xsession "$DST" "$BACKUP"

echo "session: registered $DST"
