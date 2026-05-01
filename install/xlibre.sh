#!/usr/bin/env bash
# Swap xorg-server → XLibre as part of the regular install pipeline.
#
# Pre-1.0 stance: install.sh is the single canonical path to the latest
# nw-omarchy state. No "migration" tool is needed because we don't
# promise upgrade-compat across versions yet — every install starts
# from a known-good state. Post-1.0 we'll add real migrations.
#
# Idempotent: re-running on a system already on XLibre is a no-op.
# Pipeline:
#   1. Trust the XLibre signing key (skip if already trusted)
#   2. Add the [xlibre] repo to /etc/pacman.conf (skip if present)
#   3. Compute swap set from currently-installed xorg/xf86 packages
#   4. pacman -S the xlibre equivalents in one transaction (provides/replaces
#      handle the xorg-server removal natively — no manual -R needed)

set -euo pipefail

: "${DRY_RUN:?must be set by caller (install/all.sh)}"

XLIBRE_KEY=73580DE2EDDFA6D6
XLIBRE_REPO_URL='https://x11libre.net/repo/arch_based/x86_64'
PACMAN_CONF=/etc/pacman.conf

say() { printf '%s\n' "$*"; }
run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] '; printf '%q ' "$@"; printf '\n'
    else
        printf '+ '; printf '%q ' "$@"; printf '\n'
        "$@"
    fi
}

# ── preflight ────────────────────────────────────────────────────────
command -v pacman >/dev/null || { say "ERROR: pacman not found (Arch only)"; exit 1; }

gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 || true)
[ -n "$gpu" ] && say "GPU: $gpu"

if echo "$gpu" | grep -qi nvidia; then
    if pacman -Qq nvidia >/dev/null 2>&1 || pacman -Qq nvidia-dkms >/dev/null 2>&1; then
        say "NOTE: proprietary Nvidia driver detected."
        say "      XLibre >=25.0.0.16 auto-handles the ABI mismatch internally."
        say "      Older releases need Option \"IgnoreABI\" \"1\" in xorg.conf."
    fi
fi

# ── already-migrated short-circuit ───────────────────────────────────
# `pacman -Q xorg-server` returns success even when xlibre-xserver is
# the actual installed package, because xlibre-xserver declares
# provides=('xorg-server' ...) and pacman matches that. Match the
# local package list literally to avoid the false positive.
pkg_installed() { pacman -Q 2>/dev/null | awk -v p="$1" '$1==p {f=1} END{exit !f}'; }
have_xlibre=0; have_xorg=0
pkg_installed xlibre-xserver && have_xlibre=1
pkg_installed xorg-server    && have_xorg=1

if [ "$have_xlibre" = 1 ] && [ "$have_xorg" = 0 ]; then
    say "xlibre: already on XLibre — nothing to do."
    exit 0
fi

# ── repo + key trust ─────────────────────────────────────────────────
if sudo pacman-key --list-keys "$XLIBRE_KEY" >/dev/null 2>&1; then
    say "✓ XLibre signing key already trusted"
else
    say "→ trusting XLibre signing key $XLIBRE_KEY"
    run sudo pacman-key --recv-keys "$XLIBRE_KEY"
    run sudo pacman-key --lsign-key "$XLIBRE_KEY"
fi

if grep -q '^\[xlibre\]' "$PACMAN_CONF"; then
    say "✓ [xlibre] repo already in $PACMAN_CONF"
else
    say "→ adding [xlibre] repo to $PACMAN_CONF"
    if [ "$DRY_RUN" != "1" ]; then
        printf '\n[xlibre]\nServer = %s\n' "$XLIBRE_REPO_URL" | sudo tee -a "$PACMAN_CONF" >/dev/null
    else
        say "[dry] append [xlibre] / Server=$XLIBRE_REPO_URL to $PACMAN_CONF"
    fi
fi

run sudo pacman -Sy

# ── compute swap set ─────────────────────────────────────────────────
declare -a to_install=()
[ "$have_xorg" = 1 ] && to_install+=(xlibre-xserver xlibre-xserver-common)
while read -r p; do
    case "$p" in
        xf86-input-*)        to_install+=("xlibre-input-${p#xf86-input-}") ;;
        xf86-video-*)        to_install+=("xlibre-video-${p#xf86-video-}") ;;
        xorg-server-xephyr)  to_install+=(xlibre-xserver-xephyr) ;;
        xorg-server-xnest)   to_install+=(xlibre-xserver-xnest) ;;
        xorg-server-xvfb)    to_install+=(xlibre-xserver-xvfb) ;;
        xorg-server-devel)   to_install+=(xlibre-xserver-devel) ;;
    esac
done < <(pacman -Qq 2>/dev/null)

if [ "${#to_install[@]}" = 0 ]; then
    say "xlibre: nothing to swap (no xorg/xf86 packages installed)"
    exit 0
fi

mapfile -t to_install < <(printf '%s\n' "${to_install[@]}" | awk '!seen[$0]++')

say "→ swap set: ${to_install[*]}"
run sudo pacman -S --needed --noconfirm "${to_install[@]}"

# ── verify ───────────────────────────────────────────────────────────
if [ "$DRY_RUN" != "1" ]; then
    if pkg_installed xlibre-xserver && ! pkg_installed xorg-server; then
        say "✓ on XLibre — reboot recommended"
    else
        say "✗ verification failed: xorg-server still present after swap"; exit 1
    fi
fi
