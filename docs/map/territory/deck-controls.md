# Deck controls

## What it is
The controls the deck carries past its far end — dismiss-all and hide — and the motion
a hidden zone's deck goes by. Owns where they sit, when they show, and the bar they
share when both ask for one.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the dismiss-all control and its look
  or builder; what it leaves alone; the stow, its motion and its handle, renamed `hide*`
  by #97, which removed the handle; Hide on an empty open zone.
- [spec §6](../../spec.md#6-layout-and-animation).

## Design model
Both sit `gap` past the deck's far end — the cap, on a deck that scrolls — and are
drawn **outside** the cut, so it does not eat them, and laid out **before** the deck so
a builder's size and its place arrive in one frame. The hover region has to take them
in: laid out outside the deck's box, moving the pointer onto one collapsed the deck
before it could be pressed.

Dismiss-all leaves toasts that are loading or not dismissible, and counts the ones
beyond the window, because **Dismissible** governs what the *user* may dismiss and this
is the user's control.

Hiding keeps the toasts and their countdowns; what a hidden zone draws is
[Zone](zone.md)'s.

Both show while the pointer holds the deck **or the zone is open**, and neither on a
hidden deck. The hide control also shows on an open zone with **no** toast, past the
empty card, so an empty zone can be put away without the app.

## Code
`look/deck_dismiss_all.dart` — DeckDismissAllButton, DeckLayers, DeckLayerSlot, RenderDeckLayers
`look/deck_hide.dart` — DeckHideMotionBox, DeckHideButton, DeckFarEndBar, DeckBarButton, farEndControls
`dismiss_all_view.dart` — DeckDismissAllView, DeckDismissAllBuilder
`hide_view.dart` — DeckHideView, DeckHideMotionView

## Reference behaviour

**None.** sonner has no clear-all control and no hide —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md)
records the absence. Every value here was settled from spikes in the example app.

## Cross-cutting invariants
- [A clip survives a transform applied outside it](../invariant/a-clip-survives-an-outside-transform.md)
- [Distances are measured from the position's own edge](../invariant/distances-from-the-positions-edge.md)
- [A held deck stretches to the layer's edge](../invariant/a-held-deck-stretches-to-the-layer-edge.md)

## Blast radius
- [Deck reach and cut](deck-reach-and-cut.md) — the far end these sit against is the cap.
- [Pointer hold](pointer-hold.md) — the region must reach them.
- [Deck layout](deck-layout.md) — the box they are placed against is what it drew.
- [Configuration](configuration.md) — every look and builder is a config field.
- [Zone](zone.md) — the hide control's condition reads the zone's state.

## Known holes / open
- **Not covered**: a widget test cannot tell that the control was laid out before the
  deck rather than after, since the layer lays out twice in the frame the pointer arrives.
- The hide types (`DeckHideControl`, `DeckHideMotion`) are named in one §12 row and are
  the subject of none — they grep as covered.
