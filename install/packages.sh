#!/usr/bin/env bash
# Install packages from packages/nw-omarchy.packages.
# - Records each package as `pkg` (we installed it) or `pkg-skip` (was already there)
#   so uninstall removes only what we added.
# - Routes (aur)-flagged packages through the detected AUR helper.

set -euo pipefail

: "${NW_OMARCHY_PATH:?}"
: "${DRY_RUN:?}"

PKGFILE="$NW_OMARCHY_PATH/packages/nw-omarchy.packages"
[ -f "$PKGFILE" ] || { echo "missing $PKGFILE"; exit 1; }

# Detect AUR helper (already validated by preflight, but stay defensive)
AUR_HELPER=""
for h in yay paru; do
    command -v "$h" >/dev/null && { AUR_HELPER="$h"; break; }
done

# Parse package list. Format per line: <name> [(aur)]   # comment
declare -a REPO_PKGS AUR_PKGS
while IFS= read -r line; do
    line="${line%%#*}"        # strip comment
    line="${line//$'\t'/ }"   # tabs → spaces
    line="$(echo "$line" | xargs)"  # trim
    [ -z "$line" ] && continue

    if [[ "$line" == *"(aur)"* ]]; then
        name="$(echo "${line%%(aur)*}" | xargs)"
        AUR_PKGS+=("$name")
    else
        REPO_PKGS+=("$line")
    fi
done < "$PKGFILE"

echo "repo packages: ${REPO_PKGS[*]:-<none>}"
echo "AUR  packages: ${AUR_PKGS[*]:-<none>}"
echo

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] '; printf '%q ' "$@"; printf '\n'
    else
        printf '+ '; printf '%q ' "$@"; printf '\n'
        "$@"
    fi
}

# Decide for one package whether it goes in the install list.
# Idempotency check order: first the manifest, then pacman -Q. This way
# a re-run after a successful apply doesn't add a duplicate `pkg-skip`
# row next to the existing `pkg` row.
classify_one() {
    local p="$1"
    if nw-omarchy-track has pkg "$p" || nw-omarchy-track has pkg-skip "$p"; then
        echo "  already tracked:   $p"
        return 1   # don't install
    fi
    if pacman -Qq "$p" >/dev/null 2>&1; then
        echo "  pre-existing:      $p (will not remove on uninstall)"
        run nw-omarchy-track record pkg-skip "$p"
        return 1
    fi
    return 0   # install me
}

# Repo packages: batch install (pacman handles deps cleanly).
if [ "${#REPO_PKGS[@]}" -gt 0 ]; then
    echo "==> repo packages"
    repo_to_install=()
    for p in "${REPO_PKGS[@]}"; do
        if classify_one "$p"; then
            repo_to_install+=("$p")
        fi
    done
    if [ "${#repo_to_install[@]}" -gt 0 ]; then
        echo "  installing: ${repo_to_install[*]}"
        run sudo pacman -S --needed --noconfirm "${repo_to_install[@]}"
        for p in "${repo_to_install[@]}"; do
            run nw-omarchy-track record pkg "$p"
        done
    fi
fi

# AUR packages: install ONE AT A TIME. A conflict on package X (e.g. an X server
# fork that conflicts with xorg-server) must not abort the whole batch.
if [ "${#AUR_PKGS[@]}" -gt 0 ]; then
    echo "==> AUR packages"
    [ -n "$AUR_HELPER" ] || { echo "no AUR helper; skipping AUR packages" >&2; exit 1; }
    aur_failed=()
    for p in "${AUR_PKGS[@]}"; do
        classify_one "$p" || continue
        echo "  installing (AUR): $p"
        if [ "$DRY_RUN" = "1" ]; then
            run "$AUR_HELPER" -S --needed --noconfirm "$p"
            run nw-omarchy-track record pkg "$p"
        else
            # Verify after claim. AUR helpers occasionally exit 0 without
            # actually installing (e.g. pacman aborts an earlier txn but yay
            # only reports the build success). Hit by xlibre conflict on
            # 2026-04-29 — picom-ft-labs got "installed" per yay but pacman -Qq
            # said no. Always cross-check with pacman before recording.
            if "$AUR_HELPER" -S --needed --noconfirm "$p" \
                && pacman -Qq "$p" >/dev/null 2>&1; then
                run nw-omarchy-track record pkg "$p"
            else
                aur_failed+=("$p")
                echo "  FAILED: $p (yay status \$? or pacman doesn't see it; continuing)" >&2
            fi
        fi
    done
    if [ "${#aur_failed[@]}" -gt 0 ]; then
        echo
        echo "  ⚠ AUR packages that did not install: ${aur_failed[*]}"
        echo "  (other steps will continue. Re-run install after resolving.)"
    fi
fi
