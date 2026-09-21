# Default look

## What it is
What a toast draws when the caller supplies no builder: the card, the leading slot, the
title and description, the close button, the action slot and the time left. Also the
seam a builder replaces it through.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the time left's five looks and its
  settings; a covered toast drawing no content; `ToastFit` and `toastCardBuilder`.
- [spec §9](../../spec.md#9-default-look).

## Design model
One default look, with a **builder as the escape hatch** for everything it does not do —
that is §2's split, and it is why there are no semantic toast types. What the default
look *does* draw is configurable where the maintainer asked for it.

A **covered** toast draws no content and its controls are not there to be used, while
its card stays; the look applies that fade to itself rather than leaving it to a
builder, because a builder was handed nothing to decide with and so nothing ever faded.

The time left is the countdown's own number filled in between ticks, never a second
count: it stands still while nothing draws it and comes back on the number.

## Code
`default_look.dart` — DefaultToastLook
`toast_view.dart` — ToastBuilder, ToastSlot
`toast_fit.dart` — ToastFit, toastCardBuilder
`content_fade.dart` — ContentFade
`time_left.dart` — TimeLeftSweep, TimeLeftBorderPainter, TimeLeftBarPainter, TimeLeftRingPainter

## Reference behaviour
sonner fades the children of a collapsed non-front styled toast to zero —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md),
the `styles.css` rows. It settles that the content goes rather than the card, which is
what this repo does; sonner has no time-left drawing at all, so those five looks are
this repo's and were settled from a spike.

## Cross-cutting invariants
- [Drawnness is the key](../invariant/drawnness-is-the-key.md)

## Blast radius
- [Deck layout](deck-layout.md) — coverage and the drawn height come from there, and a
  look that ignores them reports an overflow.
- [Toast lifetime](toast-lifetime.md) — the time left is the countdown's number.
- [Configuration](configuration.md) — every setting here is a config field.

## Known holes / open
- **Not covered**: how a caller's builder with a translucent or rounded surface of its
  own reads over an opaque base.
- `TimeLeftLook`, `TimeLeftStart` and `ToastBuilder` appear in no decision row.
