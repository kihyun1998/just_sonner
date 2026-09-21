# Pointer hold

## What it is
What counts as the pointer being on the deck, the box it is held by, and what that
hold does: the deck fans out and every timer stops. Owns the hover region's shape,
including the way it stretches while the deck can scroll, and the app's two handles on
it: `held`, which reports the hold, and `expand()`, which fans the deck out without one.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the four things the deck holds while
  a scroll is under way; a deck appearing under a still pointer; a drag of the
  scrollbar carried off the deck.
- [spec §12](../../spec.md#12-decision-record) — the app's expansion (#88): its own
  control, the mechanism in the package and the policy in the app, every toast drawn
  and no pause, `held` and how it is published.
- [spec §6](../../spec.md#6-layout-and-animation), [spec §7](../../spec.md#7-timers).

## Design model
The region is the box around the toasts in the deck, gaps included and cut to the
layer. **While the toasts do not fit and the pointer is on the deck** it is stretched
from the edge to the far edge's `offset` past the cap, so a deck scrolling under a
resting pointer cannot slide out from under it. That stretch is deliberately *not*
applied with no pointer on the deck: it once took the taps in its margins and paused
an `expandByDefault` deck under a pointer resting above every toast.

A pointer counts once it **moves, presses or turns the wheel** there — a toast that
lands under a pointer nobody moved counts down as usual.

**Drawing every toast and following the pointer are two things.** The app's expansion
draws every toast, taking taps, with the controls; only the pointer holds the timers,
stretches the region, shows the scrollbar and keeps a toast anchored. The host draws
itself again when the hold changes, since with the expansion already whole the pointer
arriving moves no animation.

`held` is published from every place the hold changes — a hover, a press, a stow,
another controller, the host's own dispose. Two of those run mid-frame, so a change
there reaches listeners at the frame's end, and never a controller disposed in it.

## Code
`host.dart` — DeckHitBox, _DeckRegion, _RenderDeckRegion, ToastLayer
`controller.dart` — SonnerController, holdDeck, releaseDeck
`deck_layout.dart` — ToastDeckDelegate

## Reference behaviour
sonner expands on pointer enter and pauses its timers there —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md),
the `index.tsx` rows. It settles that hover both expands and pauses; it settles
nothing about a region that stretches, because sonner's deck never scrolls.

## Cross-cutting invariants
- [A held deck stretches to the layer's edge](../invariant/a-held-deck-stretches-to-the-layer-edge.md)
- [Distances are measured from the position's own edge](../invariant/distances-from-the-positions-edge.md)

## Blast radius
- [Deck reach and cut](deck-reach-and-cut.md) — the cut's pointer margin is the same
  distance the region runs past the cap, and hit-testing reads the far end.
- [Toast lifetime](toast-lifetime.md) — the hold is what pauses every countdown.
- [Deck controls](deck-controls.md) — the region must take in the controls past the
  far end, or moving the pointer onto one collapses the deck before it can be pressed.
- [Swipe](swipe.md) — a press that stays put is a pointer over the deck; only a toast
  being dragged holds the timers.

## Known holes / open
- **Not covered** by any decision: a deck gliding past a resting pointer elsewhere on
  screen, which would expand and pause it mid-glide. Not measured.
- Touch is outside v0.1, so nothing here says how a deck expands without hover; an app
  can call `expand()`, which is the nearest thing.
- **Not covered**: several hosts on one controller. `held` is true while any of them
  holds, and a host redraws on its own hold, but no test puts two hosts on one
  controller — they are a non-goal.
