# Deck layout

## What it is
Where every toast in the deck is put, in both of the deck's states and through the
motion between them. Collapsed, the front toast is drawn in full and the rest peek
out behind it; expanded, they fan into a list. This territory owns the arithmetic —
depth, lift, coverage, the blended height a toast is laid out at — and nothing about
how far the deck reaches, which is [Deck reach and cut](deck-reach-and-cut.md).

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the rows on the deck's offsets and
  scales, on a toast's position moving only toward its place, and on a toast behind a
  shorter front being laid out at the height it is drawn at.
- [spec §6](../../spec.md#6-layout-and-animation) — Collapsed and Expanded.

## Design model
A toast's place is counted from the **presence** of the toasts in front of it rather
than from its index, so offsets, scales, the window fade and drawn heights all move
with a toast entering or leaving. A position only ever moves *toward* its place and
stops there: a toast entering over 400 ms and one leaving over 200 ms run on different
clocks, and letting positions move both ways would carry the deck forward and back for
no net change.

**Heights are measured after layout**, and a toast behind a shorter front is laid out
at the height it is drawn at rather than clipped to it. That fact holds here, in
[Default look](default-look.md) and in `ToastFit`, but it is **not** promoted to an
invariant: the coverage fraction travels down a call chain (`ToastView.covered` is
handed to the look), so it is a design-model line with three readers, not a fact two
unconnected sites arrived at separately.

## Code
`deck_layout.dart` — ToastDeckDelegate, ToastHeight, RenderToastHeight
`toast_fit.dart` — ToastFit, RenderToastFit, ClipsOverflow
`host.dart` — ToastLayer

## Reference behaviour
sonner sets `height: var(--front-toast-height)` on the toast element itself, so its
border box shrinks and nothing is cut —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md),
the `styles.css` rows. It settles that laying a toast out at the drawn height, rather
than clipping it, is the prior art; this repo diverges by keeping a clip as a backstop
for a builder that uses neither `ToastFit` nor `toastCardBuilder`.

## Cross-cutting invariants
- [Distances are measured from the position's own edge](../invariant/distances-from-the-positions-edge.md)

## Blast radius
- [Deck reach and cut](deck-reach-and-cut.md) — the cut is reported from where this
  territory drew the toasts, so any change to placement moves both ends of it.
- [Pointer hold](pointer-hold.md) — the hover region is the box around what was placed.
- [Default look](default-look.md) — coverage is handed to the look, which fades content by it.
- [Deck controls](deck-controls.md) — the dismiss-all control is placed against the
  deck's far end, which comes from this layout.

## Known holes / open
- The heights rule is read from the source and from §12's rows; no reference
  comparison covers the blend itself.
- §12 records that a builder using neither `ToastFit` nor `toastCardBuilder` reports
  an overflow in debug when it sits behind a shorter front, and that a look whose card
  and content are one widget it does not own — flash's `FlashBar` through the example's
  adapter — has nowhere to put `ToastFit`. The maintainer put that out of scope.
