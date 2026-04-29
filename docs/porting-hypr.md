# Porting Hyprland → bspwm/sxhkd

## Binding map

The user's Hyprland config (omarchy default + personal overrides) → sxhkd, with X11 substitutes for omarchy helper scripts.

### Apps

| Hyprland | sxhkd | substitute |
|---|---|---|
| `SUPER + RETURN` → terminal | `super + Return` | `alacritty` direct (no `xdg-terminal-exec` on X11 yet) |
| `SUPER + ALT + RETURN` → tmux | `super + alt + Return` | `alacritty -e bash -c "tmux attach || tmux new -s Work"` |
| `SUPER + SHIFT + RETURN` → browser | `super + shift + Return` | `brave` direct (no `omarchy-launch-browser`) |
| `SUPER + B`, `SUPER + SHIFT + B` → brave | both → `brave` | same |
| `SUPER + SHIFT + ALT + B` → brave private | `super + shift + alt + b` | `brave --incognito` |
| `SUPER + SHIFT + F` → nautilus | `super + shift + f` | `nautilus --new-window` |
| `SUPER + SHIFT + N` → editor | `super + shift + n` | `alacritty -e nvim` |
| `SUPER + SHIFT + D` → lazydocker | `super + shift + d` | `alacritty -e lazydocker` |
| `SUPER + SHIFT + M` → spotify | `super + shift + m` | wmctrl-focus or launch |
| `SUPER + SHIFT + G` → signal | `super + shift + g` | `signal-desktop` |
| `SUPER + SHIFT + O` → obsidian | `super + shift + o` | `obsidian` |
| `SUPER + SHIFT + W` → typora | `super + shift + w` | `typora` |
| `SUPER + SHIFT + /` → 1password | `super + shift + slash` | `1password` |

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
| Print → screenshot | `Print` → `maim --select | xclip` |
| `SUPER + ,` → dismiss notification | **TODO** — `dunstctl close` |

### Multimedia keys

All native via `pactl`, `brightnessctl`, `playerctl` (in package list). No omarchy helpers needed; works the same on X11.

## Omarchy helper status

Omarchy ships ~80 `omarchy-*` scripts in `~/.local/share/omarchy/bin/`. Many are pure shell and work on X11; others assume Wayland tools.

### Likely portable (no Wayland deps; reuse)

- `omarchy-battery-*` — reads `/sys/class/power_supply/`
- `omarchy-cmd-terminal-cwd` — reads `/proc/<pid>/cwd`
- `omarchy-launch-tui` — generic terminal-launching wrapper
- `omarchy-launch-editor` — same

### Wayland-specific (need replacement)

| Helper | Replace with |
|---|---|
| `omarchy-launch-walker` | `rofi -show drun` |
| `omarchy-launch-or-focus` | `wmctrl -x -a <class> \|\| <cmd>` |
| `omarchy-cmd-screenshot` | `maim --select \| xclip` |
| `omarchy-lock-screen` | `nw-omarchy-lock` (this repo) |
| `omarchy-toggle-waybar` | `polybar-msg cmd toggle` |
| `omarchy-hyprland-*` | rewrite case-by-case using bspc/wmctrl |
| `omarchy-swayosd-client` | `pactl` direct, no OSD (or install xob) |
| `makoctl` | `dunstctl` |

### Untested but probably fine

- `omarchy-menu` — gum-based, no Wayland deps that I can see
- `omarchy-cmd-mic-mute-thinkpad` — pactl wrapper
- `omarchy-brightness-display` — brightnessctl wrapper

## What we deliberately did NOT port

- **Window dimming on focus loss**: hypr `dim_inactive`. picom can do per-window opacity, but not focus-aware dim → too rough an approximation.
- **Per-window scaling**: Wayland-only (X11 has no per-window scale).
- **Workspace slide animation**: bspwm doesn't do compositor-side workspace transitions; picom-FT-Labs only animates per-window.
- **`omarchy-hyprland-active-window-transparency-toggle`** etc.: hyprctl-based, would need a per-window picom opacity rule manager.
