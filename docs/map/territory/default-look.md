# Default look

## What it is
What a toast draws when the caller supplies no builder: the card, the leading slot, the
title and description, the close button, the action slot and the time left. Also the
seam a builder replaces it through.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the time left's five looks and its
  settings; a covered toast drawing no content; `ToastFit` and `toastCardBuilder`.
- [spec §9](../../spec.md#9-default-look), and the §12 row settling its values as they
  shipped (#29).
- [spec §12](../../spec.md#12-decision-record) — update and replace fading the new content
  in over an opaque old (#21), and `ContentChange` setting a builder's change instead
  (#157).

## Design model
One default look, with a **builder as the escape hatch** for everything it does not do —
that is §2's split, and it is why there are no semantic toast types. What the default
look *does* draw is configurable where the maintainer asked for it.

A **covered** toast draws no content and its controls are not there to be used, while
its card stays; the look applies that fade to itself rather than leaving it to a
builder, because a builder was handed nothing to decide with and so nothing ever faded.

A **change of content** fades the new in over the old in `ContentFade`. The default look
always takes #21's fade: the old stays opaque, since its own card is opaque and a
cross-fade dips it. A builder's content takes `config.contentChange`, because only the
builder knows how see-through its card is; the old layer's opacity is
`(1 − t) / (1 − α·t)`, which keeps two layers of a card of α covering as one, and at α = 1
the base is handed `kAlwaysCompleteAnimation` rather than the curve, so the default is
the fade a builder had before #157, unchanged. Which fade a change takes is decided by
the look drawing the **new** content. The builder's key changes only for new content — a new state or
builder — and not while `keep` is on, so the `Builder` element updates in place and
`ContentFade` never sees a new child; a config change alone, turning `keep` on or off
included, never changes it. `keep` also fades over zero, which covers the one change it
cannot keep an element across, a replace from the default look. A zero duration needs
no case of its own: `AnimationController.forward` on a zero duration reports `completed`
in the same call, and the status listener drops the base before the frame is built.

The time left is the countdown's own number filled in between ticks, never a second
count: it stands still while nothing draws it and comes back on the number.

## Code
`look/default_look.dart` — DefaultToastLook
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
- **Not covered**: how a caller's builder with a **rounded** surface of its own reads
  over the base. A translucent one is settled by `ContentChange` (#157); a `cardOpacity`
  that does not match the card the builder draws reads as the mismatch it is.
- A change arriving mid-fade makes the half-faded content the base at full opacity: the
  card's coverage holds at every α, but the content steps — how much of each layer's text
  shows through the card above it goes 0.5 → 1 for the half-faded and 0.5 → 0 for the
  dropped base at a switch halfway — as it did before #157. Removing the
  step needs a third layer.
- `TimeLeftLook`, `TimeLeftStart` and `ToastBuilder` appear in no decision row.
