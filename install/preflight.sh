#!/usr/bin/env bash
# Sanity checks. No state changes.

set -euo pipefail

fail() { echo "preflight FAIL: $*" >&2; exit 1; }
ok()   { echo "preflight ok:  $*"; }

# Arch / pacman
command -v pacman >/dev/null || fail "pacman not found — this is Arch-only"
ok "pacman present"

# Omarchy installed
[ -d /home/"$USER"/.local/share/omarchy ] || fail "Omarchy not found at ~/.local/share/omarchy"
ok "omarchy present at ~/.local/share/omarchy"

# Not currently in the bspwm session (would clobber its own config files)
if [ "${XDG_SESSION_DESKTOP:-}" = "nw-bspwm" ]; then
    fail "you're currently logged into the nw-bspwm session — log into Hyprland first"
fi
ok "not currently in nw-bspwm session"

# AUR helper available (for FT-Labs picom + xlibre)
AUR_HELPER=""
for h in yay paru; do
    if command -v "$h" >/dev/null; then
        AUR_HELPER="$h"
        break
    fi
done
[ -n "$AUR_HELPER" ] || fail "need an AUR helper (yay or paru) on PATH"
ok "AUR helper: $AUR_HELPER"

# Sudo without password is nicer but not required
if sudo -n true 2>/dev/null; then
    ok "passwordless sudo (smoother)"
else
    echo "preflight note: sudo will prompt for password during install"
fi

# Home writable + state-dir parent writable (state dir itself is created lazily)
[ -w "$HOME" ] || fail "\$HOME not writable"
state_parent="$(dirname "$NW_OMARCHY_STATE")"
mkdir -p "$state_parent"
[ -w "$state_parent" ] || fail "state dir parent not writable: $state_parent"
ok "state dir parent writable: $state_parent"

echo "preflight: all checks passed"
