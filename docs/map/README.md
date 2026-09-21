# MAP

A dependency graph over what just_sonner **does**, so two questions have an answer:

| Question | Open |
|---|---|
| **If I touch this, what else moves?** | the territory you are changing, then its `## Blast radius` — it is a checklist, and finding nothing to do in a listed territory is a correct outcome |
| **What design is this derived from, and what decided that design?** | the territory's `## Design model`, then its `## Governing decisions` |

Read it **before** the design is committed, not after the code is written. Write to it
at the end.

## The failure this exists to stop

**#74 → #86.** #74 gave `offset` one inset per edge so a deck could clear an app's own
title bar. Nothing checked that against the scroll path, and #86 is the same clearance
being undone: a wheel turn pushed toasts back over the title bar, because the deck's cut
had only a far end. Two issues, a week apart, on one fact.

The map routes that in one hop. [Configuration](territory/configuration.md) is where
`offset` changed; its blast list names
[Deck reach and cut](territory/deck-reach-and-cut.md), whose design model says the cut
has ends — and both are held by
[Distances are measured from the position's own edge](invariant/distances-from-the-positions-edge.md),
whose *Where it will recur* asks the question #74 never asked.

The same shape sits under [Drawnness is the key](invariant/drawnness-is-the-key.md):
#62 and #67 found it independently in the cut and in the frame scheduler, which do not
call each other, and #86 reused it rather than finding it a third time.

## What was measured

- **35 exported names. 15 of them appear in no decision row at all** — not in a title,
  not in a body. Most are in [Configuration](territory/configuration.md).
- **`DeckStowControl`, `DeckStowHandle` and `DeckStowMotion`** (since #97 `DeckHideControl`
  and `DeckHideMotion`, the handle removed) **are named in one row and
  are the subject of none.** They grep as covered.
- **`host.dart` is 25.5% of `lib/src` and imports 16 of its 21 files.** It is not one
  territory; it is several that the file tree cannot name, which is why these notes are
  cut by behaviour and not by file.
- **A sweep for forward-looking prose found nothing** on the usual phrasings
  (*"lands in"*, *"tracked in"*). Widened, this repo's own idiom turned out to be
  **"Not covered"** — 13 of them, each a live hole inside a decision row. The narrow
  pattern's zero was the pattern being narrow, not the repo being clean.
- **3 open issues against 48 closed.** The catalogue of deliberate absence is not the
  tracker; it is §2's non-goals and those 13 clauses.

## What the map cannot answer

- **Only `.md` files in this repository are nodes.** Issues are not, so the hottest
  things here — #29, #87, #88 — appear as text inside notes and the graph will not draw
  them.
- **The verified external-fact store is on another branch** (`research/sonner-values`),
  so `## Reference behaviour` links out to GitHub rather than to a node. The pin lives
  there and is never restated here.
- **Nothing here is published.** `.pubignore` excludes `/docs/`, so this map is a
  repository artifact and a consumer never sees it.

## Conventions

- **Empty sections stay.** `**None.**` under `## Governing decisions` means nobody
  decided; under `## Reference behaviour`, nobody compared against a reference; under
  `## Code`, nobody built it. They are three different failures and each is greppable.
- **Territories overlap.** A fact holding in three places is an invariant note, not a
  row in whichever territory found it first.
- **Symbols, never line numbers.** A line number is an ungated copy of something the
  compiler owns; `check.py` rejects one.
- **Plain relative links**, not wikilinks — Obsidian resolves both, GitHub only these.

## Coverage, and what an absent note means

This pass covers the whole repository: twelve territories and four invariants, written
together, and [Zone](territory/zone.md) added by #97. It is not a pilot.

**An absent note is a gap, not a correct state** — with one exception. Where an area
exists only as a plan, its roster is the tracker and no note is owed; that is the case
for everything under §2's non-goals, which is deliberate absence rather than
unmapped code. **A note becomes owed the moment a first slice lands under `lib/`.**

One judgement recorded so it is not re-made: *heights are measured after layout* was
considered for promotion to an invariant and **not promoted**. Its discovery history
fills (#45, #72), but the coverage fraction travels down a call chain into the look, so
it is a design-model line in [Deck layout](territory/deck-layout.md) with three readers
rather than a fact unconnected sites arrived at separately.

## The nodes

Territories: [Toast lifetime](territory/toast-lifetime.md) ·
[Deck layout](territory/deck-layout.md) ·
[Deck reach and cut](territory/deck-reach-and-cut.md) ·
[Pointer hold](territory/pointer-hold.md) ·
[Deck controls](territory/deck-controls.md) ·
[Backdrop](territory/backdrop.md) ·
[Swipe](territory/swipe.md) ·
[Zone](territory/zone.md) ·
[Mounting](territory/mounting.md) ·
[Default look](territory/default-look.md) ·
[Configuration](territory/configuration.md) ·
[Publishing](territory/publishing.md) ·
[Example harness](territory/example-harness.md)

Invariants: [Distances are measured from the position's own edge](invariant/distances-from-the-positions-edge.md) ·
[Drawnness is the key](invariant/drawnness-is-the-key.md) ·
[A clip survives a transform applied outside it](invariant/a-clip-survives-an-outside-transform.md) ·
[A held deck stretches to the layer's edge](invariant/a-held-deck-stretches-to-the-layer-edge.md)

## Asking the map instead of storing the answer

```sh
# what exists — the folder is the roster
ls docs/map/territory/ docs/map/invariant/

# the three sentinels, each scoped to its heading: the same string marks all
# three, and an unscoped grep reports a well-governed area as ungoverned
rg -lU '## Governing decisions\r?\n\r?\n\*\*None\.\*\*'   docs/map/territory/
rg -lU '## Reference behaviour\r?\n\r?\n\*\*None\.\*\*'   docs/map/territory/
rg -lU '## Code\r?\n\r?\n\*\*None\.\*\*'                  docs/map/territory/

# the gate: sections, links, anchors, symbols, line numbers, reciprocity
python docs/map/check.py            # every note
python docs/map/check.py <file>     # one, as you finish it
```

`check.py` has been shown to **pass** on known-good input, **fail** on each defect kind
and **ignore** link-shaped text inside code spans and fences; the fixtures that prove it
are `territory/_fixture_*.md`, which the default run skips. Its first version could not
fail on line numbers, because they are written in backticks and the checker blanked
code spans before looking.

## Maintenance

1. **Coverage** — is the territory this change touched in the map, and is its blast
   list still right?
2. **Promotion** — is the fact this fix revealed also true outside this territory? The
   test in this repo's own terms: **does it hold at any site that resolves `offset`, or
   at any site that asks whether a toast is still in the deck?** If yes, the fix does
   not land until an invariant note exists. Ask it at the *first* fix, not the third.

After a refactor-shaped commit, run the symbol half of the gate: the names under
`## Code` are addresses, and a move breaks the address while leaving the claim true.

<!-- grill-map build stamp: 778cb26 -->
