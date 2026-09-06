# CLAUDE.md

Nino is a [Quickshell](https://quickshell.org) (QML) desktop shell for NixOS
running the Mango window manager. A discussion-first rebuild: the contract is
written before the code.

**Read `docs/rulebook.md` first — it governs how the work is done.** Then:

| File | For |
|---|---|
| `docs/Project` | What Nino is, in the author's words. The vision. |
| `docs/architecture.md` | Layers, contracts, the mental model. Start here for any structural question. |
| `docs/decisions.md` | Why each system is shaped that way, and what was rejected. |
| `docs/lore.md` | QML/Wayland/CLI gotchas found by testing. Check before assuming platform behaviour. |

`./run.sh` lists the project's commands.

This file is disposable and may be emptied at any time (`R22`); nothing in the
repository depends on it.

## Start the next session here

**First: `./run.sh check_docs`.** The script was written but never run (`R24`),
so `check_tags` and `check_index` are unverified. Fix whatever it reports before
anything else.

Then slice 1 — `A15`, six files. The contract is written; nothing structural is
outstanding.

Deferred, by name, so they are not rediscovered as surprises:

- **Card controls** — a back button out of a module takeover, and a button to
  disable proximity collapse. The author deferred both; they are slice 3.
- **`Project` line 61** has a leftover word (*"expands click is consumed"*). The
  author's file, so leave it unless asked.
- Adaptive cursor-poll backoff (`A5`), whether a space-reserving bar reserves its
  collapsed or extended height (`D10`), the module interface (slice 4, `D12`).
