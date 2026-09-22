# Distances are measured from the position's own edge

## The fact
Every distance the deck is laid out by is measured from **the edge the position names**
— `offset.top` for a top position, `offset.bottom` for a bottom one — and every
distance that stops it is measured from the **opposite** edge. A site that reads
`offset` as one number, or reads the wrong one of the two, is wrong by the difference
between the two insets and correct whenever they happen to be equal.

## Why it is cross-cutting
`offset` became an `EdgeInsets` of physical edges, and the two insets a deck is measured
along are derived per position rather than passed down. Each site resolves them for
itself — the layout for a toast's distance, the cut for both of its ends, the scrollbar
for its track, the empty card for its place. **They do not
call each other**, so there is no chain along which a fix propagates: each reads the
config and decides again.

## Territories it holds in
- [Deck layout](../territory/deck-layout.md) — each toast's distance from the edge.
- [Deck reach and cut](../territory/deck-reach-and-cut.md) — the near end, `DeckCap.pixels`, and the scrollbar's track.
- [Deck controls](../territory/deck-controls.md) — the far end the controls sit against.
- [Zone](../territory/zone.md) — the empty card sits at the near edge's `offset`, where the front toast would.
- [Configuration](../territory/configuration.md) — where the two insets are derived.

## What a violation looks like
The deck sits right with `EdgeInsets.all(n)` and wrong the moment two insets differ —
off by exactly their difference. Because the common test config uses equal insets, the
whole suite can pass with the wrong inset read: mutating `nearOffset` to `farOffset` in
the cut's report reddens **one** test out of 409, the one written with
`EdgeInsets.only(bottom: 30, top: 50)`.

## Discovery history
- **#74** — an app with its own 60 px title bar wanted the deck 68 from the top and 16
  from the right. One number held it off every edge alike, so clearing the title bar
  pushed it 68 off the right as well. That issue's body enumerates every site that
  reads `offset`, which is this invariant's site list in its first form.
- **#86** — a scroll took the clearance back: toasts pushed past the top `offset` went
  on being painted over the title bar, because the cut had only a far end. The fix had
  to resolve the near inset itself, and the test that pins *which* inset is read is the
  only one in the suite that can tell.

Two sites, found a year apart in project time, neither reachable from the other.

## Where it will recur
Any new site that positions something against the deck's edge — a control, an
indicator, a second scrollbar, an animation's start box. The test: **does this code
read `offset` at all?** If yes, it has to say which of the two edges it means, and it
needs a case with unequal insets or nothing will catch it being wrong.
