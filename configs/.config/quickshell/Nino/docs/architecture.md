# Architecture

The mental model: what the layers are, what may depend on what, and the contract
each system exposes to the others.

**This file describes only what has been decided.** Sections marked `NOT YET
DECIDED` are deliberate holes — they get filled when we discuss that slice, not
before. If code exists that isn't described here, that's a bug in our process.

Rationale for these choices lives in `decisions.md`, referenced as `D1`, `D2`, …

---

## Tags

Fixed vocabulary (`R20`). A new tag is added here by hand before it is used.

`#layout` `#modules` `#services` `#config` `#theme` `#windowing` `#position`
`#state` `#cursor` `#input` `#tooling`

## Index

| ID | Section | Tags |
|---|---|---|
| A1 | The layers, and the three rules with teeth | `#layout` `#modules` `#services` |
| A2 | File naming | `#layout` |
| A3 | The global coordinate space | `#position` `#windowing` |
| A4 | Contract — Config → everything | `#config` |
| A5 | Contract — Service_Cursor → Stage | `#services` `#cursor` |
| A6 | Contract — Stage → Surface | `#position` `#windowing` |
| A7 | Contract — Shell → Module | `#modules` |
| A8 | Contract — Theme → Module / Ui | `#theme` |
| A9 | Cursor tracking | `#services` `#cursor` |
| A10 | Hosting: one content instance per Nino | `#windowing` |
| A11 | Fitting: keeping Nino on an actual monitor | `#position` `#windowing` |
| A12 | Movement | `#position` |
| A13 | States: two axes, not four | `#state` `#input` `#position` |
| A14 | Modules | `#modules` |
| A15 | Build order | `#layout` |
| A16 | Running and verifying | `#tooling` |

---

## A1 — The layers

Dependencies point **down only**. Data is injected downward, events travel
upward as signals. (`D3`)

```
   L4  Module_*      composed views. know Theme + services. never touch the OS.
        │
   L3   Ui_*         dumb presentation. plain properties in, signals out.
        │            never reads Theme, never reads a service.
   L2   Shell_*      layer-shell windows, shared identity state, module hosting.
        │            knows about screens. owns "which one is the real Nino".
   L1   Service_*    the ONLY code that talks to the OS. no UI whatsoever.
        │            one file per domain.
   L0   Config       plain data. depends on nothing at all.
        ConfigInstance
        Theme
```

`shell.qml` is the entry point and sits above L2: it instantiates the services
and the per-screen surfaces, and wires them together. It is the only file allowed
to know about everything.

### Three rules with teeth

1. **A `Module_*` may never spawn a `Process`.** If a module needs system data,
   that data gets a `Service_*`. Not negotiable — this is a performance rule as
   much as an architectural one, because Quickshell instantiates one copy of each
   module *per monitor*. (`D3`)

2. **A `Ui_*` never reads `Theme` or a service.** It takes plain values as
   properties. A `Ui_Slider` that reads `Theme` directly is not reusable and is
   not a `Ui_` component. (`D3`)

3. **A file may read `Config` directly only for values that are identical across
   every Nino.** Per-instance values arrive as properties, injected from the host.
   There are several Ninos; a file that reaches for a global to find out about
   itself has already picked the wrong one. (`D9`)

## A2 — File naming

One flat directory. Layer carried by an uppercase prefix. (`D2`)

```
shell.qml            entry point
Config.qml           L0   one, over config.json
ConfigInstance.qml   L0   one per Nino
Theme.qml            L0
Service_Cursor.qml   L1
Shell_Surface.qml    L2
Ui_Slider.qml        L3
Module_Clock.qml     L4
```

A file is usable as a QML type tag only if its filename begins with an uppercase
letter; underscores after that are fine. Verified — see `lore.md`.


## A3 — The global coordinate space

The single most important idea in Nino's structure. (`D6`)

Every monitor's position and size is available from `ShellScreen.x/y/width/height`,
so all monitors together form **one continuous plane**. `mmsg get cursorpos`
reports the cursor in that same plane — verified, no translation needed.

**All position math happens in that plane.** Nothing that computes where Nino
should be ever knows about monitors, screen edges, or surfaces. A global point is
converted to a surface and a local position at exactly one place, as the very last
step (`Shell_Stage` → `Shell_Surface`).

The plane is **not** a filled rectangle. On this machine two regions inside the
global bounds have no monitor at all, so "which screen contains this point" can
return nothing — routinely, not rarely (see `lore.md`). See "Fitting" below.


---
# Contracts

## A4 — Config → everything
`Config.qml` is a `FileView` reading `config.json` through a `JsonAdapter`.
Missing file is written with defaults; a wrong-typed value logs and keeps the
declared default; external edits live-reload.

There are several Ninos, each with an id (`Project`), so the file has two kinds of
key: **global** ones, and an `instances` map keyed by id. (`D9`)

```
Config              global keys + instances map        one, ever
  └─ ConfigInstance validated readonly view of one id  one per Nino
```

**Consumers never read the adapter directly.** The validated `readonly property`
layer — which also rejects values that parse fine but are nonsensical, like
negative distances and out-of-range angles — lives on `ConfigInstance` for
per-instance keys and on `Config` for global ones. Never `Config.adapter.foo`.

**Below the instance root, nothing knows that ids exist.** `ConfigInstance`
resolves its id once; everything under it receives the values it needs as
properties. A module is handed its own settings block and could not name another
instance if it tried. This is rule 3 above.

Config only ever grows a key when a slice actually uses it. No placeholder keys.

## A5 — Service_Cursor → Stage
```
readonly property real x          global cursor position
readonly property real y
readonly property string monitor  name of the monitor the cursor is on
readonly property bool  valid     false until the first successful read
```
Polls `mmsg get cursorpos` on a `Timer` at `Config.cursorPollIntervalMs`, parsing
`{"x":float,"y":float,"monitor":string}`. Values are floats, not ints.

Nothing else. No smoothing, no velocity, no prediction — those are movement
concerns and belong to slice 2, not to the thing that reads the OS.

> **NOT YET DECIDED:** adaptive poll backoff while the cursor is idle, and gating
> polling on whether Nino is following at all. Both are real wins the previous
> iteration measured, but they are optimisations — deferred until the naive
> version is running and its cost is known.

## A6 — Stage → Surface
```
readonly property real   ninoX          global, already fitted
readonly property real   ninoY
readonly property string hostScreen     name of the screen that must host Nino
```
`Shell_Stage` publishes a global point and the name of the screen responsible for
drawing it. It holds no reference to any surface and cannot address one.

Each `Shell_Surface` watches for **its own name** and claims the content when it
matches, positioning it at `global − screenOrigin`. Only one surface can match, so
no arbitration is needed and there is no registry of surfaces anywhere.

## A7 — Shell → Module
A module offers three views: **ICON**, **WIDGET**, **CARD**. The widget view
declares a minimum height; the host grants a height, and a host that cannot meet
the minimum shows ICON instead — which is why a full-size widget can never appear
in a pill or a bar. (`D12`)

> **NOT YET DECIDED.** Everything else. How a module declares that minimum, how
> the host asks, and what else crosses the boundary is slice 4's contract.

## A8 — Theme → Module / Ui
> **NOT YET DECIDED.** Slice 3.


---
# Systems

## A9 — Cursor tracking
Wayland does not expose a global cursor position to a click-through layer-shell
surface. Mango's IPC client `mmsg` does (`mmsg get cursorpos`), and it must be
polled — `mmsg` has a streaming `watch` mode for several queries, but *not* for
cursor position. Polling is not a shortcut here; there is no event source to
subscribe to.

## A10 — Hosting: one content instance per Nino, many surfaces
One `PanelWindow` per screen — not per Nino — each covering its whole output,
transparent, with `mask` limited to the bounds of whichever Ninos it is currently
hosting so everything else clicks through. Each Nino has **exactly one content
instance**, reparented to whichever surface its stage names
(`content.parent = surface.contentItem`).

Reparenting across surfaces is verified to preserve object identity, property
values, running timers and bindings (`lore.md`), so a monitor crossing costs
nothing and loses nothing.

This is why the "one Nino" identity problem barely exists here: state like
`following`, `expanded` and `pinned` lives *in that content instance*, so there is
nothing to mirror between monitors and nothing to bubble back up. The only
genuinely shared value is which screen is currently hosting, and that is derived
from the cursor, not stored. (`D6`)

Several Ninos change none of that: `D6` is what makes each one whole, and `D9` is
what keeps them from reading each other's settings. They share the surfaces and
the services; they share no state.

## A11 — Fitting: keeping Nino on an actual monitor
Nino's ideal position — cursor plus a configured angle and distance — is regularly
outside every monitor. This is common, not exceptional: any upward offset with the
cursor near a top edge does it, and this machine's layout has genuine dead zones.

The rule is one uniform path, applied to every position with no special cases
(`D7`):

1. Pick the **best screen** for the ideal point: the one whose rectangle is at
   minimum distance from it. A screen containing the point is at distance 0 and
   therefore wins automatically.
2. **Clamp Nino's whole rectangle** inside that screen.

Because step 2 runs unconditionally, it also handles the ordinary case of a point
that *is* on a screen but whose rectangle overhangs the edge. One code path covers
dead zones, screen edges and overhang alike.

A bar-based Nino is anchored to a named screen, so its ideal point is on a monitor
by construction and both steps are no-ops. Fitting is not a special case for it —
it is the same path, satisfied trivially. (`D10`)

## A12 — Movement
> **NOT YET DECIDED.** Slice 2. Slice 1 deliberately teleports — position is
> assigned, not animated — so that the fitting and hosting logic can be judged
> without easing hiding anything.

## A13 — States: two axes, not four states
Nino is not three peer things. It is one thing positioned by its **base** and
filled by its **extent** — which is what makes a pill, a bar and a card feel like
the same object changing shape and content. (`D10`)

| | **compact** | **card** | **takeover** |
|---|---|---|---|
| **pill** — cursor-relative | follows | follows, expanded | follows, one module |
| **bar** — screen-anchored | anchored strip | anchored, expanded | anchored, one module |

The base decides *where and how it moves*; the extent decides *what is inside*.
Collapsing moves left along the row you are already in, so "collapses back to a
pill or a bar" needs no remembered origin.

The bar still reads `Service_Cursor` — for proximity reveal rather than for
position — so the `Stage → Surface` contract above is unchanged by its existence.
Only what computes `ninoX`/`ninoY` differs per base.

> **NOT YET DECIDED.** Slice 3: the transitions themselves, the pin, the follow
> toggle, proximity reveal, and space reservation. Reservation is opt-in and off by
> default; when on, that instance needs its own edge-anchored window rather than
> the shared masked surface, because a window anchored on all four sides has no
> edge to reserve against (`D10`).

## A14 — Modules
> **NOT YET DECIDED.** Slices 4–5. The view set is fixed at three (`D12`); the
> interface that delivers them is not.


## A15 — Build order

Riskiest and most load-bearing first. The mouse-following spine is what makes
Nino *Nino*; everything after it is a conventional bar.

| # | Slice | Proves |
|---|---|---|
| 0 | Docs skeleton | *(done)* |
| 1 | **Spine** — one surface per monitor, a cursor service, a plain rectangle that follows across screens | config loading, service injection, shared identity state, monitor handoff |
| 2 | **Kinematics** — leash, angle, delay, speed, acceleration as an isolated model | movement is a real model, not an ad-hoc animation |
| 3 | **States** — base (pill/bar) × extent (compact/card/takeover), pin, follow toggle, proximity reveal, optional space reservation | transitions are enumerable, not emergent from scattered booleans |
| 4 | **Module contract** — the interface plus one trivial module (Clock, icon only) | the contract holds before there are modules depending on it |
| 5 | **Module views** — widget mode and card takeover | |
| 6 | **Services** — audio and network as separate services | `D3`'s split survives a real second and third domain |
| 7 | Real modules — Mango windows, Mango layout, volume | |

Slice 1 deliberately carries no theme, no modules and no card. It exists to force
the four hardest structural questions into the open while nothing else is in the
way to hide them.


## A16 — Running and verifying

There is no build step, package manifest, linter or test suite — Quickshell reads
the QML directly.

```sh
./run.sh verify_shell [seconds]   # launch briefly, report warnings and errors
./run.sh check_docs               # tags and indexes across these documents
./run.sh                          # list everything
```

`verify_shell` puts real overlay windows on the live Wayland session, so it runs
under a short timeout, and its log goes to a file first — piping `quickshell`
straight into `grep` swallows the output when the timeout fires (`L27` neighbours
this in spirit; the specific gotcha is noted in `run.sh`).

A clean log means a clean log. Anything visual still needs looking at (`R12`).

*How* the work is sequenced — discuss, contract, implement, verify, record — is
`rulebook.md`, not here (`R19`).
