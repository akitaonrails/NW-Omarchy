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
