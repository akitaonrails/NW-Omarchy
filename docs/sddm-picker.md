# sddm-picker

The stock omarchy SDDM theme is a minimal black password box with **no session
selector** — it always launches `hyprland-uwsm` (look at
`/usr/share/sddm/themes/omarchy/Main.qml` lines 11-18). With nothing else done,
`nw-bspwm` is unreachable: the session entry exists, but the greeter never
asks.

This step ships a near-identical theme called `nw-omarchy` that adds a single
line under the password box:

```
session: nw-bspwm   ↑/↓
```

Up/Down (or Tab) cycles through every entry in `/usr/share/xsessions/` and
`/usr/share/wayland-sessions/`. Enter logs in to the currently shown session.

## Install

Part of the main install pipeline:

```bash
~/.local/share/nw-omarchy/install.sh --apply
```

Or in isolation:

```bash
nw-omarchy-sddm-picker enable --apply
sudo systemctl restart sddm     # kills the running X session
```

The theme is laid down at `/usr/share/sddm/themes/nw-omarchy/` (cloned from
the omarchy theme so we inherit `logo.svg`, then our `Main.qml` /
`metadata.desktop` overlaid). The switch happens via a single override at
`/etc/sddm.conf.d/20-nw-omarchy.conf` containing `[Theme] Current=nw-omarchy`.

## Disable / restore vanilla omarchy

```bash
nw-omarchy-sddm-picker disable --apply
sudo systemctl restart sddm
```

Removes our theme dir and the conf override. SDDM falls back to whatever else
is in `/etc/sddm.conf.d/` (e.g. `[Theme] Current=omarchy` from
`autologin.conf`). The original omarchy theme at
`/usr/share/sddm/themes/omarchy/` is **never touched** by us.

## Status

```bash
nw-omarchy-sddm-picker status
```

Shows whether the theme + override are installed, what each conf file in
`/etc/sddm.conf.d/` declares for `[Theme] Current=`, and warns if autologin
is bypassing the greeter entirely.

## Gotcha: autologin bypasses everything

Vanilla Omarchy ships `/etc/sddm.conf.d/autologin.conf` with:

```ini
[Autologin]
User=...
Session=hyprland-uwsm

[Theme]
Current=omarchy
```

When that's active, **SDDM never shows the greeter** — no theme matters, no
picker. To use the picker, move the file *out of* `/etc/sddm.conf.d/`:

```bash
sudo mv /etc/sddm.conf.d/autologin.conf /etc/sddm-autologin.conf.disabled
sudo systemctl restart sddm
```

To re-enable, move it back:

```bash
sudo mv /etc/sddm-autologin.conf.disabled /etc/sddm.conf.d/autologin.conf
sudo systemctl restart sddm
```

(We deliberately don't disable autologin during install — it's user-owned
omarchy state, and some users want it.)

### Why move it out, not just rename it

SDDM reads **every** file in `/etc/sddm.conf.d/` regardless of extension.
Renaming `autologin.conf` to `autologin.conf.disabled` does **not** stop
SDDM from parsing it — the file is still loaded and merges into the live
config. The autologin section won't be triggered (no `User=` matched at the
right time), but its `[Theme] Current=omarchy` line will quietly override
ours, because in the conf.d/ alphabetical merge `autologin.conf.disabled`
sorts after `20-nw-omarchy.conf` (last writer wins). Symptom: you see the
greeter (no picker), wonder why our theme didn't load, find this paragraph.
