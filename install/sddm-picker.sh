#!/usr/bin/env bash
# Install the nw-omarchy SDDM theme — a clone of the omarchy theme with a
# session picker added — and switch SDDM to it via /etc/sddm.conf.d/.
#
# Strategy:
#   1. Copy every file from /usr/share/sddm/themes/omarchy/ into
#      /usr/share/sddm/themes/nw-omarchy/ (so we inherit logo.svg etc).
#   2. Override Main.qml + metadata.desktop with our patched copies.
#   3. Drop /etc/sddm.conf.d/20-nw-omarchy.conf with [Theme] Current=nw-omarchy.
#
# Idempotent. Records every file/dir in the manifest so uninstall replays cleanly.
#
# NOTE: this only changes the SDDM greeter theme. If autologin is enabled
# (/etc/sddm.conf.d/autologin.conf with [Autologin] User=...) SDDM will still
# bypass the greeter — disable autologin separately.

set -euo pipefail

: "${NW_OMARCHY_PATH:?}"
: "${NW_OMARCHY_STATE:?}"
: "${DRY_RUN:?}"

OMARCHY_THEME="/usr/share/sddm/themes/omarchy"
OUR_THEME_DIR="/usr/share/sddm/themes/nw-omarchy"
OUR_CONF="/etc/sddm.conf.d/20-nw-omarchy.conf"

SRC_QML="$NW_OMARCHY_PATH/default/sddm-theme/Main.qml"
SRC_META="$NW_OMARCHY_PATH/default/sddm-theme/metadata.desktop"
SRC_CONF="$NW_OMARCHY_PATH/default/sddm-conf/20-nw-omarchy.conf"

[ -d "$OMARCHY_THEME" ] || { echo "sddm-picker: $OMARCHY_THEME missing — is omarchy installed?" >&2; exit 1; }
[ -f "$SRC_QML" ]  || { echo "missing $SRC_QML"  >&2; exit 1; }
[ -f "$SRC_META" ] || { echo "missing $SRC_META" >&2; exit 1; }
[ -f "$SRC_CONF" ] || { echo "missing $SRC_CONF" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry] '; printf '%q ' "$@"; printf '\n'
    else
        printf '+ '; printf '%q ' "$@"; printf '\n'
        "$@"
    fi
}

# Install $1 (source) to $2 (dest) as a system file owned by root, idempotent.
# Records `file $2` in the manifest. No backup tracking — these files live
# inside our own theme dir, which didn't exist before us.
install_theme_file() {
    local src="$1" dst="$2"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        echo "  up-to-date: $dst"
    else
        run sudo install -m 0644 "$src" "$dst"
    fi
    run nw-omarchy-track record file "$dst"
}

echo "==> ensure theme dir exists: $OUR_THEME_DIR"
if [ ! -d "$OUR_THEME_DIR" ]; then
    run sudo mkdir -p "$OUR_THEME_DIR"
fi
# Record dir BEFORE files, so reverse-replay removes files first then rmdir's the dir.
run nw-omarchy-track record dir "$OUR_THEME_DIR"

echo "==> seed theme dir from $OMARCHY_THEME"
shopt -s nullglob
for src in "$OMARCHY_THEME"/*; do
    # Only top-level files. The omarchy theme has no subdirs today; bail loudly
    # if that ever changes so we don't silently miss assets.
    if [ -d "$src" ]; then
        echo "sddm-picker: $src is a directory — theme has unexpected subdirs, aborting" >&2
        exit 1
    fi
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    install_theme_file "$src" "$OUR_THEME_DIR/$name"
done
shopt -u nullglob

echo "==> overlay our patched Main.qml + metadata.desktop"
install_theme_file "$SRC_QML"  "$OUR_THEME_DIR/Main.qml"
install_theme_file "$SRC_META" "$OUR_THEME_DIR/metadata.desktop"

echo "==> drop SDDM conf override: $OUR_CONF"
if [ -f "$OUR_CONF" ] && cmp -s "$SRC_CONF" "$OUR_CONF"; then
    echo "  up-to-date: $OUR_CONF"
    run nw-omarchy-track record file "$OUR_CONF"
else
    BACKUP="-"
    if [ -e "$OUR_CONF" ]; then
        ts="$(date +%Y%m%d-%H%M%S)"
        BACKUP="$NW_OMARCHY_STATE/backups/etc_sddm.conf.d_20-nw-omarchy.conf.$ts"
        mkdir -p "$NW_OMARCHY_STATE/backups"
        run sudo cp -a "$OUR_CONF" "$BACKUP"
    fi
    run sudo install -m 0644 "$SRC_CONF" "$OUR_CONF"
    run nw-omarchy-track record file "$OUR_CONF" "$BACKUP"
fi

echo
echo "sddm-picker: done. The picker takes effect next time SDDM (re)starts the greeter."
echo "             Try:  sudo systemctl restart sddm   (this kills the current X session)"

# Soft-warn if any file in /etc/sddm.conf.d/ declares an autologin user.
# SDDM parses every file in that dir regardless of extension, so a `.disabled`
# rename does NOT stop autologin or its [Theme] Current= from taking effect.
for f in /etc/sddm.conf.d/*; do
    [ -f "$f" ] || continue
    if awk '/^\[Autologin\]/{inauto=1; next} /^\[/{inauto=0} inauto && /^User=.+/{found=1} END{exit !found}' "$f"; then
        echo
        echo "             ⚠  $f declares [Autologin] User=… — SDDM will skip the greeter."
        echo "                Renaming to .disabled is NOT enough — SDDM parses every file in that dir."
        echo "                Move it out of /etc/sddm.conf.d/ entirely:"
        echo "                    sudo mv $f /etc/sddm-autologin.conf.disabled"
        break
    fi
done
