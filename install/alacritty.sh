#!/usr/bin/env bash
# Append our alacritty overrides path to the user's alacritty.toml general.import.
# We do NOT replace or rewrite the user's file — just add our path to the
# import list so alacritty's later-wins merge gives us our keybindings on top.
#
# Single-line import form is what omarchy ships:
#     general.import = [ "~/.config/omarchy/current/theme/alacritty.toml" ]
# We turn that into:
#     general.import = [ "~/.config/omarchy/current/theme/alacritty.toml", "<our path>" ]
#
# Idempotent: once the path string is in the file we skip. If the file's
# import isn't in the single-line form we recognise, we restore the backup
# and print instructions instead of guessing.

set -euo pipefail

: "${NW_OMARCHY_PATH:?}"
: "${NW_OMARCHY_STATE:?}"
: "${DRY_RUN:?}"

ALACRITTY_CFG="$HOME/.config/alacritty/alacritty.toml"
NW_KEYBINDS="$NW_OMARCHY_PATH/default/alacritty/keybindings.toml"

[ -f "$NW_KEYBINDS" ] || { echo "alacritty: missing $NW_KEYBINDS" >&2; exit 1; }

if [ ! -f "$ALACRITTY_CFG" ]; then
    echo "alacritty: $ALACRITTY_CFG doesn't exist — skipping (alacritty not configured)."
    exit 0
fi

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] '; printf '%q ' "$@"; printf '\n'
    else
        printf '+ '; printf '%q ' "$@"; printf '\n'
        "$@"
    fi
}

# Idempotent: if our path is already in the file, just record + return.
if grep -qF "$NW_KEYBINDS" "$ALACRITTY_CFG"; then
    echo "  up-to-date: $ALACRITTY_CFG"
    run nw-omarchy-track record file "$ALACRITTY_CFG"
    exit 0
fi

# Backup before editing — uninstall replays this to restore the original.
ts="$(date +%Y%m%d-%H%M%S)"
sanitized="${ALACRITTY_CFG#/}"; sanitized="${sanitized//\//_}"
BACKUP="$NW_OMARCHY_STATE/backups/${sanitized}.${ts}"
mkdir -p "$NW_OMARCHY_STATE/backups"
run cp -a "$ALACRITTY_CFG" "$BACKUP"

# Single-line import detection: `general.import = [ ... ]` on one line.
if grep -qE '^general\.import[[:space:]]*=[[:space:]]*\[[^][]*\][[:space:]]*$' "$ALACRITTY_CFG"; then
    # Insert our path before the closing `]` of the array, separated by `, `.
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] sed -i -E ...append %q to general.import in %q\n' "$NW_KEYBINDS" "$ALACRITTY_CFG"
    else
        sed -i -E "s|^(general\.import[[:space:]]*=[[:space:]]*\[[^][]*)\][[:space:]]*$|\1, \"$NW_KEYBINDS\" ]|" "$ALACRITTY_CFG"
    fi
    run nw-omarchy-track record file "$ALACRITTY_CFG" "$BACKUP"
    echo "alacritty: appended override path to general.import."
    exit 0
fi

# Fallback: import isn't in a form we recognise. Don't munge — restore and instruct.
echo "alacritty: general.import in $ALACRITTY_CFG isn't on a single line we can patch."
echo "           Add this entry to your general.import array manually:"
echo "             \"$NW_KEYBINDS\""
echo "           (Backup at $BACKUP if you want to compare.)"
# The backup was made before we did anything destructive, so leaving the
# file untouched here is safe — no need to restore.
run nw-omarchy-track record file "$BACKUP"   # at least track the backup so uninstall cleans it
exit 0
