# Lore

Platform behaviour that cost real time to discover — QML, Qt Quick, Quickshell,
Wayland, and the CLI tools we shell out to. Things that are *not* inferable from
the docs, or that contradict a reasonable assumption.

Not architecture. Not decisions. Just facts about the ground we're standing on.

**Provenance is marked on every entry, and it matters** (`R9`):

- `[verified]` — reproduced on this machine, in this project, with output seen.
- `[inherited]` — carried over from the previous `Ninab` iteration's notes
  (`git show abded3f:configs/.config/quickshell/Ninab/CLAUDE.md`), where it was
  recorded as tested. **Not re-verified here.** Trust it enough to design around,
  not enough to skip checking when it bites.

## Tags

Fixed vocabulary (`R20`). A new tag is added here by hand before it is used.

`#qml` `#quickshell` `#wayland` `#cli` `#ipc` `#machine` `#windowing` `#cursor`
`#config` `#input` `#audio` `#network` `#layout`

## Index

| ID | Fact | Tags |
|---|---|---|
| L1 | A type tag needs an uppercase filename | `#qml` `#layout` |
| L2 | Each directory is a separate implicit-import scope | `#qml` `#layout` |
| L3 | A plain `Item` ignores its own implicit size | `#qml` |
| L4 | A property named like the outer `id` binds to itself | `#qml` |
| L5 | `clip: true` is a bounding-box clip, not a rounded one | `#qml` |
| L6 | A fresh `Process` does not auto-run | `#quickshell` |
| L7 | `QtObject` has no default property | `#quickshell` `#config` |
| L8 | `Array.isArray()` is false on a `JsonAdapter` array | `#quickshell` `#config` |
| L9 | `visible: false` stops rendering, not timers | `#quickshell` |
| L10 | No global cursor position for a layer-shell surface | `#wayland` `#cursor` |
| L11 | An accepted click is exclusively yours | `#wayland` `#input` |
| L12 | `keyboardFocus: OnDemand` is needed for any `TextInput` | `#wayland` `#input` |
| L13 | `wpctl` has no per-channel balance, and no workaround | `#cli` `#audio` |
| L14 | `wpctl status` prints no volume for stream entries | `#cli` `#audio` |
| L15 | `wpctl` accepts any object id | `#cli` `#audio` |
| L16 | `nmcli -t` escapes `:` and `\` inside values | `#cli` `#network` |
| L17 | No wifi hardware on this machine | `#machine` `#network` |
| L18 | What is installed, and the session name | `#machine` |
| L19 | No window type exposes `x` or `y` | `#quickshell` `#windowing` |
| L20 | `PopupWindow` is the sole positionable exception | `#quickshell` `#windowing` |
| L21 | `PanelWindow` has `aboveWindows` and `focusable` natively | `#quickshell` `#windowing` |
| L22 | `ShellScreen` exposes the global monitor layout | `#quickshell` `#windowing` `#layout` |
| L23 | Reassigning a `PanelWindow`'s `screen` flickers badly | `#quickshell` `#windowing` |
| L24 | Reparenting an item between windows preserves everything | `#quickshell` `#windowing` |
| L25 | Three monitors, non-rectangular, with real dead zones | `#machine` `#layout` |
| L26 | `mmsg dispatch` can call compositor functions | `#ipc` `#windowing` |
| L27 | `mmsg watch` covers most queries — but not cursor position | `#ipc` `#cursor` |
| L28 | `MANGO_INSTANCE_SIGNATURE` is the IPC socket path | `#ipc` |

---

## QML / Qt Quick

**L1 — a `.qml` file is usable as a type tag only if its filename starts with an uppercase letter.** Underscores after the first character are fine —
`Ui_Probe.qml` resolves as the type `Ui_Probe`. A lowercase file can still be
loaded dynamically by path via `Loader { source: "module_lowercase.qml" }`, but can
never be written as a `<tag>`. `[verified 2026-09-04, quickshell on this machine]`

**L2 — each directory is a separate QML implicit-import scope.** A component in
`modules/` cannot see a component at the repo root without an explicit
`import ".."` at the top of the file. This is a large part of why Nino uses a flat
layout (`D2`). `[inherited]`

**L3 — a plain `Item`'s `width`/`height` do not follow its `implicitWidth`/
`implicitHeight`** the way `Text` or a positioner's children do. An `Item` that
computes a correct implicit size and never sets `width: implicitWidth; height:
implicitHeight` silently renders at 0×0 — no warning, no error. `[inherited]`

**L4 — do not name a property the same as an outer `id` you bind it from.**
`Nino { theme: theme }` where `Nino` declares `property var theme` looks correct
but binds the property to *itself* (always `null`), because the object under
construction is part of the scope chain. Name the outer instance something else
(`themeInstance`). Worse, this once surfaced as a cascade of unrelated-looking
`ReferenceError`s on later lines of the same object — if you see errors on lines
you didn't touch, suspect a real binding error earlier in the same object first.
`[inherited]`

**L5 — `clip: true` is an axis-aligned bounding-box clip only.** It never follows
a `Rectangle`'s rounded outline. A square-cornered fill inside a rounded, clipped
track paints its square corners straight over the rounded ones. The fix is to give
the inner rectangle the same `radius` — a smaller pill nested in a bigger one —
not to rely on clipping. `[inherited]`

## Quickshell

**L6 — a freshly instantiated `Process` does not auto-run** — `running` defaults
to `false`. A `Process` created inside an `Instantiator` delegate needs an explicit
`running: true` in the delegate or it silently never executes. No error, no
warning, no output. `[inherited]`

**L7 — `QtObject` has no default property in this Quickshell version**, so a
`FileView` child inside one fails with "Cannot assign to non-existent default
property". The `.qml` root element has to *be* the `FileView`. `[inherited]`

**L8 — `Array.isArray()` returns `false` on a JSON array read off a `JsonAdapter`
`property var`** — even though it is indexable, has a correct `.length`, and
`.filter()`/`.map()` work on it normally. A validator written as
`if (!Array.isArray(v)) return fallback` therefore discards every real array,
silently, with no warning anywhere. Duck-type instead:
`typeof v.length === "number" && typeof v.filter === "function"`. This one cost a
full debugging session, because every layer checked out fine in isolation.
`[inherited]`

**L9 — `visible: false` stops rendering, not bindings or timers.** A hidden
per-monitor instance keeps polling. This is the reason for `D3`'s
no-`Process`-in-modules rule. `[inherited]`

## Wayland

**L10 — no global cursor position is exposed to a click-through layer-shell surface.** It has to come from the compositor's IPC — here `mmsg get cursorpos`
(`L27`). `[inherited]`

**L11 — an accepted click is exclusively yours.** Wayland has no "handle this
event and also forward it to the surface below". A layer-shell surface that claims
a region to detect click-outside swallows that click from the desktop underneath.
Doing it properly would need synthetic input injection (`ydotool`/`wtype`/
compositor IPC). This is what `D11` is built on. `[inherited]`

**L12 — `WlrLayershell.keyboardFocus: OnDemand`** is needed for any `TextInput` to
receive keys. It only grabs focus when something inside requests it, so it does
not affect click-through, which is a separate mechanism (`mask: Region`).
`[inherited]`

## CLI tools

**L13 — `wpctl` has no per-channel (left/right) balance control, and there is no working workaround via `pw-cli`.** Writing PipeWire's `channelVolumes` directly —
tried against both the node's `Props` and the device's active `Route` param —
succeeds, reads back briefly, then gets silently reverted: WirePlumber owns and
continuously re-asserts volume state for ALSA hardware devices, and a raw `pw-cli`
client loses that fight with no error anywhere. The path that would work is
`pactl set-sink-volume <sink> <L>% <R>%`, which needs `pactl` (not installed).
`[inherited]`

**L14 — `wpctl status`'s "Streams:" table prints no volume for stream entries**,
unlike Sinks/Sources — even though `wpctl get-volume <id>` returns it fine for the
same id. Stream entries also have indented port-link sub-lines beneath them that
match the same `<id>. <name>` shape; filter by indentation depth, and treat the
first blank line as the section boundary. `[inherited]`

**L15 — `wpctl` accepts any object id**, not just a sink/source alias — so per-app
stream control needs no extra dependency. `[inherited]`

**L16 — `nmcli -t` (terse) escapes `:` and `\` inside field values with a leading
`\`.** A plain `split(':')` breaks on any value legitimately containing a colon (an
SSID can). Unescape while splitting. `[inherited]`

## Machine-specific

**L17 — no wifi hardware on this machine.** `nmcli dev wifi list` always returns
empty, which is indistinguishable from "no networks found". Any wifi scan/connect
code can only be checked structurally here, never live. `[inherited]`

**L18 — available and confirmed present:** `quickshell` 0.3.0 (Nixpkgs), `mmsg`.
Session: `WAYLAND_DISPLAY=wayland-0`. `[verified 2026-09-04]`

## Quickshell window types (0.3.0)

**L19 — no window type exposes `x` or `y`.** Checked `WindowInterface` and
`ProxyWindowBase` — every window type inherits one of them — and `FloatingWindow`
itself. The full set is `visible`, `implicitWidth/Height`, `width`, `height`,
`screen`, `color`, `mask`, `devicePixelRatio`, `surfaceFormat`, `updatesEnabled`,
`contentItem`. This is not a Quickshell gap: xdg-shell has no client-side window
positioning by design. A toplevel can only be moved by the compositor.
`[verified 2026-09-04]`

**L20 — `PopupWindow` is the sole exception** — it has `relativeX`/`relativeY`
against a `parentWindow`, plus `grabFocus`. Positioning works because
xdg-positioner allows it, but only relative to a parent, and a popup is bound to
its parent's output. `[verified 2026-09-04]`

**L21 — `PanelWindow` has `aboveWindows` and `focusable` as native properties**,
so always-on-top and focus behaviour need no compositor config. It also has
`anchors`, `margins`, `exclusiveZone`, `exclusionMode`. `[verified 2026-09-04]`

**L22 — `ShellScreen` exposes global `x`, `y`, `width`, `height`** (plus `name`,
`model`, `serialNumber`, densities, orientation). The full multi-monitor layout is
available from Quickshell directly — no compositor IPC needed to build a global
coordinate space. `[verified 2026-09-04]`

**L23 — reassigning a `PanelWindow`'s `screen` property to move it between
monitors flickers badly.** The transition is not smooth — the layer surface is
bound to an output at creation, so this destroys and recreates it. Do not re-test
this. `[observed in the previous iteration by the project author]`

**L24 — a `QQuickItem` can be reparented between two `PanelWindow`s with full
state preservation.** Setting `item.parent = otherWindow.contentItem` moves it
across what are two separate scene graphs, and the item keeps its object identity,
its property values, its running `Timer`s and its bindings — verified by driving a
counter across six moves and confirming the count was continuous (+6 per 1.2s at a
200ms tick, no reset, no skipped ticks). `visible` stays true and the window
attaches. No warnings or errors. This is what makes `D6` viable; the alternative
(a `Loader` per surface) would destroy and recreate the content on every crossing.
`[verified 2026-09-04]`

## This machine's monitor layout

**L25 — three monitors, in a non-rectangular arrangement:**

```
DVI-D-1    x=0     y=180    1440×900
DP-1       x=1440  y=0      1920×1080
HDMI-A-1   x=1440  y=1080   1920×1080
```

Global bounds are 3360×2160, but two regions inside that box are covered by no
monitor: `(0..1440, 0..180)` and `(0..1440, 1080..2160)`.

**Consequence: "which screen contains this global point" can legitimately return
nothing.** Any code mapping a global coordinate to a hosting surface must handle
the empty answer — this is not a defensive-programming nicety, it is reachable in
normal use, since Nino sits at an offset from the cursor and that offset can point
into dead space. Do not develop against a two-monitor rectangular assumption.
`[verified 2026-09-04]`

## Mango IPC (`mmsg`)

**L26 — `mmsg dispatch <func>[,arg...] [client,<id>]` can call compositor
functions**, including `movewin,<x>,<y>` and `togglefloating`, optionally targeting
a specific client id. So compositor-side window movement *is* available — it is a
process spawn per call, not a cheap one. ``[verified 2026-09-04, from `mmsg --help`]``

**L27 — `watch` exists for monitors, clients, tags, keymode, keyboard layout and
devices — but not for cursor position.** `get cursorpos` is one-shot only, so
cursor tracking has to poll. Polling is not a shortcut here; there is no event
source to subscribe to. ``[verified 2026-09-04, from `mmsg --help`]``

**L28 — `MANGO_INSTANCE_SIGNATURE` is the IPC socket path.** A persistent
connection via Quickshell's `Socket` would avoid per-call process spawns, at the
cost of implementing Mango's wire protocol. Not currently needed.
`[verified 2026-09-04]`
