#!/usr/bin/env bash
# Lay down user-side shim configs in ~/.config/{bspwm,sxhkd,picom,polybar,rofi}.
# Each shim sources/includes the matching default in ~/.local/share/nw-omarchy/default/*
# so the user can layer overrides on top by editing the shim — same pattern Omarchy uses.
#
# If a target file already exists, we back it up to $NW_OMARCHY_STATE/backups/ first.
# Each shim is recorded in the manifest as `file` so uninstall removes it cleanly.

set -euo pipefail

: "${NW_OMARCHY_PATH:?}"
: "${NW_OMARCHY_STATE:?}"
: "${DRY_RUN:?}"

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] '; printf '%q ' "$@"; printf '\n'
    else
        printf '+ '; printf '%q ' "$@"; printf '\n'
        "$@"
    fi
}

# Drop a shim file. Args: <abs-target-path> <heredoc-content-via-stdin>
#   - Backs up existing non-shim content
#   - Skips if the file already matches what we'd write (idempotent)
#   - Records as `file` in the manifest
write_shim() {
    local target="$1"
    local content
    content="$(cat)"   # read from stdin

    mkdir -p "$(dirname "$target")"

    # Idempotent: if file matches expected content, just record + return.
    if [ -f "$target" ] && [ "$(cat "$target")" = "$content" ]; then
        run nw-omarchy-track record file "$target"
        echo "  up-to-date: $target"
        return
    fi

    # Back up displaced content (anything we didn't write).
    local backup="-"
    if [ -e "$target" ] || [ -L "$target" ]; then
        local ts
        ts="$(date +%Y%m%d-%H%M%S)"
        local sanitized="${target#/}"
        sanitized="${sanitized//\//_}"
        backup="$NW_OMARCHY_STATE/backups/${sanitized}.${ts}"
        run cp -a "$target" "$backup"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] write %s (%d bytes)\n' "$target" "${#content}"
    else
        printf '+ write %s (%d bytes)\n' "$target" "${#content}"
        mkdir -p "$(dirname "$target")"
        printf '%s\n' "$content" > "$target"
    fi

    run nw-omarchy-track record file "$target" "$backup"
}

DEFAULT="$NW_OMARCHY_PATH/default"

# Screenshots go into $XDG_PICTURES_DIR/Screenshots (or ~/Pictures/Screenshots
# if XDG_PICTURES_DIR isn't set). Pre-create so the directory exists from
# day one, instead of springing into existence on the user's first Print.
echo "==> screenshot directory"
[ -f ~/.config/user-dirs.dirs ] && . ~/.config/user-dirs.dirs
SHOTS="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
if [ -d "$SHOTS" ]; then
    echo "  already exists: $SHOTS"
else
    run mkdir -p "$SHOTS"
fi

echo "==> bspwm shim"
write_shim "$HOME/.config/bspwm/bspwmrc" <<EOF
#!/bin/sh
# bspwm user config — managed by nw-omarchy.
# Defaults live at: $DEFAULT/bspwm/bspwmrc (sourced below).
# Add user overrides AFTER the source line. They will run last and win on conflict.

. "$DEFAULT/bspwm/bspwmrc"

# ── user overrides below ─────────────────────────────────────────────
EOF
# bspwmrc is executed by bspwm, so it must be executable.
if [ "$DRY_RUN" = "0" ]; then
    chmod +x "$HOME/.config/bspwm/bspwmrc"
fi

echo "==> sxhkd shim"
# sxhkd has no native include. The bspwmrc launches sxhkd with both the default
# and the user file via `sxhkd -c <default> -c <user>`, where the later file
# overrides earlier ones on conflict.
write_shim "$HOME/.config/sxhkd/sxhkdrc" <<EOF
# sxhkd user bindings — managed by nw-omarchy.
# Defaults live at: $DEFAULT/sxhkd/sxhkdrc (loaded before this file by bspwmrc).
# Add user overrides below. Same key on the same modifier mask wins here.

# ── user bindings below ──────────────────────────────────────────────
EOF

echo "==> picom shim"
write_shim "$HOME/.config/picom/picom.conf" <<EOF
# picom user config — managed by nw-omarchy.
# Defaults live at: $DEFAULT/picom/picom.conf (included below).
# Add user overrides AFTER the @include. picom honours later definitions.

@include "$DEFAULT/picom/picom.conf"

# ── user overrides below ─────────────────────────────────────────────
EOF

echo "==> polybar shim"
# polybar's INI parser does not support file include. We make the user's launch
# script a shim that calls the default launch script, which uses the default
# config.ini. Customising means editing the launch.sh shim or the config.ini
# (and at that point you should copy the default config.ini and edit your copy).
write_shim "$HOME/.config/polybar/launch.sh" <<EOF
#!/usr/bin/env bash
# polybar launcher — managed by nw-omarchy.
# Default launcher: $DEFAULT/polybar/launch.sh
# To customise: copy $DEFAULT/polybar/config.ini to ~/.config/polybar/config.ini,
# then edit this script to point polybar at your copy.

exec "$DEFAULT/polybar/launch.sh" "\$@"
EOF
if [ "$DRY_RUN" = "0" ]; then
    chmod +x "$HOME/.config/polybar/launch.sh"
fi

echo "==> rofi shim"
write_shim "$HOME/.config/rofi/config.rasi" <<EOF
// rofi user config — managed by nw-omarchy.
// Defaults live at: $DEFAULT/rofi/config.rasi (imported below).
// Add user overrides AFTER the @import.

@import "$DEFAULT/rofi/config.rasi"

/* ── user overrides below ──────────────────────────────────────── */
EOF

echo "==> done laying down shims"
