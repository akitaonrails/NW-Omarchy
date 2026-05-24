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
#   3. Compute swap set from currently-installed xorg/xf86 packages, dropping
#      any target with no build in the repo (a single missing target would
#      otherwise abort the whole transaction)
#   4. Install the xlibre equivalents. xlibre-xserver declares conflicts=
#      AND provides= for xorg-server, but `pacman --noconfirm` answers the
#      "Remove xorg-server? [y/N]" conflict prompt with the default *No* and
#      aborts — so we feed `yes` to a non-noconfirm pacman to resolve the
#      conflict atomically (verified against the live xlibre repo).

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

# ── compute install set ──────────────────────────────────────────────
declare -a to_install=(xlibre-xserver xlibre-xserver-common)
if [ "$have_xorg" = 1 ]; then
    say "→ swapping existing xorg-server → XLibre"
else
    # Omarchy is Wayland-first and may ship no xorg-server at all (only
    # xorg-xwayland). nw-omarchy's bspwm session still needs a real X server,
    # so install XLibre fresh rather than no-op'ing. The libinput driver plus
    # the modesetting DDX bundled inside xlibre-xserver cover common hardware.
    say "→ no xorg-server present — installing XLibre fresh (bspwm needs an X server)"
    to_install+=(xlibre-input-libinput)
fi

# Map any installed xf86 drivers to their xlibre equivalents.
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

mapfile -t to_install < <(printf '%s\n' "${to_install[@]}" | awk '!seen[$0]++')

# Dry-run can't validate against the repo (we didn't really `pacman -Sy`), so
# just preview the computed set and the transaction, then stop.
if [ "$DRY_RUN" = "1" ]; then
    say "[dry] computed install set: ${to_install[*]}"
    run sudo pacman -S --needed --noconfirm "${to_install[@]}"
    say "[dry] (target validation + xf86 cleanup happen only on --apply)"
    exit 0
fi

# ── validate every target against the synced repo ─────────────────────
# A single nonexistent target (e.g. an exotic xf86 driver with no xlibre
# build) makes `pacman -S a b c` abort the WHOLE transaction with
# "target not found" — leaving xorg-server un-swapped. That's the failure
# reported in issue #1. Partition instead: install what exists, and for a
# driver with no xlibre build, remove the now-ABI-incompatible xf86 original
# so it can't block the server swap (the bundled modesetting DDX covers it).
declare -a available=() to_remove=()
for t in "${to_install[@]}"; do
    if pacman -Si "$t" >/dev/null 2>&1; then
        available+=("$t")
    else
        say "⚠ no repo package '$t'"
        case "$t" in
            xlibre-input-*) old="xf86-input-${t#xlibre-input-}" ;;
            xlibre-video-*) old="xf86-video-${t#xlibre-video-}" ;;
            *)              old="" ;;
        esac
        if [ -n "$old" ] && pkg_installed "$old"; then
            say "  → will remove ABI-incompatible $old (xlibre's modesetting DDX covers it)"
            to_remove+=("$old")
        fi
    fi
done

if [ "${#available[@]}" = 0 ]; then
    say "✗ no installable XLibre targets found in the repo — aborting"; exit 1
fi

# Remove ABI-orphaned xf86 drivers first. They have no xlibre build and are
# incompatible with the new server ABI; leaving them installed makes the
# `-S` below fail dependency resolution. -Rdd: they're leaf packages, but
# skip dep checks to be safe against the in-flight server swap.
if [ "${#to_remove[@]}" -gt 0 ]; then
    say "→ removing ABI-orphaned xf86 drivers: ${to_remove[*]}"
    run sudo pacman -Rdd --noconfirm "${to_remove[@]}"
fi

say "→ install set: ${available[*]}"
# NOT --noconfirm: that answers the "Remove xorg-server?" conflict prompt with
# the default No and aborts. Feed `yes` to a confirming pacman so the conflict
# (xlibre-xserver vs xorg-server, etc.) is resolved atomically in one txn.
# `yes` is killed by SIGPIPE when pacman exits, so read pacman's real status
# from PIPESTATUS rather than letting pipefail surface yes's 141.
printf '+ yes | '; printf '%q ' sudo pacman -S --needed "${available[@]}"; printf '\n'
set +o pipefail
yes 2>/dev/null | sudo pacman -S --needed "${available[@]}"
rc=${PIPESTATUS[1]}
set -o pipefail
if [ "$rc" -ne 0 ]; then
    say "✗ XLibre install transaction failed (pacman exit $rc)"
    exit 1
fi

# ── verify ───────────────────────────────────────────────────────────
# xlibre-xserver must be present and xorg-server gone (its conflicts= forced
# removal). On a fresh install xorg-server was never there — also fine.
if pkg_installed xlibre-xserver && ! pkg_installed xorg-server; then
    say "✓ on XLibre — reboot recommended"
else
    say "✗ verification failed: xorg-server still present after swap"; exit 1
fi
