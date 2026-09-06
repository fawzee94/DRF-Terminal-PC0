# Decision log

Append-only. One entry per decision about how a system is put together.
Newest at the bottom. Never rewrite an entry — supersede it with a new one and
mark the old one `Superseded by Dn`.

Format: what we chose, why, and what we rejected. The rejected column is the
valuable one — it stops us relitigating the same choice in three weeks.

## Tags

Fixed vocabulary (`R20`). A new tag is added here by hand before it is used.

`#process` `#docs` `#tooling` `#layout` `#modules` `#services` `#config`
`#windowing` `#position` `#state` `#input`

## Index

| ID | Decision | Tags |
|---|---|---|
| D1 | Rebuild from scratch; `Ninab` is reference only | `#process` `#docs` |
| D2 | Flat file layout; layer encoded in the filename prefix | `#layout` `#modules` |
| D3 | Dependencies point one way only | `#layout` `#services` `#modules` |
| D4 | A module's config name is its identity | `#modules` `#config` |
| D5 | Four documents, four jobs | `#docs` |
| D6 | Surfaces per monitor, exactly one content instance | `#windowing` `#position` |
| D7 | Off-monitor targets slide along the edge | `#position` `#windowing` |
| D8 | A fifth document: the rulebook | `#docs` `#process` |
| D9 | One config file, instances by id, resolved slice injected | `#config` `#modules` |
| D10 | Two axes, not four states: base × extent | `#state` `#position` `#windowing` |
| D11 | The card collapses by distance, not by an outside click | `#state` `#input` |
| D12 | Three module views; the widget view is sized by its host | `#modules` |
| D13 | Indexed docs, a portable rulebook, and `run.sh` | `#docs` `#tooling` `#process` |

---

## D1 — Rebuild from scratch; the old `Ninab` code is reference only
**Date:** 2026-09-04 · **Status:** active

A previous iteration (`Ninab`, 20 files / 3,385 lines) exists in git at commit
`abded3f`. It works, and it got as far as a module system, cursor following and
multi-monitor handoff.

**Decision:** We do not restore or port it. No file is copied. Every file in Nino
is written from a contract agreed in advance. The one thing we harvest is its
tested findings, which are recorded in `lore.md` with their provenance marked.

**Why:** The goal is an owned mental model, not working code — working code
already exists. Porting would mean reverse-engineering assumptions instead of
choosing them.

**Rejected:**
- *Restore and refactor in place.* Fastest to something running, but the model
  would be recovered from the code rather than driving it, which is the exact
  failure being corrected.
- *Harvest files opportunistically per slice.* Risks importing old assumptions
  unexamined at precisely the moments we're moving fastest.

---

## D2 — Flat file layout; the layer is encoded in the filename prefix
**Date:** 2026-09-04 · **Status:** active

**Decision:** All QML lives in one directory. No subfolders. Only `docs/` exists
as a subfolder, and it holds no code. A file's architectural layer is carried by
an uppercase prefix:

| Prefix | Layer | Job |
|---|---|---|
| *(none)* | L0 | `Config.qml`, `Theme.qml` — data, one of each, depends on nothing |
| `Service_` | L1 | The only code permitted to talk to the OS. No UI. |
| `Shell_` | L2 | Layer-shell windows, shared identity state, module hosting |
| `Ui_` | L3 | Dumb presentation primitives. No data, no services. |
| `Module_` | L4 | Composed views. See Theme + services; never the OS. |

`shell.qml` is the entry point (`quickshell -p shell.qml`) and sits outside the
scheme by convention.

**Why:** Directory nesting in QML is not free — each directory is a separate
implicit-import scope, so a component in `modules/` cannot see a component at the
root without an explicit `import ".."`. That bit the previous iteration. One flat
directory means one scope and zero imports between our own components. The prefix
recovers the only thing the folders were giving us: visible grouping.

Config and Theme stay unprefixed because there is exactly one of each; a prefix
implies a family.

**Rejected:**
- *Numbered prefixes* (`L0_`, `L1_`…), which would sort the dependency direction
  directly into the file listing. Rejected as harder to read at a glance and
  painful if a layer ever needs to be inserted between two others.
- *Prefixing Config and Theme too.* Uniform, but adds a category name for a
  category with one member each.

**Consequence accepted:** in a flat directory every capitalised file is a
globally visible type in one namespace, so a user-dropped `Module_Spotify.qml`
shares that namespace with core code. The prefix convention is what keeps this
safe — it is load-bearing, not cosmetic.

---

## D3 — Dependencies point one way only
**Date:** 2026-09-04 · **Status:** active

**Decision:** A file may only depend on files in a *lower* layer. Data is injected
downward; events travel upward as signals. Two rules with teeth:

1. **A module may never spawn a `Process`.** If a module needs data from the
   system, that data gets a service.
2. **A `Ui_` component never reads `Theme` or a service.** It receives plain
   values as properties. This is what makes it reusable.

**Why:** The previous iteration's modules each owned their own polling, and
`Variants { model: Quickshell.screens }` instantiates one module copy per monitor.
Every copy independently re-ran the same `wpctl` / `nmcli` / `ping` calls,
including on monitors that were not visible — `visible: false` stops rendering,
not timers and bindings. Centralising OS access is a performance fix before it is
an architecture preference.

**Rejected:** *One `System.qml` owning all OS access.* The previous iteration did
this and it worked, but it grew to 571 lines covering cursor, audio and network in
one object. Right instinct, wrong granularity — we split it per domain
(`Service_Cursor`, `Service_Audio`, `Service_Network`) so the rule survives growth.

---

## D4 — A module's config name is its identity
**Date:** 2026-09-04 · **Status:** active

**Decision:** Config names a module in PascalCase — `pillModules: ["Clock",
"Volume"]` — and the host resolves it to the path `"Module_" + name + ".qml"`.
No case transformation anywhere.

**Why:** Verified today that `Loader { source: "..." }` resolves a plain path
regardless of filename case, so any convention would technically work. Choosing
one where the config string is *literally* the filename's distinguishing part
means there is no mapping function to get wrong, and a user reading an error
message sees the same token in the config and on disk.

**Rejected:** *Lowercase config names* (`["clock"]` → `Module_Clock.qml`), as the
previous iteration used. Requires a capitalisation step, which is one more place
for a mismatch to hide.

---

## D5 — Four documents, four jobs
**Date:** 2026-09-04 · **Status:** active

**Decision:** Split project knowledge across `docs/Project` (vision),
`docs/architecture.md` (mental model and contracts), `docs/decisions.md` (this
file), and `docs/lore.md` (tested platform gotchas). `CLAUDE.md` stays thin and
points at them.

**Why:** The previous iteration had one 120-line `CLAUDE.md` holding all four,
which made it unreadable and unmaintainable — vision, contracts and debugging war
stories interleaved, none findable. These four have different change rates and
different readers.

**Rejected:** *One `ARCHITECTURE.md`.* Simpler, but lore grows without bound and
would swamp the contracts, which is exactly what happened before.

---

## D6 — Layer-shell surfaces per monitor, but exactly one content instance
**Date:** 2026-09-04 · **Status:** active

**Decision:** One `PanelWindow` per screen via `Variants { model: Quickshell.screens }`,
each covering its whole output, transparent, with `mask` limited to Nino's own
bounds. But **only one Nino content instance exists**, hosted by whichever
surface currently contains it.

Nino's position is computed in a **global coordinate space** built from
`ShellScreen.x/y/width/height`, then mapped into the hosting surface's local
coordinates. Movement math therefore never knows about monitors — it works in one
continuous plane, exactly as `docs/Project` asks for.

**Why:** This gets the decisive win of the single-window approaches — one instance
of everything, so the "one Nino" shared-identity problem largely stops existing
rather than being managed — without leaving layer-shell. Module duplication across
monitors, the performance bug behind `D3`, disappears with it. Moving within a
monitor costs nothing: it is an `Item` changing `x`/`y`, not a window operation.

**Rejected — a real toplevel window (`FloatingWindow`) moved by the compositor.**
This was seriously considered, and its wins were real: free monitor crossing, free
focus and drag-and-drop, one window by construction. Killed by evidence:

- **No Quickshell window type exposes `x`/`y`.** Verified against
  `WindowInterface`, `ProxyWindowBase` and `FloatingWindow` — you get `width`,
  `height`, `screen`, `mask`, `color`, `visible` and nothing else. That is the
  protocol, not a Quickshell gap: xdg-shell has no client-side positioning by
  design.
- So *every* position update would go through
  `mmsg dispatch movewin,X,Y client,<id>` — a `fork` + `exec` + socket round-trip
  per frame, permanently, with motion quantised to the spawn rate.
- `PanelWindow` already has `aboveWindows` and `focusable` natively, so the
  always-on-top argument for toplevels evaporates — layer-shell gets it with no
  compositor config at all.
- A toplevel is a real window: it appears in alt-tab and window lists, and Nino's
  own planned MangoWindows module would list Nino itself. Suppressing that needs
  per-compositor `windowrule` config, pushing system-specificity *outward* into
  the user's WM setup — the opposite of `Project`'s goal.
- Behaviour under fullscreen windows becomes compositor-dependent, where
  layer-shell handles it by layer ordering.

**Rejected — one `PanelWindow` with a reassigned `screen` property.** Directly
observed to flicker badly on monitor transitions in the previous iteration. See
`lore.md`.

**Rejected — one content instance per surface (the previous iteration's design).**
Known to work, but it is the source of both the shared-state bugs and the
per-monitor polling duplication. `D6` is that design with the duplication removed.

**Mechanism — resolved same day.** The content instance moves by reparenting:
`content.parent = targetWindow.contentItem`. Verified to preserve object identity,
property values, running `Timer`s and bindings across separate scene graphs, with
no warnings (see `lore.md`). The `Loader`-per-surface fallback is not needed, and
would have been materially worse — it destroys and recreates the content on every
crossing, losing scroll position, expansion state and any text being typed.

---

## D7 — Off-monitor targets slide along the edge
**Date:** 2026-09-04 · **Status:** active

Nino's ideal position is the cursor plus a configured angle and distance, so it is
regularly outside every monitor — with the cursor near a top edge and any upward
offset, always. On this machine's layout there are also genuine dead zones inside
the global bounds (`lore.md`). This is a constant case, not an edge case.

**Decision:** one uniform path, applied to every position, with no special cases:

1. Pick the screen whose rectangle is at **minimum distance** from the ideal point.
   A screen containing the point is at distance 0, so it wins automatically — the
   normal case needs no separate branch.
2. **Clamp Nino's whole rectangle** inside that screen.

Nino therefore holds its configured offset wherever it fits and slides along the
screen edge where it does not.

**Why:** It keeps Nino continuously visible and its motion continuous — no jumps,
nothing clipped, nothing hidden. Running step 2 unconditionally also means the
ordinary "point is on-screen but the rectangle overhangs the edge" case falls out
of the same code, rather than being a second rule to keep in sync.

**Rejected:**
- *Flip to the opposite side*, tooltip-style. Preserves the full configured
  distance, but the pill snaps across the cursor, which is a large discontinuity
  in a thing whose whole identity is smooth following.
- *Always host on the cursor's screen, clamped there.* Most predictable, and the
  simplest rule. Rejected because it forbids Nino from leading the cursor onto the
  next monitor, making crossings feel like Nino lags behind rather than travels.
- *Let it hide.* Least code, but Nino disappears near every screen edge.

---

## D8 — A fifth document: the rulebook
**Date:** 2026-09-05 · **Status:** active · **Extends D5** · **Extended by D13**

**Decision:** `docs/rulebook.md` joins the four documents of `D5`. It holds how
the *work* is done — the contract-before-code gate, whose call a decision is, how
evidence is graded, what gets verified before it is claimed, and how the other
documents are maintained. `D5`'s split is otherwise unchanged.

**Why:** The working method was being re-established from `CLAUDE.md` prose each
session, which meant it drifted. It is a contract like any other here, so it gets
written down like any other, and amended in the open when a rule fails rather than
quietly dropped.

`CLAUDE.md` keeps a short summary and points at it, on the same principle that
keeps the other four thin.

**Rejected:** *Leaving it in `CLAUDE.md`.* That is what `D5` already rejected for
the other three — one file holding four jobs becomes unreadable, and the rules
that matter most are the ones that get skimmed.

---

## D9 — One config file, instances keyed by id, the resolved slice injected down
**Date:** 2026-09-05 · **Status:** active

`Project` asks for several Nino instances, each with its own id and its own
settings. There is still exactly one `config.json` and one `Config.qml`; instances
are keyed by id inside it.

**Decision:** three parts.

1. `Config.qml` stays a singleton over `config.json`. It holds the global keys and
   an `instances` map keyed by id.
2. A `ConfigInstance.qml` is instantiated **once per Nino**, resolves its id
   against that map, and exposes the validated `readonly` layer for that instance
   alone.
3. **A file may read `Config` directly only for values identical across every
   Nino** — poll intervals, theme path. Anything per-instance arrives as a
   property, injected from its host. A module receives its own settings block and
   never learns that ids exist.

**Why:** QML lexical scope does not cross file boundaries — a separate `.qml` file
cannot see an `id` declared in the file that instantiated it. `Module_Clock.qml`
therefore *cannot* discover which Nino it belongs to on its own. Something must be
handed down regardless; the only real question was what.

Handing down the resolved slice rather than the id means the id match happens in
exactly one place, and reading another instance's settings by mistake becomes
structurally impossible instead of merely discouraged. It also keeps modules
unaware of multi-instancing entirely, which is what lets a user write one.

`ConfigInstance` as a type, rather than a function on `Config` returning a plain
object, keeps validation **declarative**: fallbacks are ordinary bindings that
re-evaluate when the file reloads, instead of a JS routine that has to be
re-invoked by hand on every external edit. `Project` promises that a bad value
falls back rather than crashes, and this is what keeps that promise cheap as the
config grows.

**Rejected:**
- *Inject the id, look up per consumer* (`Config.forInstance(ninoId).clock`).
  Every consumer repeats the lookup, and every consumer is able to address a
  different instance's settings — a class of bug with nothing structural stopping
  it.
- *One config file per instance.* Keeps instances trivially separate, but the
  user now maintains N files that mostly repeat each other, and global values have
  no home.

**Consequence accepted:** `ConfigInstance.qml` is a second unprefixed L0 type,
which dents `D2`'s "unprefixed because there is exactly one of each". Accepted:
it is one *type* with N instances, which is a different thing from a family of
types, and `Config_` as a prefix would falsely imply a layer.

---

## D10 — Two axes, not four states: base × extent
**Date:** 2026-09-05 · **Status:** active

`Project` describes a pill, a card and a bar. The bar has a fixed screen position,
does not follow the cursor, and when expanded its card stays anchored too.

**Decision:** these are not three peer states. There are two independent axes:

| | **compact** | **card** | **takeover** |
|---|---|---|---|
| **pill** — cursor-relative | follows | follows, expanded | follows, one module |
| **bar** — screen-anchored | anchored strip | anchored, expanded | anchored, one module |

The **base** (pill / bar) decides where Nino is and how it moves. The **extent**
(compact / card / takeover) decides what is inside it. Every cell is reachable and
means something.

**Why:** it is the literal form of `Project`'s requirement that all of these "feel
like the same thing that changes shape and/or content" — one axis *is* shape and
position, the other *is* content. It also makes the collapse rule fall out for
free: collapsing moves left along the row you are already in, so "collapses back
into a pill or bar" needs no remembered origin.

The bar still consumes `Service_Cursor` — for proximity reveal rather than for
position — so the cursor drives something in every cell, and `Shell_Stage`'s
contract (`ninoX` / `ninoY` / `hostScreen`) is unchanged by the bar's existence.
Only what computes those values differs.

**Rejected:**
- *Bar as a swappable positioner rather than a state.* Cheaper — the state machine
  would stay pill ↔ card ↔ takeover. Rejected because the bar's behaviour differs
  in more than position: no following, proximity reveal, an anchored card, and
  optional space reservation. That is a state, not a coordinate source.
- *Four flat states.* Loses the fact that "expanded" means the same thing on both
  bases, and would duplicate the card's entire definition per base.

**Consequences, both deferred to slice 3:**
- **Space reservation is opt-in, default off** (author's call). A reserving bar
  cannot live on the shared surface: a `PanelWindow` covering a whole output and
  masked to Nino's bounds has no meaningful `exclusiveZone`, since the zone derives
  from anchors and a window anchored on all four sides has no edge to reserve
  against. That instance needs its own edge-anchored window — which in exchange
  needs no mask and, being screen-bound, never uses the reparenting path of `D6`.
- Whether a reserving bar reserves its collapsed or its extended height is open.

---

## D11 — The card collapses by distance, not by an outside click
**Date:** 2026-09-05 · **Status:** active

**Decision:** the card collapses when the cursor strays beyond a configured
distance from it. Clicking elsewhere on the desktop does not collapse it. A pin
button suppresses the distance collapse.

**Why:** click-outside-to-dismiss is not implementable without stealing the click.
Wayland has no "handle this event and also forward it to the surface below" — an
accepted event is exclusively yours (`lore.md`). A surface claiming a region in
order to notice clicks outside the card swallows those clicks from the application
underneath, so the first click after opening a card would be eaten. The previous
iteration hit exactly this and arrived at the same answer.

Recorded even though it is no longer contentious: without the reason written down,
"why isn't this click-to-dismiss like every other popup" is guaranteed to be asked
again, and the answer is not guessable from the code.

**Rejected:**
- *Synthetic input injection* (`ydotool` / `wtype` / compositor IPC) to replay the
  swallowed click. Technically possible, adds a hard dependency outside Quickshell,
  and replays the click at a moment the compositor did not choose.
- *A short grace period where clicks pass through.* Still swallows the click that
  matters, only less predictably.

---

## D12 — Three module views; the widget view is sized by its host
**Date:** 2026-09-05 · **Status:** active

An earlier draft of `Project` had four views — icon, mini-widget, widget, card —
where mini-widget was a compact rendering of the same content as widget.

**Decision:** three views: **ICON**, **WIDGET**, **CARD**. A module declares a
minimum height for its widget view; the **host** decides the height it can grant,
and a host that cannot meet the minimum shows ICON instead.

**Why:** mini-widget and widget were one view under a size constraint, not two
views, and a four-view contract makes every future module pay for the distinction.

More importantly it turns the author's rule — *full-size widgets belong in the
card overview only* — into a mechanism instead of documentation. The pill and the
bar cannot grant a full row's height, so they can never show a full-size widget,
by construction. Nothing has to be remembered or policed.

**Rejected:** *Keeping MINI-WIDGET as a fourth view.* Justified only if a compact
widget is a genuinely different composition rather than the same one smaller. If a
module ever needs that, it is what the ICON view is for.

**Scope:** the view set is fixed here because it changes `Project`. The mechanism —
how a module declares the minimum, how the host queries it — is slice 4's contract
and is not decided yet.

---

## D13 — Documents are indexed and tagged; the rulebook is portable; `run.sh` holds the commands
**Date:** 2026-09-05 · **Status:** active · **Extends D8**

Three changes to how the documents themselves work.

**Decision 1 — every entry has an ID and tags.** `architecture.md`,
`decisions.md`, `lore.md` and `rulebook.md` each carry an append-only ID series
(`A1..`, `D1..`, `L1..`, `R1..`), never renumbered, plus a fixed tag vocabulary and
an index of `ID | title | tags` at the top. IDs are citable from code comments and
across documents; tags make an entry findable by keyword. `Project` is exempt.

**Decision 2 — the rulebook is project-agnostic.** It names no project, no
platform and no `D`-number. It is portable as-is, and carries instructions for
bootstrapping a fresh `docs/` folder from itself alone (`R25`). Project-specific
rules live in the other four documents (`R19`).

**Decision 3 — a `run.sh` at the repo root** hosts frequently used and
project-testing commands as named functions, invoked `./run.sh <function> [args]`.
Its rules are `R24`.

**Why:**

1. Readability first — the author's stated reason. IDs also make code comments
   able to point at a rationale instead of restating it (`R14`), and the tag list
   is a cheap index for finding the relevant entry without reading the document.
   The vocabulary is *fixed* because free-form tags drift into synonyms
   (`#ipc` / `#mmsg`) and stop being an index. `run.sh` reports unlisted tags;
   adding one stays a human act, or "fixed" means nothing.
2. A permission prompt reading `./run.sh verify_shell 5` is reviewable at a glance,
   where a wall of piped commands is not. The cost is real and accepted: allowing
   the script allows every function in it, which is why a function is added in one
   turn and used in a later one, and why nothing privileged or destructive may live
   inside it.

**Rejected:**
- *Free-form tags.* Cheaper to write, but a tag set nobody maintains is not
  searchable, which was the entire point.
- *A second document for project-specific working rules.* Would duplicate what
  `architecture.md` and `decisions.md` already hold (`R19`).
- *Keeping ad-hoc commands in chat only.* Readable in the moment, gone by the next
  session, and it leaves no debugging tool behind.

**Consequence accepted:** the rulebook now diverges per project unless the author
syncs it. That is deliberate — syncing or forking is their call, not automatic.
