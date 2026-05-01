# Gaps vs vanilla Omarchy

Where nw-omarchy is at parity, what's intentionally dropped, and what's still worth building. Last refreshed after the picom v13 + XLibre + binding-parity sweep (early May 2026).

## Footprint

|  | omarchy | nw-omarchy |
|---|---:|---:|
| `bin/` helpers | 227 | 49 |
| `default/` component dirs | 24 | 12 |

The 178-helper gap is mostly omarchy's hardware/install/system internals which we either reuse via PATH (no need to fork) or that target the boot/filesystem layer (out of scope here).

## At parity ✅

- **X server** — XLibre (maintained xorg-server fork) installed by the regular `install.sh --apply` pipeline. Coexists with omarchy's hyprland (xorg-xwayland untouched). See [`why-xlibre.md`](why-xlibre.md), [`xlibre.md`](xlibre.md).
- **Window manager + bindings** — bspwm/sxhkd mirror hyprland's full binding map: apps + webapps, focus / swap / workspaces, resize, screenshots, multimedia, and the omarchy v2 `super+l` ↔ `super+ctrl+l` convention (layout vs lock). 73 bindings total.
- **Top bar** — polybar with the omarchy-logo launcher, per-module click actions, the same nerd-font icons waybar uses (audio/wifi/bluetooth/battery), and a custom-script battery module that handles the firmware-paused-on-AC state polybar's internal/battery silently dropped.
- **Compositor effects** — upstream picom v13: blur, rounded corners, shadows, opacity-rule, fade-on-open/close. Replaces the abandoned FT-Labs fork whose animation system never engaged on bspwm tag changes. (We tried a custom workspace-pan slide on top of v13's trigger system; reverted to plain fade — see `docs/README.md`.)
- **System menu** (`super+alt+space`) — 1:1 port of `omarchy-menu` via `rofi -dmenu`, every leaf
- **App launcher** — `super+space` is the full `rofi -show drun` (every .desktop entry, type to filter); `super+shift+space` is the pinned-apps cheat-sheet parsed from sxhkdrc with chord shown next to each.
- **Keybindings cheat-sheet** (`super+k`) — searchable list of every binding, with leading-comment as description
- **Notifications** — dunst, themed via the same template pipeline as polybar/rofi/bspwm. `super+,` family dismisses (last/all/silence-toggle), parity with omarchy's mako `super+,` chords. Toast actions: clicking the screenshot toast opens the image (mirrors omarchy-cmd-screenshot's `notify-send -A` pattern).
- **Per-app TUIs** — `super+ctrl+a/b/w/t/h/s` cover audio / bluetooth / wifi / btop / hardware-menu / share-menu via `nw-omarchy-launch-*` and `nw-omarchy-menu`, parity with omarchy's `super+ctrl+letter` family.
- **Theme integration** — bspwm border / rofi / polybar / dunst regenerate via `omarchy-theme-set-templates` on every theme change. Same path omarchy uses for hypr.
- **SDDM picker theme** — clone of the omarchy theme with a session selector added
- **Touchpad gestures** — 3-finger horizontal → workspace switch via `libinput-gestures`
- **Clipboard manager** — clipmenu (rofi-backed) via `super+ctrl+v`
- **Lock screen** — i3lock-color, palette pulled from active theme
- **Floating Setup TUIs** — wiremix / impala / bluetui / fastfetch open as centered floating overlays
- **Doctor / status** — `nw-omarchy-doctor` lints the live install in 8 categories
- **Input prefs** — natural-scroll, keyboard repeat 250/40, parity with omarchy's hypr `input.conf`
- **Idle handling** — xidlehook fires the tte terminal-art screensaver at 5 min, `loginctl lock-session` (→ xss-lock → nw-omarchy-lock) at 10 min
- **Battery notifier** — reuses omarchy's `omarchy-battery-monitor.timer`; bspwmrc starts it on session start
- **Mic-mute LED** — `nw-omarchy-cmd-mic-mute` flips `platform::micmute` on ThinkPads (no-ops on hardware without the LED)
- **Update-available indicator** — polybar `module/update` polls `omarchy-update-available` every 10 min; click runs `omarchy-update` in a floating terminal
- **Calculator in launcher** — `super+ctrl+c` opens rofi calc mode; Enter copies the result to clipboard
- **Color picker** — `super+Print` runs `xcolor` and copies the hex to clipboard (xcolor is the X11 substitute for hyprpicker)
- **App launcher icons** — `nw-omarchy-launcher` (super+space) emits the rofi dmenu icon protocol (`\0icon\x1f<name>`) per row; icons resolve through the active icon theme (Papirus / Adwaita). Heuristic class derivation from the binding's command — covers `nw-omarchy-launch-*` helpers and bare commands.
- **Web search** (`super+slash`) — `nw-omarchy-launcher-websearch` opens a rofi prompt and feeds the URL-encoded query to the default browser via `xdg-open`. Engine override via `NW_OMARCHY_SEARCH_URL` env var (default DuckDuckGo). Replaces walker's `websearch` provider.
- **Picom rules-block config** — migrated off the legacy `shadow-exclude` / `blur-background-exclude` / `opacity-rule` / `rounded-corners-exclude` / `wintypes` family to picom v13's unified `rules = (...)` block. Same visual behaviour, but per-window animations are now suppressible (e.g. for slop/rofi/dunst), which unlocks future work like a direction-aware workspace pan.

## Intentional drops ⛔

Wayland-only or out-of-scope, with no useful X11 cousin in our stack:

| Component | Reason |
|---|---|
| Walker rich preview pane (theme picker) | Walker is Wayland-only; rofi has no preview equivalent |
| Continuous workspace swipe with **live preview** during the gesture | bspwm has no in-progress switch state; libinput-gestures fires on completion only. Hyprland gets it because it's both WM and compositor. |
| **Workspace-pan slide animation** (windows slide as one on switch) | Built it on picom v13 with a custom `offset-x` script keyed off `window-monitor-width`. Reverted because (a) direction was fixed regardless of next/prev — picom can't tell which way the user moved; (b) the slop screenshot overlay got animated through the same `open` trigger, and suppressing it would require migrating every legacy exclude/wintype/opacity option to v13's new `rules` block in one shot. Simple opacity fade for now. |
| Hyprland's `dim_inactive` focus dimming | upstream picom has no focus-aware dim either; would need per-window opacity rule reshuffling on focus events |
| Voxtype dictation | Wayland-only |
| Native fractional scaling | X11 only does integer-per-output |
| Polybar tooltips on hover | polybar 3.x limitation; right-click is our secondary path |
| Plymouth boot splash, snapper snapshots, limine theme | Boot/filesystem layer — outside the project scope |
| Hyprsunset / hypridle (Wayland daemons) | Replaced with redshift / xss-lock |
| `super + c` / `super + v` / `super + x` universal clipboard | Couldn't make X11 key synthesis reliable while super was still physically held — see `docs/clipboard.md`. `ctrl + c` / `ctrl + v` / `ctrl + x` work natively; `super + ctrl + v` opens history. |
| Scratchpad (`super + s` → togglespecialworkspace) | bspwm's marked-node + hidden-flag combo could approximate it but needs a stateful daemon to track the scratch toggle. Niche enough to skip. |
| Window grouping (`super + g`, `super + alt + arrow`, `super + alt + Tab`) | hypr v2's tabbed/stacked groups have no clean bspwm analog. |
| Pop-out window (`super + o` → float + pin) | Trivial in hypr (`togglefloating`+pin), in bspwm needs `bspc node -t floating; bspc node -g sticky=on` plus state to restore. Skipped; users who care can add it locally. |
| Cursor zoom (`super + ctrl + z`) | X11 has no per-cursor zoom; xrandr `--scale` applies globally and looks heavy-handed. |
| Active-window transparency toggle (`super + BackSpace` in hypr) | Would require a per-window picom opacity-rule manager. We use `super + BackSpace` for the gap-toggle that omarchy puts on `super + shift + BackSpace`. |
| Waybar toggle (`super + shift + space`) | Reused that chord for the pinned-apps cheat-sheet — felt more useful than a bar visibility toggle. polybar can still be toggled via `polybar-msg cmd toggle` if you bind it locally. |
| Capture menu chord (`super + ctrl + c` in omarchy) | Reused for rofi-calc — calculator is more valuable on a laptop. Capture menu still reachable through `super + alt + space` → Capture. |

## Gaps worth filling 🔨

Open work, deferred until use exposes which actually matters. Full design notes for each in [`future.md`](future.md):

| # | Gap | Effort | Notes |
|---:|---|---|---|
| 1 | **Direction-aware workspace animation** | ~2-3 h | Wrap bspc desktop switching with a script that picks `picom.forward.conf` / `picom.backward.conf` and SIGUSR1-reloads picom. Small race-window caveat. See [`future.md`](future.md). |
| 2 | **Pop-out window** (`super + o`) | ~30 min | bspwm `floating + sticky + layer=above` toggle, state file per window. See [`future.md`](future.md). |
| 3 | **Scratchpad** (`super + s`) | ~30 min – 2 h | Two flavors documented in [`future.md`](future.md): workspace-style (cheap, glorified super+9) or window-stash style (matches hypr UX, has edge cases). |

### Pre-1.0: no migration tool

`install.sh --apply` is the canonical path to the latest target state, idempotent, safe to re-run. It auto-removes known predecessor packages (currently `picom-ftlabs-git` → `picom`) so re-running after a repo pull converges cleanly even on previously-installed systems. `bin/nw-omarchy-xlibre-migrate` will stay a no-op stub until we cut 1.0+ tags and need to express deltas between them.

## Not worth doing ❌

- **Walker-style preview pane** in theme picker — different UX, substantial rofi-mode rewrite for marginal gain. The 17-theme name list is fine.
- **Per-monitor scaling** — X11 doesn't support it cleanly; `nw-omarchy-cycle-scaling` does whole-screen integer scale and that's the ceiling.
- **Forking omarchy-pkg-* / -theme-* / -update / -setup-* / -font-*** — they're cross-stack-portable; we just call them.
- **First-run helper** parity (`omarchy-cmd-first-run`) — our install pipeline is idempotent and `nw-omarchy-doctor` is the equivalent post-install check.

## Recommended next moves

The original "top five" items (mic-mute LED, battery notifier, update indicator, idle screensaver, calculator) all landed. picom v13, XLibre, binding parity, launcher icons, web-search, and the rules-block migration all landed too. The project is now in polish territory:

1. **Direction-aware workspace animation** (~3h) — closes the last meaningful animation gap
2. **Pop-out / scratchpad** if you actually miss them in daily use

Beyond those, deeper omarchy parity hits the X11 ceiling — see "Intentional drops" — so further effort returns diminishing UX gains. Live with it for a few weeks before deciding whether anything in the drops list is actually missed.
