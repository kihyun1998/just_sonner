# A held deck stretches to the layer's edge

## The fact
While the deck can scroll **and** the pointer is holding it, the deck's box is
deliberately stretched from the layer's edge to the far edge's `offset` past the cap —
wider than the toasts in it — so that scrolling cannot slide the deck out from under a
pointer resting in a margin. The stretch is conditional on the pointer: with none on the
deck the margins belong to the app.

## Why it is cross-cutting
It is a single box read by several questions that otherwise have nothing to do with each
other: whether the pointer is still on the deck, whether a click reaches the app, and
whether the timers stay paused. A change to any of the three that reasons only about its
own question will get the other two wrong.

It also acts as a **constraint from outside** on territories that would otherwise be
free: it is the reason a paint change may not touch hit-testing.

## Territories it holds in
- [Pointer hold](../territory/pointer-hold.md) — the region is the stretched box.
- [Deck reach and cut](../territory/deck-reach-and-cut.md) — hit-testing reads the far end plus that margin, and reads the near end not at all.
- [Swipe](../territory/swipe.md) — a press that stays put is a pointer over the deck, not a drag.
- [Deck controls](../territory/deck-controls.md) — the controls past the far end must fall inside it.

## What a violation looks like
The deck collapses while the user is reading it: the pointer has not moved, but the
content under it has, and the box stopped covering where the pointer is. Or the
opposite — an `expandByDefault` deck with nobody near it eats the clicks in its margins
and pauses under a pointer resting above every toast.

## Discovery history
- **#41** — found by an adversarial pass. A pointer resting in the far margin at y = 10
  was left outside the region as the scroll brought the oldest toast to 24, collapsing
  the deck. A second pass over the fix found the inverse: the full-length region was
  being applied with no pointer on the deck, so a 800 x 220 window with three 5 s toasts
  took `taps=0` at y = 5 and the toasts were still alive after 8 s.
- **#86** — the near end of the cut was made **paint-only** because of this row. A click
  in the `offset` band does not reach the app before a scroll either, so changing the
  pointer there would have undone the stretch without anyone noticing it had been a
  decision.

Two, and the second is the more useful kind: the fact stopped a change rather than
explaining a bug.

## Where it will recur
Any change that makes the deck's box and the deck's paint disagree — a new cut, a new
control outside the toasts, a new reason to clip. The test: **am I about to make
hit-testing follow paint?** If so, this row says why it does not, and the answer is a
decision to take to a person rather than a consistency to restore.
