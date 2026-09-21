# Swipe

## What it is
Dragging a toast off the screen to dismiss it: which ways out a position allows, what
a drag the other way does, and how a drag shares the pointer with the deck's scroll.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the swipe's directions, damping and
  threshold; and the rows on a drag holding the timers.
- [spec §8](../../spec.md#8-swipe).

## Design model
The ways out come from the position's own words unless `swipeDirections` names them —
`bottomRight` takes down and right, `topCenter` up only. Every drag the toast will not
leave on is **damped rather than blocked**, on either axis — one where neither way is
allowed included — and one let go short of the threshold springs back. An empty set
lets no swipe dismiss and still damps the drag; `dismissible: false` is what takes the
drag away.

A two-finger trackpad pan scrolls the deck rather than swiping a toast; a mouse drag on
a toast swipes rather than scrolling. Only a toast **being dragged** holds the timers —
a press that merely stays put is a pointer over the deck, which [Pointer hold](pointer-hold.md) owns.

## Code
`swipe.dart` — SwipeDrag, SwipeStep
`config.dart` — SwipeDirection, SonnerPosition

## Reference behaviour
sonner takes a swipe on its own axis and has a threshold and a damped wrong-way drag —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md),
the `index.tsx` rows. It settles the damping and the spring-back shape; the per-position
direction sets are this repo's, since sonner's toaster has one axis. So is the axis where
neither way is allowed: sonner leaves it still, and this repo damps it (#87).

## Cross-cutting invariants
- [A held deck stretches to the layer's edge](../invariant/a-held-deck-stretches-to-the-layer-edge.md)

## Blast radius
- [Pointer hold](pointer-hold.md) — the gesture arena is shared with the deck's scroll
  and with what counts as the pointer being on the deck.
- [Deck reach and cut](deck-reach-and-cut.md) — a vertical swipe and a vertical scroll
  compete on the same axis for a deck that scrolls.
- [Toast lifetime](toast-lifetime.md) — a completed swipe dismisses.

## Known holes / open
- **Not covered**: a builder with its own drag recognizer on default devices, and
  whether a physical trackpad click-drag reaches the swipe.
- **Not covered**: the touch equivalent — touch is outside v0.1.
- **Not covered**: a top deck, where flash's dismissal meets the other scroll direction.
