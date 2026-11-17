# Deck controls

## What it is
The controls the deck carries past its far end — dismiss-all and hide — and the motion
a hidden zone's deck goes by. Owns where they sit, when they show, and the bar they
share when both ask for one.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the dismiss-all control and its look
  or builder; what it leaves alone; the stow, its motion and its handle, renamed `hide*`
  by #97, which removed the handle; Hide on an empty open zone; each toast re-read as it
  is reached (#129, maintainer); the two sideways hide looks (#141); the reach the deck
  comes back from (#143).
- [spec §6](../../spec.md#6-layout-and-animation).

## Design model
Both sit `gap` past the deck's far end — the cap, on a deck that scrolls — and are
drawn **outside** the cut, so it does not eat them, and laid out **before** the deck so
a builder's size and its place arrive in one frame. The hover region has to take them
in: laid out outside the deck's box, moving the pointer onto one collapsed the deck
before it could be pressed.

A wheel turned over either one moves the deck, which the deck's own `Scrollable` cannot
see from outside its cut: it goes to the deck's scroll position as a wheel over the deck
does, and so glides with the same motion and adds to the same target (#107). A turn with
no vertical part moves nothing, rather than stopping a glide under way.

Dismiss-all leaves toasts that are loading or not dismissible, and counts the ones
beyond the window, because **Dismissible** governs what the *user* may dismiss and this
is the user's control. It reads each toast as it reaches it (#129). Every dismissal notifies,
so a listener can make the next one not dismissible, or dismiss it and show another at its id,
and the list was built before any of that.

Hiding keeps the toasts and their countdowns; what a hidden zone draws is
[Zone](zone.md)'s.

The built-in hide motions are one transform around the whole deck — toasts, controls,
backdrop and scrollbar — inside `DeckHideMotionBox`. A `slide` reads how far the deck
reached from its edge, and `slideLeft` and `slideRight` how far it reached from that side of
the layer to its far side; the host measures all three from the deck's box as it is hidden for
the way out, and from the deck as it is laid out for the way back (#143), and each slide adds
24 px, so the deck ends wholly outside the layer. Only the vertical reach as hidden is on
`DeckHideMotionView`: a builder is handed the position and that reach, and the side reaches
and the way back's reach stay the built-in looks' (#141, #143). The side is the app's and is
never read from the position. The outside scrollbar ends 12 px past the deck, inside the 24 px;
a backdrop padding wider than 24 px is left partly inside the layer at opacity 0, under `slide`
as under the sideways looks. Measuring the way back from the deck as it was hidden brought a
banner on a deck hidden before it was laid out, or while empty, in from an empty box's distance
(#141 measured it). The way out keeps the reach it was hidden with, so a toast leaving
during the hide does not move the rest (114 px drifting to 100 px when read live).

A deck turned before its motion ends goes on from the reach drawn at the turn: an open zone
collapses while it hides, so its live reach parts from the one it was hidden with, and taking the
live one at a banner 150 ms in moved the deck 54 px in one frame. Going out again keeps the drawn
reach; coming back eases from it to the live one in step with the hide value. A turn from wholly
out of sight, or with nothing drawn at the turn, takes the live reach at once. "Nothing drawn" is
read at the turn, not as the zone was hidden: a toast shown and hidden in one frame is drawn by
the time it turns, and reading it at the hide jumped it 420 px. A position on the other edge
assigned while the deck moves keeps the reach drawn then, as before #143: the live reach toward
the new edge is measured while the deck still glides from the old one, and it jumped 208 px.

The reach is set as the deck is built and again as the layout reports the deck and the layer
(`findRenderObject` is not valid in a build), and `DeckHideMotionBox` reads it as it paints and
hit-tests, so no frame draws a reach a frame old. On the way back it follows the deck as it
changes: a toast dismissed during a `reveal()` drifts it (128 px to 114 px), the reading of
"the deck as it comes back" #143 took.

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
- [Hit-testing follows paint](../invariant/hit-testing-follows-paint.md)
- [A notification can re-enter its sender](../invariant/a-notification-can-re-enter-its-sender.md)

## Blast radius
- [Deck reach and cut](deck-reach-and-cut.md) — the far end these sit against is the cap.
- [Pointer hold](pointer-hold.md) — the region must reach them.
- [Deck layout](deck-layout.md) — the box they are placed against is what it drew.
- [Configuration](configuration.md) — every look and builder is a config field.
- [Zone](zone.md) — the hide control's condition reads the zone's state.

## Known holes / open
- **Not covered**: a widget test cannot tell that the control was laid out before the
  deck rather than after, since the layer lays out twice in the frame the pointer arrives.
- `DeckHideControl` and `DeckHideMotion` are named in one §12 row and are the subject of
  none — they grep as covered. `DeckHideMotionLook` is the subject of #141's row.
- **Not covered**: the sideways looks were not seen by eye.
- **Not covered**: a position flipped to the other edge while the deck goes out of sight keeps
  the sign jump it had before #143.
- **Open**: a motion builder's `reach` is still the deck's as the zone was hidden, so a builder
  that slides brings a banner on a zone hidden empty in from the wrong distance; left outside
  #143's confirmed scope.
