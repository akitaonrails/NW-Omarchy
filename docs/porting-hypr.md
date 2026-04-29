# Porting Hyprland → bspwm/sxhkd

## Binding map

The user's Hyprland config (omarchy default + personal overrides) → sxhkd, with X11 substitutes for omarchy helper scripts.

### Apps

App launchers route through `nw-omarchy-launch-*` / `nw-omarchy-cmd-*` helpers in `bin/` — X11 ports of the omarchy helpers, built on `wmctrl` + `xdotool` instead of `hyprctl`. PATH for these is set up in `bspwmrc` (sxhkd doesn't source `.bashrc`).

| Hyprland | sxhkd | substitute |
|---|---|---|
| `SUPER + RETURN` → terminal | `super + Return` | `alacritty --working-directory "$(nw-omarchy-cmd-terminal-cwd)"` |
| `SUPER + ALT + RETURN` → tmux | `super + alt + Return` | `alacritty -e bash -c "tmux attach || tmux new -s Work"` |
| `SUPER + SHIFT + RETURN` → browser | `super + shift + Return` | `nw-omarchy-launch-browser` |
| `SUPER + B`, `SUPER + SHIFT + B` → brave | both → `nw-omarchy-launch-browser` | same |
| `SUPER + SHIFT + ALT + B` → brave private | `super + shift + alt + b` | `nw-omarchy-launch-browser --private` (translates to per-browser flag) |
| `SUPER + SHIFT + F` → nautilus | `super + shift + f` | `nw-omarchy-launch-or-focus nautilus "nautilus --new-window"` |
| `SUPER + SHIFT + ALT + F` → nautilus (cwd) | `super + shift + alt + f` | `nautilus --new-window "$(nw-omarchy-cmd-terminal-cwd)"` |
| `SUPER + SHIFT + N` → editor | `super + shift + n` | `nw-omarchy-launch-editor` (TUI editors wrapped in alacritty) |
| `SUPER + SHIFT + D` → lazydocker | `super + shift + d` | `nw-omarchy-launch-tui lazydocker` |
| `SUPER + SHIFT + M` → spotify | `super + shift + m` | `nw-omarchy-launch-or-focus spotify` |
| `SUPER + SHIFT + G` → signal | `super + shift + g` | `nw-omarchy-launch-or-focus signal-desktop` |
| `SUPER + SHIFT + O` → obsidian | `super + shift + o` | `nw-omarchy-launch-or-focus obsidian "obsidian --disable-gpu"` |
| `SUPER + SHIFT + W` → typora | `super + shift + w` | `typora` |
| `SUPER + SHIFT + /` → 1password | `super + shift + slash` | `1password` |

### Webapps (Chrome `--app=` windows)

| Hyprland | sxhkd | substitute |
|---|---|---|
| `SUPER + SHIFT + A` → ChatGPT | same | `nw-omarchy-launch-webapp "https://chatgpt.com"` |
| `SUPER + SHIFT + ALT + A` → Grok | same | `nw-omarchy-launch-webapp "https://grok.com"` |
| `SUPER + SHIFT + C` → Calendar | same | `nw-omarchy-launch-webapp "https://app.hey.com/calendar/weeks/"` |
| `SUPER + SHIFT + E` → Email | same | `nw-omarchy-launch-webapp "https://app.hey.com"` |
| `SUPER + SHIFT + Y` → YouTube | same | `nw-omarchy-launch-webapp "https://youtube.com/"` |
| `SUPER + SHIFT + ALT + G` → WhatsApp | same | `nw-omarchy-launch-or-focus-webapp WhatsApp "https://web.whatsapp.com/"` |
| `SUPER + SHIFT + CTRL + G` → Google Messages | same | `nw-omarchy-launch-or-focus-webapp "Google Messages" "https://messages.google.com/web/conversations"` |
| `SUPER + SHIFT + P` → Google Photos | same | `nw-omarchy-launch-or-focus-webapp "Google Photos" "https://photos.google.com/"` |
| `SUPER + SHIFT + X` → X.com | same | `nw-omarchy-launch-webapp "https://x.com/"` |
| `SUPER + SHIFT + ALT + X` → X compose | same | `nw-omarchy-launch-webapp "https://x.com/compose/post"` |

### Tiling / windows

| Hyprland | sxhkd / bspc |
|---|---|
| `SUPER + W` → killactive | `super + w` → `bspc node -c` |
| `SUPER + J` → togglesplit | `super + j` → `bspc node -t \~tiled` (closest analogue) |
| `SUPER + P` → pseudo | `super + p` → `bspc node -t \~pseudo_tiled` |
| `SUPER + SHIFT + V` → togglefloating | `super + shift + v` → `bspc node -t \~floating` |
| `SHIFT + F11` / `ALT + F11` → fullscreen | both → `bspc node -t \~fullscreen` |
| `SUPER + arrow` → focus | `super + Left/Right/Up/Down` → `bspc node -f west/east/north/south` |
| `SUPER + SHIFT + arrow` → swap | `super + shift + arrow` → `bspc node -s west/...` |
| `SUPER + 1..0` → workspace | `super + {1-9,0}` → `bspc desktop -f {1-9,10}` |
| `SUPER + SHIFT + 1..0` → move to workspace | same → `bspc node -d {1-9,10} --follow` |
| `SUPER + TAB` → next workspace | `super + Tab` → `bspc desktop -f next.local` |
| `SUPER + SHIFT + TAB` → prev workspace | `super + shift + Tab` → `bspc desktop -f prev.local` |
| `SUPER + CTRL + TAB` → previous workspace | `super + ctrl + Tab` → `bspc desktop -f last` |
| `SUPER + minus/equal` → resize | same → `bspc node -z left ...` |
| `ALT + TAB` → cycle windows | `alt + Tab` → `bspc node -f next.local.!hidden.window` |

### Menus / launcher

| Hyprland | X11 |
|---|---|
| `SUPER + SPACE` → walker | `super + space` → `rofi -show drun` |
| `SUPER + CTRL + E` → emoji | `super + ctrl + e` → `rofi -show emoji` |
| `SUPER + K` → key bindings | `super + k` → `rofi -show keys` (TBD: pretty list) |
| `SUPER + ESCAPE` → system menu | **TODO** — `omarchy-menu system` may work; test after install |
| `SUPER + ALT + SPACE` → omarchy-menu | **TODO** — same |

### Aesthetics / system toggles

| Hyprland | X11 |
|---|---|
| `SUPER + L` → lock | `super + l` → `nw-omarchy-lock` (i3lock-color) |
| `SUPER + CTRL + L` → workspace layout toggle | `super + ctrl + l` → `bspc desktop -l next` |
| `SUPER + BACKSPACE` → toggle window transparency | not ported (picom rule-based, not toggle-based) |
| `SUPER + SHIFT + BACKSPACE` → toggle gaps | `super + BackSpace` → toggles current desktop's gap |
| `SUPER + SHIFT + SPACE` → toggle waybar | **TODO** — polybar equivalent: `polybar-msg cmd toggle` |
| Print → screenshot | `Print` → `nw-omarchy-cmd-screenshot region` (maim+slop+xclip+notify-send) |
| `SHIFT + Print` → fullscreen | `shift + Print` → `nw-omarchy-cmd-screenshot fullscreen` |
| `SUPER + ,` → dismiss notification | **TODO** — `dunstctl close` |

### Multimedia keys

All native via `pactl`, `brightnessctl`, `playerctl` (in package list). No omarchy helpers needed; works the same on X11.

### Touchpad gestures

Hyprland has built-in `gesture = N, direction, action` handling. On X11 there's no compositor for this, so we run a small daemon (`libinput-gestures`, AUR `libinput-gestures-git`). It listens on libinput swipe/pinch events and runs shell commands.

| Hyprland | X11 (libinput-gestures) |
|---|---|
| `gesture = 3, horizontal, workspace` | `gesture swipe left/right 3 → bspc desktop -f next.local/prev.local` |
| (none) | `gesture swipe left/right 4 → bspc node -d next/prev.local --follow` (move active window across) |

Config lives at `~/.config/libinput-gestures.conf` (symlinked to `default/libinput-gestures/libinput-gestures.conf` by `install/gestures.sh`). Started from `bspwmrc` after picom. Requires the user be in the `input` group — the install step warns if not.

Caveat vs Hyprland: there's **no live preview animation** during the swipe. libinput-gestures fires a discrete command on swipe completion, not a continuous scrub. You get the destination workspace; you don't see the in-between.

## Omarchy helper status

Omarchy ships ~80 `omarchy-*` scripts in `~/.local/share/omarchy/bin/`. The
launchers used by hypr bindings reach into `hyprctl` for window state, so on
X11 we ship our own ports with the same surface but `wmctrl` + `xdotool`
underneath.

### Ported in this repo

| omarchy helper (Wayland) | nw-omarchy port (X11) | implementation |
|---|---|---|
| `omarchy-launch-browser` | `nw-omarchy-launch-browser` | `xdg-settings` + per-browser private flag |
| `omarchy-launch-or-focus` | `nw-omarchy-launch-or-focus` | `wmctrl -lx` substring match on class/title, then `wmctrl -i -a` to focus |
| `omarchy-launch-webapp` | `nw-omarchy-launch-webapp` | resolves Chromium-class browser, runs `--app=<url>` |
| `omarchy-launch-or-focus-webapp` | `nw-omarchy-launch-or-focus-webapp` | composes the two above |
| `omarchy-launch-tui` | `nw-omarchy-launch-tui` | `alacritty --class org.nw-omarchy.<cmd> -e <cmd>` |
| `omarchy-launch-editor` | `nw-omarchy-launch-editor` | `$EDITOR`-aware; TUI editors wrapped in `nw-omarchy-launch-tui` |
| `omarchy-cmd-terminal-cwd` | `nw-omarchy-cmd-terminal-cwd` | `xdotool getactivewindow getwindowpid` → child shell `/proc/<pid>/cwd` |
| `omarchy-cmd-screenshot` | `nw-omarchy-cmd-screenshot` | `maim+slop+xclip+notify-send`; modes `region|fullscreen|smart` |
| `omarchy-lock-screen` | `nw-omarchy-lock` | i3lock-color (separate script, predates phase 2) |

The `nw-omarchy-` prefix is deliberate so we don't shadow the omarchy
originals on PATH. `bspwmrc` puts both `nw-omarchy/bin` and `omarchy/bin`
on PATH so bindings can reach either.

### Reused as-is from omarchy/bin

These have no Wayland deps and are useful inside our helpers / future
wrappers — we just call them through:

- `omarchy-cmd-present <cmd>` — `command -v` for multiple commands
- `omarchy-battery-*` — reads `/sys/class/power_supply/`
- `omarchy-brightness-display` — brightnessctl wrapper
- `omarchy-cmd-mic-mute-thinkpad` — pactl wrapper

### Still Wayland-specific (no port yet)

| Helper | Status / replace with |
|---|---|
| `omarchy-launch-walker` | use `rofi -show drun` directly (we don't ship walker) |
| `omarchy-toggle-waybar` | `polybar-msg cmd toggle` |
| `omarchy-hyprland-*` | rewrite case-by-case using `bspc` / `wmctrl` if needed |
| `omarchy-swayosd-client` | `pactl` direct (no OSD) or install `xob` |
| `makoctl` | `dunstctl` |

### Untested but probably fine

- `omarchy-menu` — gum-based, no obvious Wayland deps

## What we deliberately did NOT port

- **Window dimming on focus loss**: hypr `dim_inactive`. picom can do per-window opacity, but not focus-aware dim → too rough an approximation.
- **Per-window scaling**: Wayland-only (X11 has no per-window scale).
- **Workspace slide animation**: bspwm doesn't do compositor-side workspace transitions; picom-FT-Labs only animates per-window.
- **`omarchy-hyprland-active-window-transparency-toggle`** etc.: hyprctl-based, would need a per-window picom opacity rule manager.
