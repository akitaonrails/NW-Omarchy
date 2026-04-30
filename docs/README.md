# nw-omarchy docs

Index of "what worked" notes for the bspwm/picom/XLibre layer on top of Omarchy.

## Bootstrap

```bash
cd ~/.local/share/nw-omarchy
./install.sh           # dry-run, prints planned actions
./install.sh --apply   # actually install

# Pick "nw-bspwm" at the SDDM session selector on next login.
```

## Uninstall

```bash
~/.local/share/nw-omarchy/uninstall.sh           # dry-run
~/.local/share/nw-omarchy/uninstall.sh --apply   # actually undo

# Or from anywhere on PATH:
nw-omarchy-uninstall --apply
```

The uninstaller reads `~/.local/state/nw-omarchy/manifest.tsv` and replays it in reverse:
- removes only the packages it installed (`pkg-skip` rows are left alone)
- restores backed-up configs from `~/.local/state/nw-omarchy/backups/`
- removes `/usr/share/xsessions/nw-bspwm.desktop`
- wipes the state dir (pass `--keep-state` to retain)

## Topics

- [architecture.md](architecture.md) — directory layout, manifest schema, install/uninstall pipeline
- [porting-hypr.md](porting-hypr.md) — Hyprland binding/feature → X11 map, omarchy helper substitutions
- [sddm-picker.md](sddm-picker.md) — adding a session picker to the omarchy SDDM greeter (so `nw-bspwm` is selectable)
- [theming.md](theming.md) — how bspwm/rofi/polybar pick up the active omarchy theme via `~/.config/omarchy/themed/`
- [menu.md](menu.md) — `nw-omarchy-menu`: 1-to-1 port of the omarchy system menu (super+alt+space)
- [gaps.md](gaps.md) — what's at parity vs vanilla omarchy, what's intentionally dropped, what's still worth building
- [services.md](services.md) — audit of every omarchy systemd unit / hook, with verdict on whether nw-omarchy needs to wire it
- [clipboard.md](clipboard.md) — universal copy/paste/cut bindings, app matrix, and what each chord actually fires

## Health-checking the install

```bash
nw-omarchy-doctor
```

Lints the live system in eight sections (Packages, Manifest, SDDM picker, Theme integration, Alacritty, Session, Live daemons). Marks every line `[OK]` (healthy), `[!]` (broken — fix suggested), or `[-]` (informational). Read-only, no side effects. First thing to run when something feels off, or after any `omarchy-*` upgrade that might have shifted theme files around.

## Gotchas worth knowing

### XLibre skipped by default

The original plan was bspwm + picom + **XLibre**. It fell apart on inspection of the actual AUR packaging:

- `xlibre-xserver-common-git` declares `Conflicts=xorg-server-common` but does **not** declare `Provides=xorg-server-common`.
- `xorg-xwayland` depends on `xorg-server-common`.
- `hyprland` depends on `xorg-xwayland`.

So pacman cannot install XLibre alongside Hyprland — installing it would force-remove `xorg-server-common` → `xorg-xwayland` → `hyprland` (the very session this project is supposed to sit *next* to). XLibre is a *replacement* for Xorg, not an addition.

Decision: bspwm runs on stock Xorg. Visually and functionally equivalent for our purposes — XLibre's wins are server-side modernization, none of which the bspwm-on-X11 stack can detect. The `xlibre-xserver-git` line is commented out in `packages/nw-omarchy.packages`; `install/xlibre.sh` is now diagnostic-only.

If you ever run nw-omarchy on a machine *without* Hyprland and want XLibre anyway:
```bash
yay -S xlibre-xserver-git
nw-omarchy-track record pkg xlibre-xserver-git    # so uninstall sees it
```
You'll get a pacman replace prompt; answer `y` to swap xorg-server-common.

### picom-FT-Labs animations syntax has drifted

The `animations = (...)` block in `default/picom/picom.conf` targets the FT-Labs fork's current syntax. If you upgrade the package and animations stop, check the [FT-Labs README](https://github.com/FT-Labs/picom) for the new keys — the `triggers` / `curve` / `duration` shape changes occasionally. Mainline picom silently ignores the block.

### Battery name on T14 Gen 6

Polybar's `[module/battery]` defaults to `BAT0` / `ADP1`. Verify with `ls /sys/class/power_supply/`. If yours is `BAT1` or `AC0`, edit `~/.local/share/nw-omarchy/default/polybar/config.ini` (or override in your shim).

### bspwmrc is shell, not config

Reload bspwm config with `bspc wm -r` (re-execs `bspwmrc`). Reload sxhkd separately with `pkill -USR1 -x sxhkd`. They're independent daemons.

### sxhkd uses *two* config files

bspwmrc launches sxhkd with `-c default-rc user-rc` — the **main** config goes after `-c`, **additional** configs are passed as positional args. We initially used `-c A -c B` and lost every binding (the second `-c` overrides the first; `man sxhkd` says `-c` takes a single file). Later definitions across the loaded files override earlier ones on conflict, so to override a binding put the same `super + key` line in `~/.config/sxhkd/sxhkdrc`. To *unbind* a default, sxhkd doesn't have a clean way — just rebind it to `:` (no-op) in your override.

### Hypr session is untouched

Nothing under `~/.config/hypr/`, `~/.local/share/omarchy/`, or `/etc/sddm.conf` is modified. Hyprland keeps appearing in the SDDM session menu next to `nw-bspwm`.

### Stock omarchy SDDM theme has no session picker

The vanilla `/usr/share/sddm/themes/omarchy/` Main.qml hardcodes the session whose name contains `uwsm` and exposes no UI to switch — meaning a fresh nw-omarchy install can't actually reach `nw-bspwm` from the greeter. Fix: we ship a clone of the theme called `nw-omarchy` with an Up/Down session picker. See [sddm-picker.md](sddm-picker.md). Autologin (vanilla Omarchy ships it on by default) bypasses themes entirely and must be disabled separately.

### SDDM reads every file in `/etc/sddm.conf.d/`, not just `*.conf`

Renaming `autologin.conf` to `autologin.conf.disabled` does **not** disable it — SDDM parses every file in `/etc/sddm.conf.d/` regardless of extension. A `.disabled` autologin file still has its `[Theme] Current=omarchy` merged in (last-key-wins, alphabetical) and silently overrides our nw-omarchy theme override. To actually disable: `sudo mv /etc/sddm.conf.d/autologin.conf /etc/sddm-autologin.conf.disabled` (out of the directory entirely).

## Things that are TODO

- Hyprland-style **blurry lockscreen background** (`nw-omarchy-lock` is currently a flat color — needs maim+convert+i3lock-color piping)
- `omarchy-menu` parity (gum-based system menu) — the script may already work on X11; needs testing
- ~~`omarchy-launch-or-focus` parity for X11~~ — done; `nw-omarchy-launch-or-focus` ships in `bin/` (wmctrl-based). See [porting-hypr.md](porting-hypr.md).
- ~~Theming: pick up the active omarchy theme and translate its colors into picom + polybar + rofi~~ — done; templates in `default/themed/` regenerate via `omarchy-theme-set-templates`. See [theming.md](theming.md).
