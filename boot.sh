#!/usr/bin/env bash
# nw-omarchy zero-friction bootstrapper.
#
# Recommended invocation:
#   curl -fsSL https://raw.githubusercontent.com/akitaonrails/NW-Omarchy/master/boot.sh | bash
#
# Skip the confirmation prompt:
#   curl -fsSL https://raw.githubusercontent.com/akitaonrails/NW-Omarchy/master/boot.sh | bash -s -- --yes
#
# What it does:
#   1. Checks Arch + omarchy + git
#   2. Clones (or updates) the repo at ~/.local/share/nw-omarchy
#   3. Runs install.sh --apply (which does packages + bspwm session +
#      picom v13 + XLibre swap as the last step)
#   4. Prints reboot reminder
#
# Idempotent: re-running after a repo bump pulls and re-applies cleanly.

set -euo pipefail

REPO_URL='https://github.com/akitaonrails/NW-Omarchy'
TARGET="$HOME/.local/share/nw-omarchy"
auto_yes=0

# Reattach stdin to the terminal so `read` works when the script is
# piped from curl. Probe /dev/tty in a subshell first — it can exist
# as a device file but fail to open if there's no controlling terminal
# (CI, sandboxes, headless), and a failed top-level `exec` aborts.
if [ ! -t 0 ] && (: </dev/tty) 2>/dev/null; then
    exec </dev/tty
fi

for arg in "$@"; do
    case "$arg" in
        --yes|-y)  auto_yes=1 ;;
        --help|-h)
            cat <<EOF
nw-omarchy bootstrap installer.

Clones $REPO_URL to $TARGET and runs the install pipeline.

  --yes        skip the confirmation prompt
  --help       show this and exit
EOF
            exit 0 ;;
        *)
            echo "unknown flag: $arg" >&2
            exit 2 ;;
    esac
done

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

bold "==> nw-omarchy bootstrap"
echo

# ── pre-flight ───────────────────────────────────────────────────────
if ! command -v pacman >/dev/null; then
    red "ERROR: pacman not found — nw-omarchy targets Arch Linux only."
    exit 1
fi

if [ ! -d "$HOME/.local/share/omarchy" ]; then
    red "ERROR: omarchy is not installed."
    echo "       nw-omarchy is a layered add-on for omarchy — install omarchy first:"
    echo "       https://learn.omacom.io/2/the-omarchy-manual"
    exit 1
fi

if ! command -v git >/dev/null; then
    echo "==> installing git (required to clone the repo)..."
    sudo pacman -S --needed --noconfirm git
fi

# ── confirm ─────────────────────────────────────────────────────────
if [ "$auto_yes" = 0 ]; then
    cat <<EOF
This will:
  - clone $REPO_URL to $TARGET
  - install bspwm + picom v13 + polybar + sxhkd + rofi + dunst (and helpers)
  - register an SDDM session entry called "nw-bspwm"
  - swap xorg-server for XLibre (system-wide, requires sudo)

Your existing omarchy / hyprland session is untouched — both sessions will
appear in SDDM after install. Reboot picks one or the other.

Manual revert if you change your mind later:
  sudo pacman -S xorg-server xorg-server-common xf86-input-libinput
  ~/.local/share/nw-omarchy/uninstall.sh --apply

EOF
    read -rp "Proceed? [y/N] " ans
    case "$ans" in
        [Yy]*) ;;
        *)     echo "Aborted."; exit 1 ;;
    esac
fi

# ── clone / update — pin to the latest stable tag ──────────────────
# Tag-based deployment so users land on a known-good release rather
# than HEAD of master. Falls back to default branch only if the repo
# has no v* tags yet (pre-1.0 emergency).
LATEST_TAG=$(git ls-remote --tags --refs --sort='-v:refname' "$REPO_URL" 'v*' 2>/dev/null \
    | head -1 | awk '{print $2}' | sed 's|refs/tags/||')

if [ -d "$TARGET/.git" ]; then
    echo
    bold "==> updating existing nw-omarchy clone"
    git -C "$TARGET" fetch --tags --quiet
    if [ -n "$LATEST_TAG" ]; then
        git -C "$TARGET" checkout --quiet "$LATEST_TAG"
        echo "    checked out $LATEST_TAG"
    else
        git -C "$TARGET" pull --ff-only
    fi
else
    echo
    if [ -n "$LATEST_TAG" ]; then
        bold "==> cloning nw-omarchy $LATEST_TAG → $TARGET"
        mkdir -p "$(dirname "$TARGET")"
        git clone --depth 1 --branch "$LATEST_TAG" "$REPO_URL" "$TARGET"
    else
        bold "==> cloning nw-omarchy → $TARGET (no tags yet, using default branch)"
        mkdir -p "$(dirname "$TARGET")"
        git clone --depth 1 "$REPO_URL" "$TARGET"
    fi
fi

# ── install ─────────────────────────────────────────────────────────
echo
bold "==> running install pipeline (--apply)"
echo "    sudo will be requested for package installs and the XLibre swap."
echo
"$TARGET/install.sh" --apply

# ── done ────────────────────────────────────────────────────────────
echo
green "==> nw-omarchy installed."
cat <<EOF

Next steps:
  1. Reboot.
  2. At the SDDM login screen, pick the "nw-bspwm" session.
  3. After login, super+space opens the launcher; super+k shows all keybindings.

Documentation: $TARGET/docs/README.md
EOF
