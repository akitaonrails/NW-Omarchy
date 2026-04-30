# nw-omarchy-menu

1-to-1 port of `omarchy-menu` for the bspwm/X11 stack. Every leaf in the
omarchy tree has either an identical mapping (when the underlying helper is
cross-stack) or an X11 cousin we ship in `bin/`.

## Bindings

```
super + alt + space   → nw-omarchy-menu                (top-level)
super + escape        → nw-omarchy-menu System         (jump to System submenu — power actions)
super + k             → nw-omarchy-menu-keybindings    (search live sxhkdrc bindings)
```

## Polybar entry points

The top bar exposes the same menu surface omarchy's waybar does. Click actions only — polybar 3.x has no hover/tooltip support, so we lean on right-click as a secondary path instead.

| Polybar item | left-click | right-click |
|---|---|---|
| Omarchy logo (leftmost) | `nw-omarchy-menu`              | `nw-omarchy-menu System`     |
| Date (centre)           | `nw-omarchy-menu Update`       | —                            |
| Audio                   | `nw-omarchy-launch-audio` (wiremix TUI) | `pavucontrol` (GUI mixer)   |
| Bluetooth               | `nw-omarchy-launch-bluetooth` (bluetui TUI) | `blueman-manager` (GUI) |
| Wifi                    | `nw-omarchy-launch-wifi` (impala TUI) | `nm-connection-editor` (GUI) |
| Battery                 | `nw-omarchy-menu Setup` (Power Profile lives there) | — |

Audio also gets `scroll-up`/`scroll-down` for ±5% volume and `click-middle` for mute toggle (parity with omarchy waybar's pulseaudio module).

The omarchy-logo glyph at U+E900 lives in `~/.local/share/fonts/omarchy.ttf` (shipped by omarchy). Polybar references it via `font-3 = omarchy:size=14;3` in `[bar/main]`, and the `[module/omarchy]` block uses `label-font = 4` (1-based) to render the glyph in that font.

## Driver

Where omarchy uses `walker --dmenu`, we use `rofi -dmenu`. Same stdin/stdout
contract; the `menu()` shell function in `nw-omarchy-menu` is the single
swap point. Theming is picked up automatically from
`~/.config/omarchy/current/theme/rofi-colors.rasi` (rendered by
`omarchy-theme-set-templates`; see [theming.md](theming.md)).

## Helpers we add (in `bin/`)

These match the surface of the omarchy helpers the menu calls but use bspwm
/ wmctrl / xinput / xrandr / ffmpeg+x11grab instead of hyprctl /
swayosd / wf-recorder / hyprpicker:

| Helper | Purpose |
|---|---|
| `nw-omarchy-menu`                 | the menu itself |
| `nw-omarchy-menu-keybindings`     | sxhkdrc parser → rofi search |
| `nw-omarchy-toggle-bar`           | `polybar-msg cmd toggle` |
| `nw-omarchy-toggle-gaps`          | bspc desktop window_gap toggle |
| `nw-omarchy-toggle-layout`        | `bspc desktop -l next` |
| `nw-omarchy-toggle-touchpad`      | `xinput {disable,enable}` per touchpad |
| `nw-omarchy-toggle-nightlight`    | redshift on/off |
| `nw-omarchy-toggle-idle`          | xss-lock daemon on/off |
| `nw-omarchy-toggle-screensaver`   | uses omarchy-toggle's flag-file (shared) |
| `nw-omarchy-cycle-scaling`        | xrandr --scale 1.0/1.25/1.5/2.0 cycle |
| `nw-omarchy-monitor-internal`     | xrandr --output INTERNAL --auto/--off |
| `nw-omarchy-cmd-screenrecord`     | ffmpeg x11grab + pulse + v4l2 (flag-compat with omarchy's) |
| `nw-omarchy-bg-set`               | feh + update omarchy current/background symlink |
| `nw-omarchy-launch-floating-terminal` | bspc one-shot floating rule + alacritty |
| `nw-omarchy-launch-or-focus-tui`  | wmctrl-based TUI focus-or-launch |
| `nw-omarchy-launch-audio`         | wiremix in TUI |
| `nw-omarchy-launch-wifi`          | impala in TUI |
| `nw-omarchy-launch-bluetooth`     | bluetui in TUI |
| `nw-omarchy-launch-about`         | fastfetch in TUI |
| `nw-omarchy-launch-screensaver`   | tte (terminal-art) in fullscreen alacritty |
| `nw-omarchy-restart-{bspwm,sxhkd,picom,polybar,dunst}` | restart-app cousins |
| `nw-omarchy-refresh-{bspwm,sxhkd,picom,polybar,rofi}`  | re-deploy the user shim from our default and restart |
| `nw-omarchy-system-{logout,reboot,shutdown}` | close all bspc nodes, then bspc quit / systemctl |

## Items we keep verbatim from omarchy

These don't touch hyprctl and work the same on either stack — the menu calls
them directly:

`omarchy-pkg-{add,install,aur-add,aur-install,remove}`,
`omarchy-webapp-{install,remove}`,
`omarchy-tui-{install,remove}`,
`omarchy-install-{dropbox,tailscale,nordvpn,once,vscode,steam,geforce-now,xbox-controllers,docker-dbs,dev-env,terminal,chromium-google-account}`,
`omarchy-remove-{preinstalls,dev-env}`,
`omarchy-theme-{install,list,set,update,remove,bg-{install,set,next}}`,
`omarchy-font-{list,current,set}`,
`omarchy-update`, `omarchy-update-{firmware,time}`,
`omarchy-channel-set`,
`omarchy-tz-select`,
`omarchy-drive-set-password`,
`omarchy-restart-{pipewire,wifi,bluetooth,trackpad}`,
`omarchy-setup-{dns,fingerprint,fido2}`,
`omarchy-toggle-suspend`, `omarchy-toggle-enabled`,
`omarchy-hibernation-{available,setup,remove}`,
`omarchy-cmd-share`,
`omarchy-windows-vm`,
`omarchy-show-logo`, `omarchy-show-done`,
`omarchy-refresh-{plymouth,tmux}`.

## Items we drop

Wayland-only with no useful X11 cousin in our stack:

- Toggle → 1-Window Ratio (no bspc concept; `single_monocle` is a separate switch we already expose elsewhere)
- Trigger → Hardware → Hybrid GPU stays via omarchy's helper, but the listing condition uses `omarchy-hw-hybrid-gpu` (still works on X11 — reads PCI)
- Setup → Config → Hyprland/Hypridle/Hyprlock/Hyprsunset/Swayosd/Walker/Waybar entries — replaced with bspwm/sxhkd/picom/polybar/rofi/dunst
- Update → Process → Hypridle/Hyprsunset/Swayosd/Walker/Waybar — replaced with bspwm/sxhkd/picom/polybar/dunst
- Update → Config → same swaps
- AI → Dictation (voxtype is Wayland-only)

## Extension hook

Same surface omarchy offers: drop a shell file at
`~/.config/nw-omarchy/menu.sh` and it gets sourced by `nw-omarchy-menu` at
the very end (after all the `show_*` functions are defined). Override or
add submenus there.

## Visual style

- **Font**: `JetBrainsMono Nerd Font Mono` (the `Mono` suffix is critical — without it nerd-font icons render at variable widths and the leading-icon column misaligns).
- **Theme**: rofi config is styled to match walker's `omarchy-default` look — solid translucent background, 2px accent border, selected rows signalled by **text-color change** (not a blue fill bar), 18pt menu / 22pt launcher / 16pt keybindings search.
- **Palette**: pulled from `~/.config/omarchy/current/theme/rofi-colors.rasi`, regenerated by `omarchy-theme-set-templates` on every theme change. See [theming.md](theming.md).

## Icon escape convention

Every icon in `bin/nw-omarchy-menu` is written as an explicit ANSI-C escape
inside `$'…'` strings: `\uXXXX` for BMP code points (4-digit), `\UXXXXXXXX`
for supplementary plane (8-digit). **Don't paste raw UTF-8 PUA glyphs into
the source.**

The reason: most of the nerd-font icons live in Unicode's Private Use Area
(U+E000–U+F8FF for BMP, U+F0000+ for supplementary). PUA codepoints have no
Unicode names, so editors / clipboards / JSON pipelines that round-trip via
"description" fields silently drop them — turning `` (cog) into a
literal space. Supplementary-plane PUA usually survives because its 4-byte
UTF-8 encoding round-trips through bytes-only paths, but BMP PUA (3 bytes
in UTF-8) gets misidentified as accidental whitespace and stripped by some
tools.

Writing the source as pure-ASCII escapes makes it grep-friendly, diff-clean,
and immune to copy-paste regressions. Look up codepoints at
[nerdfonts.com/cheat-sheet](https://www.nerdfonts.com/cheat-sheet).
