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
`/etc/sddm.conf.d/zz-nw-omarchy.conf` containing `[Theme] Current=nw-omarchy`.

### Why the `zz-` prefix matters

SDDM merges every `*.conf` in `/etc/sddm.conf.d/` in **lexical order, last
writer wins**. Omarchy ships a non-prefixed `autologin.conf` that carries
`[Theme] Current=omarchy`. A numeric-prefixed name like `20-nw-omarchy.conf`
sorts *before* `autologin.conf` (`'2'` < `'a'`), so omarchy's line is read last
and silently wins — the picker theme never loads and `nw-bspwm` stays
invisible. `zz-nw-omarchy.conf` sorts after any digit or the bare `autologin`
name, so our `Current=nw-omarchy` is the final word. (Installs from before this
fix dropped `20-nw-omarchy.conf`; re-running the installer deletes it.)

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

Omarchy ships `/etc/sddm.conf.d/autologin.conf`. Its contents vary by version —
sometimes a full autologin block, sometimes just the theme line:

```ini
[Autologin]
User=...
Session=hyprland-uwsm

[Theme]
Current=omarchy
```

Two distinct things can go wrong, and they have different fixes:

1. **`[Theme] Current=omarchy`** — handled automatically now. Our override is
   named `zz-nw-omarchy.conf` so it sorts last and wins the merge (see "Why the
   `zz-` prefix matters" above). No action needed.
2. **`[Autologin] User=…`** — when present and active, **SDDM never shows the
   greeter at all**: no theme, no picker, straight into hyprland. The `zz-`
   trick can't help — there's no greeter to theme.

For case 2 the installer now **offers to move the file aside** during
`install.sh --apply` (prompted, default no; the move is tracked so uninstall
restores it). If you decline, or want to do it by hand:

```bash
sudo mv /etc/sddm.conf.d/autologin.conf /etc/sddm-autologin.conf.disabled
sudo systemctl restart sddm
```

To re-enable autologin, move it back:

```bash
sudo mv /etc/sddm-autologin.conf.disabled /etc/sddm.conf.d/autologin.conf
sudo systemctl restart sddm
```

### Why move it *out*, not just rename it in place

SDDM reads **every** file in `/etc/sddm.conf.d/` regardless of extension.
Renaming `autologin.conf` to `autologin.conf.disabled` does **not** stop SDDM
from parsing it — the file is still loaded. (Its `[Theme]` line no longer
matters post-`zz-` fix, but the `[Autologin]` block could still fire.) Moving
it out of the directory is the only reliable disable.
