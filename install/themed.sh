#!/usr/bin/env bash
# Symlink our theme templates into omarchy's user-template dir.
#
# Mechanism (all owned by omarchy — we just plug into it):
#   - Templates go in   ~/.config/omarchy/themed/<name>.tpl
#   - On every `omarchy-theme-set <name>` (or omarchy-theme-refresh), the script
#     omarchy-theme-set-templates reads the next theme's colors.toml and runs
#     `sed` substitutions ({{ key }}, {{ key_strip }}, {{ key_rgb }}) over EVERY
#     .tpl in that dir. Output lands in ~/.config/omarchy/current/theme/<name>.
#   - Our bspwmrc / rofi / polybar configs source/include those rendered files,
#     so they re-paint to match whatever theme omarchy is on, with no extra
#     wiring on theme change.
#
# We track each symlink in the manifest so uninstall removes them. After the
# symlinks are in place we run `omarchy-theme-refresh` once so the rendered
# files exist for the FIRST bspwm session (otherwise the source/import in
# bspwmrc/config.rasi/config.ini hits a missing path).

set -euo pipefail

: "${NW_OMARCHY_PATH:?}"
: "${NW_OMARCHY_STATE:?}"
: "${DRY_RUN:?}"

THEMED_SRC="$NW_OMARCHY_PATH/default/themed"
THEMED_DST="$HOME/.config/omarchy/themed"

[ -d "$THEMED_SRC" ] || { echo "themed: $THEMED_SRC missing" >&2; exit 1; }

# omarchy must be installed for this to mean anything. Preflight already
# checks ~/.local/share/omarchy, but ~/.config/omarchy is created lazily.
if [ ! -d "$HOME/.config/omarchy" ]; then
    echo "themed: ~/.config/omarchy doesn't exist — skipping theme integration."
    echo "        (install omarchy and re-run, or this step does nothing.)"
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

# Ensure the user-template dir exists and is tracked so uninstall can rmdir
# if we created it.
if [ ! -d "$THEMED_DST" ]; then
    run mkdir -p "$THEMED_DST"
fi
run nw-omarchy-track record dir "$THEMED_DST"

# Symlink each .tpl into the user template dir. If a non-symlink file with
# the same name already exists, back it up.
shopt -s nullglob
for src in "$THEMED_SRC"/*.tpl; do
    name="$(basename "$src")"
    dst="$THEMED_DST/$name"

    # Already our symlink → just record + skip
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "  up-to-date: $dst"
        run nw-omarchy-track record symlink "$dst"
        continue
    fi

    backup="-"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        ts="$(date +%Y%m%d-%H%M%S)"
        sanitized="${dst#/}"; sanitized="${sanitized//\//_}"
        backup="$NW_OMARCHY_STATE/backups/${sanitized}.${ts}"
        mkdir -p "$NW_OMARCHY_STATE/backups"
        run mv "$dst" "$backup"
    fi

    run ln -s "$src" "$dst"
    run nw-omarchy-track record symlink "$dst" "$backup"
done
shopt -u nullglob

# Trigger an immediate render so the rendered files exist in
# ~/.config/omarchy/current/theme/ before bspwm tries to source/import them.
# omarchy-theme-refresh = re-run omarchy-theme-set for the current theme.
if command -v omarchy-theme-refresh >/dev/null; then
    if [ -f "$HOME/.config/omarchy/current/theme.name" ]; then
        echo "==> rendering templates against current theme"
        run omarchy-theme-refresh
    else
        echo "themed: no current theme set — first run of omarchy-theme-set"
        echo "        will render our templates."
    fi
else
    echo "themed: omarchy-theme-refresh not on PATH — skipping immediate render."
    echo "        Templates will render on next theme switch."
fi

# Wire ~/.config/dunst/dunstrc → the rendered themed dunstrc. dunst doesn't
# support config @includes, so the symlink is the only way for the user's
# default config path to resolve to our themed file. nw-omarchy-dunst-watch
# (autostarted from bspwmrc) picks up theme changes by watching the parent
# dir and signalling dunst.
DUNST_DIR="$HOME/.config/dunst"
DUNST_LINK="$DUNST_DIR/dunstrc"
DUNST_TARGET="$HOME/.config/omarchy/current/theme/dunstrc"

if [ ! -d "$DUNST_DIR" ]; then
    run mkdir -p "$DUNST_DIR"
fi
run nw-omarchy-track record dir "$DUNST_DIR"

if [ -L "$DUNST_LINK" ] && [ "$(readlink "$DUNST_LINK")" = "$DUNST_TARGET" ]; then
    echo "  up-to-date: $DUNST_LINK"
    run nw-omarchy-track record symlink "$DUNST_LINK"
else
    backup="-"
    if [ -e "$DUNST_LINK" ] || [ -L "$DUNST_LINK" ]; then
        ts="$(date +%Y%m%d-%H%M%S)"
        sanitized="${DUNST_LINK#/}"; sanitized="${sanitized//\//_}"
        backup="$NW_OMARCHY_STATE/backups/${sanitized}.${ts}"
        mkdir -p "$NW_OMARCHY_STATE/backups"
        run mv "$DUNST_LINK" "$backup"
    fi
    run ln -s "$DUNST_TARGET" "$DUNST_LINK"
    run nw-omarchy-track record symlink "$DUNST_LINK" "$backup"
fi

# Restart dunst so it picks up the new config now (rather than waiting for
# the next session or theme change).
if [ "$DRY_RUN" = "0" ] && command -v dunst >/dev/null 2>&1 && pgrep -x dunst >/dev/null; then
    nw-omarchy-restart-dunst >/dev/null 2>&1 || true
fi

echo "themed: done."
