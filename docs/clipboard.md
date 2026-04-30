# Clipboard

## What works

| Chord | Action | How |
|---|---|---|
| `ctrl + c` / `ctrl + v` / `ctrl + x` | Standard copy / paste / cut | Native to every app — no nw-omarchy involvement |
| `ctrl + insert` / `shift + insert` | Copy / paste in alacritty | Mapped via `default/alacritty/keybindings.toml` to use the **CLIPBOARD** selection (alacritty's default `shift+insert` reads PRIMARY, which is the wrong buffer) |
| `super + ctrl + v` | Clipboard history picker | `clipmenu` (rofi-backed; `CM_LAUNCHER=rofi` set in bspwmrc autostart) |

## What does NOT work — `super + c` / `super + v` / `super + x`

omarchy's Hyprland config has universal clipboard chords on the super key (parity with macOS cmd). We **attempted** to port them and shipped several iterations — none reliably worked. **Use `ctrl + v` for paste**.

The bindings are not currently wired in `default/sxhkd/sxhkdrc`. The `nw-omarchy-paste` and `nw-omarchy-send-key` helpers were removed. If you want them locally, add overrides in `~/.config/sxhkd/sxhkdrc`, but expect them to misfire.

## What we tried (and why none stuck)

The fundamental problem: when sxhkd fires the binding, the user is still physically holding super. Anything we synthesise after that has to compete with the live modifier state.

1. `xdotool key --clearmodifiers ctrl+v` — synthetic event reached focused app as `super+ctrl+v` (apps don't bind that → no paste). `--clearmodifiers` is supposed to release/restore the held modifiers but loses to the physical hold on most apps.
2. `xdotool keyup super_l super_r` then `xdotool key ctrl+v` — silently no-op'd. xdotool keysyms are case-sensitive: `Super_L` works, `super_l` is rejected with "No such key name" but exits 0.
3. `xdotool keyup Super_L Super_R` then `xdotool key --clearmodifiers ctrl+v` — fixed the case bug; still inconsistent. evdev re-asserts super between our keyup and the next event because the user's finger is still on the key.
4. Strategy split by focused-window class: terminals get `ctrl+shift+v`, others get `xdotool type` of clipboard content. The `xdotool type` path works when invoked directly from a shell (verified: `DEBUG_xxx` typed at prompt) but doesn't reach the focused app reliably when fired via the sxhkd binding.
5. `xinput query-state` poll loop, waiting up to 1s for any modifier keycode (37,50,62,64,105,108,133,134) to release before firing. Probe shows the master keyboard reports **no modifiers down** when the binding fires (sxhkd's keyboard grab masks the state from xinput) so the loop short-circuits and we're back to (4)'s race.

We don't fully understand why `xdotool type` works direct but not via the binding — focus shift, sxhkd grab interaction with XTestFakeKeyEvent, or something deeper in the X event timing. Wayland sidesteps this entirely with `wlr-virtual-keyboard` (separate device, separate state); X11 has only XTest, which shares state with the real keyboard.

For reference — omarchy uses Hyprland's `sendshortcut` dispatcher (`bindd = SUPER, V, …, sendshortcut, SHIFT, Insert,`). That's a Hyprland-specific feature, not a Wayland protocol: Hyprland is the compositor and writes the per-client `wl_keyboard.modifiers` state directly, so the synthetic chord ships with a clean modifier mask regardless of what the user is physically holding. There's no equivalent on X11 short of becoming the X server.

## Future angle to try: ydotool

`ydotool` is uinput-based. It creates a separate virtual kernel input device and feeds events through evdev rather than XTest. The X server may track modifier state per-device, in which case synthetic ctrl+v from the ydotool device wouldn't merge with the physical keyboard's still-held super. Worth a 30-min experiment before declaring this dead. Steps:

1. Install `ydotool` + `ydotoold` (the daemon must run for ydotool to talk to uinput without root each call).
2. Re-add the `super + v` binding pointing at `ydotool key 29:1 47:1 47:0 29:0` (ctrl down, v down, v up, ctrl up) instead of xdotool.
3. Test in brave / alacritty / rofi the same way we did before.

If you crack it, PRs welcome.

## Diagnostic recipes

If `super + ctrl + v` (clipmenu) stops working:

```bash
# Is sxhkd alive and grabbing?
pgrep -af 'sxhkd -c' | head -1

# Is clipmenud collecting? (ships from clipmenu autostart)
pgrep -af clipmenud

# Is rofi the launcher? (set in bspwmrc; clipmenu uses CM_LAUNCHER)
echo "$CM_LAUNCHER"   # should print: rofi
```
