# XLibre — opt-in X server replacement

XLibre is a community fork of `xorg-server`, actively maintained. nw-omarchy can run on top of either xorg-server (default) or XLibre. **Nothing in this repo's code paths cares which X server is running** — bspwm, picom, polybar, sxhkd, rofi, dunst, xdotool, etc. are all libxcb/libx11 protocol clients, not server modules.

This doc covers the optional migration. The default install does **not** swap your X server.

## Why bother

XLibre tracks fixes, security patches, and modernisation that mainline `xorg-server` no longer ships actively. Active distros: Artix Linux 2026.04+ ships it as default; Fedora has an open Change proposal. For an X11-first stack like nw-omarchy, it's a low-risk way to stay on a maintained X server.

## What the migration touches

In scope (XLibre owns):
- `xorg-server`, `xorg-server-common`, `xorg-server-{devel,xephyr,xnest,xvfb}` → `xlibre-xserver*` equivalents
- `xf86-input-*` → `xlibre-input-*`
- `xf86-video-*` → `xlibre-video-*`
- (bundled into `xlibre-xserver` itself: `xf86-video-modesetting`, `glamor-egl`)

Out of scope (stays on arch repos):
- `xorg-xinit`, `xorg-xrandr`, `xorg-xset`, `xorg-xrdb`, `xorg-xprop`, `xorg-xkill`, `xorg-xinput`, `xorg-xkbcomp`, `xorg-xauth`, `xkeyboard-config`
- `libx11`, `libxcb`, `libxtst`, `mesa`, `libdrm`, `libglvnd`
- `xorg-xwayland` — completely separate package (used by hyprland), no conflict declared

## Compatibility

Wire-protocol parity with X11R7 — every X11 client app keeps working. The break is the **DDX driver ABI**: `xlibre-xserver` declares
```
provides=('xorg-server' 'X-ABI-VIDEODRV_VERSION=28.0' 'X-ABI-XINPUT_VERSION=26.0' 'X-ABI-EXTENSION_VERSION=11.0' 'x-server')
```
which is incompatible with the arch xorg-server's ABIs. That's why the swap must be transactional — input/video drivers ride along in the same pacman invocation.

### Nvidia notes
- XLibre **>= 25.0.0.16**: proprietary nvidia auto-detected, no config needed
- XLibre **<= 25.0.0.15**: requires `Option "IgnoreABI" "1"` in xorg.conf (turns off the safety check globally — not great)
- nouveau / amdgpu / Intel: install the `xlibre-video-*` equivalent, no extra config

## Migration script

```bash
nw-omarchy-xlibre-migrate                  # preview (dry-run)
nw-omarchy-xlibre-migrate --apply          # commit
nw-omarchy-xlibre-migrate --revert --apply # roll back
```

Idempotent. Re-running on a fully-migrated system is a no-op. The pipeline:
1. Trust XLibre signing key `73580DE2EDDFA6D6` (skip if trusted)
2. Append `[xlibre]` repo to `/etc/pacman.conf` (skip if present)
3. `pacman -Sy`
4. Compute swap set from currently-installed `xorg-*` / `xf86-*` packages
5. Single `pacman -S --needed` invocation — provides/conflicts handle the xorg-server removal natively, no manual `-R`

After it finishes: **reboot**. The running X session is still using the old binary; the swapped files only take effect on next session start.

## Revert

```bash
nw-omarchy-xlibre-migrate --revert --apply
```

Reinstalls `xorg-server` + matching `xf86-*` drivers via the same provides/conflicts dance. The `[xlibre]` repo entry and signing key are left in place — remove manually if desired:
```bash
sudo sed -i '/^\[xlibre\]/,/^$/d' /etc/pacman.conf
sudo pacman-key --delete 73580DE2EDDFA6D6
```

## Risk and rollback plan

For a single-GPU Intel/AMD/nouveau box: very low risk. The driver ABI swap is the only failure mode, and pacman rolls the transaction back atomically if something can't resolve.

If the X session refuses to start after reboot:
1. Switch to a TTY (`Ctrl+Alt+F2`)
2. Log in
3. `nw-omarchy-xlibre-migrate --revert --apply`
4. `sudo systemctl restart sddm`

## Why not auto-run from `install.sh`

Replacing the X server is a substantially riskier operation than the rest of nw-omarchy's install pipeline (which only touches user configs and the bspwm session entry). Keeping XLibre out of the default flow lets you decide whether the trade-off makes sense for your system, and lets the rest of the install pipeline stay safely re-runnable on a vanilla omarchy box.
