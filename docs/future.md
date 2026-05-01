# Future work — design notes

Plans for features called out in [`gaps.md`](gaps.md) but not yet shipped. Captured here so the next person (or future-you) doesn't have to redo the architectural exploration.

---

## Direction-aware workspace animation

**Status:** unblocked since the picom v13 rules-block migration. Not yet implemented.

**Goal:** when going forward (`super+Tab`, `super+2` from desktop 1, swipe-left), windows on the outgoing workspace slide off to the **left** and incoming windows slide in from the **right**. When going backward, mirror it. Direction matches the visual semantics of "you moved this way, so the world moves the other way."

**Why it's hard:** picom v13 doesn't know which direction the user moved in bspwm. It sees `MapNotify` / `UnmapNotify` per window and can match against window properties, but has no global "WM action context" variable.

### Approach: wrap bspc with a direction-detector that swaps picom configs

Two picom configs differ only in the rules block — same blur / shadows / opacity rules, opposite `offset-x` start values for the workspace-pan rule:

- `~/.config/picom/picom.forward.conf` — `start = "window-monitor-width"` for show, `end = "0 - window-monitor-width"` for hide
- `~/.config/picom/picom.backward.conf` — flipped

`~/.config/picom/picom.conf` is a symlink to whichever is currently active.

A wrapper script intercepts every desktop change:

```bash
# bin/nw-omarchy-bspc-direction
target="$1"  # next | prev | <desktop-number>
current=$(bspc query -D -d focused --names)
case "$target" in
    next|"+1") dir=forward ;;
    prev|"-1") dir=backward ;;
    [0-9]*)    [ "$target" -gt "$current" ] && dir=forward || dir=backward ;;
esac

state=$XDG_RUNTIME_DIR/nw-omarchy-direction
if [ "$(cat "$state" 2>/dev/null)" != "$dir" ]; then
    ln -sf "$HOME/.config/picom/picom.$dir.conf" "$HOME/.config/picom/picom.conf"
    pkill -USR1 picom
    echo "$dir" >"$state"
fi

case "$target" in
    next) bspc desktop -f next.local ;;
    prev) bspc desktop -f prev.local ;;
    *)    bspc desktop -f "$target" ;;
esac
```

`sxhkdrc` swaps the direct `bspc desktop -f` calls (super+Tab, super+shift+Tab, super+{1-5}) for `nw-omarchy-bspc-direction <target>`. Same for `libinput-gestures.conf` swipe actions.

### Race window

`pkill -USR1 picom` reloads the config; `bspc desktop -f` switches. The reload is fast (~tens of ms) but the ordering means a single stale-direction frame can flash on the **first** switch after reversing direction. Once `state` matches the new direction, subsequent switches in the same direction don't reload picom and have no race at all.

**Mitigation options** (pick one if it's noticeable):
- `sleep 0.05` between SIGUSR1 and `bspc desktop -f`. Lazy but reliable.
- Track the desktop change in two phases: send SIGUSR1, wait for picom's window to repaint via inotify on `~/.cache/picom/...`, then fire bspc. Overengineered.
- Accept the race — most users won't notice a 50 ms flash on the first reverse.

### Effort: ~2–3 h

Most of it is testing the race-window perception and writing the two config variants. The wrapper itself is ~30 lines.

---

## Pop-out window (`super + o` → float + sticky + above)

**Goal:** match Hyprland's `togglefloating` + pin combo. Take the focused window, make it floating, sticky across desktops, and always-on-top. Pressing the chord again restores it to the tiled layout.

**Mechanism:** bspwm has all the primitives.

```bash
# bin/nw-omarchy-window-pop-out
node=$(bspc query -N -n focused)
state="$XDG_RUNTIME_DIR/nw-omarchy-popped-$node"

if [ -f "$state" ]; then
    bspc node "$node" -g sticky=off layer=normal
    bspc node "$node" -t tiled
    rm "$state"
else
    bspc node "$node" -t floating
    bspc node "$node" -g sticky=on layer=above
    touch "$state"
fi
```

Plus one line in sxhkdrc:

```
# Pop window out (float + sticky + always-on-top)
super + o
    nw-omarchy-window-pop-out
```

State file per-window so multiple windows can be popped independently. State files survive across sessions only by accident; that's fine — if a window is destroyed while popped, the stale state file gets cleared at next pop attempt (we'd need to add `rm` for stale entries on next invocation).

### Effort: ~30 min

Including testing on 2–3 windows simultaneously and verifying behavior on bspwm restart.

---

## Scratchpad (`super + s` → stash / unstash)

Two flavors — pick one based on workflow. Hyprland's `togglespecialworkspace` is closer to flavor B.

### Flavor A: workspace-style scratch desktop

A dedicated `scratch` desktop you toggle to/from. State file remembers the previous desktop so the toggle returns you home.

```bash
# bin/nw-omarchy-scratchpad
SCRATCH=scratch
state=$XDG_RUNTIME_DIR/nw-omarchy-scratchpad-prev

current=$(bspc query -D -d focused --names)
if [ "$current" = "$SCRATCH" ]; then
    bspc desktop -f "$(cat "$state" 2>/dev/null || echo 1)"
else
    bspc query -D --names | grep -q "^$SCRATCH$" || bspc monitor -a "$SCRATCH"
    echo "$current" >"$state"
    bspc desktop -f "$SCRATCH"
fi
```

Pros: trivial. Cons: it's basically a glorified `super+9` — you still have to manually move windows to/from the scratch desktop.

### Flavor B: window-stash style (closer to Hypr UX)

Mark the focused window as "scratch" + hide it. Press the chord again to unhide it on the current desktop. Works like a quake-style dropdown but driven by per-window state instead of a tied app.

```bash
# bin/nw-omarchy-scratchpad
MARK_PROP=_NW_SCRATCH_PINNED  # custom X11 atom we set on the stashed window

scratched=$(xdotool search --name '.*' \
    | xargs -I{} sh -c 'xprop -id {} _NW_SCRATCH_PINNED 2>/dev/null \
        | grep -q "1" && echo {}' 2>/dev/null | head -1)

if [ -n "$scratched" ]; then
    # Bring stashed window to current desktop
    bspc node "$scratched" -d focused -g hidden=off
    xdotool windowunmap "$scratched"  # let bspwm handle remap
    xdotool windowmap "$scratched"
    xprop -id "$scratched" -remove "$MARK_PROP"
else
    # Stash focused window
    win=$(bspc query -N -n focused)
    xprop -id "$win" -f "$MARK_PROP" 32c -set "$MARK_PROP" 1
    bspc node "$win" -g sticky=on hidden=on
fi
```

Pros: matches the "I want this terminal handy but invisible until I summon it" workflow. Cons: edge cases — what if user destroys the stashed window? What if the user stashes another window before unstashing the first one? (Treat it as LIFO via the marker?) What if the X atom survives across reboots? (It shouldn't because windows are recreated, but worth verifying.)

### Effort

- Flavor A: ~30 min
- Flavor B: ~1–2 h depending on edge-case tolerance

### Recommendation

Don't ship either until you've used the rest of nw-omarchy for a few weeks and decide whether you actually miss scratchpads in daily use. They're heavily Hyprland-personal — many users never touch them.

---

## What links here

- [`gaps.md`](gaps.md) lists these as remaining gaps with rough effort estimates; this doc is the design depth behind those one-line entries.
- [`porting-hypr.md`](porting-hypr.md) lists what's *not* coming back from Hyprland; if you decide to ship one of these features, move its row from there to "at parity" in `gaps.md`.
