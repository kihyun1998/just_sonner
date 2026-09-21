# Deck reach and cut

## What it is
How far the expanded deck reaches from its edge before its toasts scroll, what
happens past that, and where the deck stops being drawn at **both** of its ends.
Holds the cap, the scroll, the two-ended cut and the scrollbar beside it.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the cap and the scrollbar as
  separate config fields; the newest toast never cut *by the cap*; the cut keyed on
  where toasts are drawn; a fading cut clipping as a hard one does; and the near end.
- [spec §6](../../spec.md#6-layout-and-animation) — the cap, the cut and the scrollbar.

## Design model
The cut has two ends and each is reported from **where toasts were drawn**, never from
whether the scroll overflows — the toasts beyond the window leave the deck the moment
the pointer does, while still fanned out, so a cut keyed on the overflow shows them for
the whole 400 ms collapse. The far end sits at the cap; the near end at the position's
own `offset`, and **the near end needs no cap at all**, since a deck taller than the
layer scrolls with none.

Both ends fade over `DeckCap.fade` — outward at the far end, inward at the near — and
cut hard where there is no fade. The report holds
`near.at <= near.fadeFrom <= far.fadeFrom <= far.at`, so a window shorter than two
fades cannot cross the gradient's stops.

It is a **paint** cut. Hit-testing reads the far end alone.

## Code
`deck_cut.dart` — DeckCutBox, RenderDeckCut
`deck_layout.dart` — DeckCut, DeckCutEnd, DeckScrollbarGeometry, ToastDeckDelegate
`deck_scrollbar.dart` — DeckScrollbarThumb

## Reference behaviour

**None.** sonner draws at most `visibleToasts` whether expanded or not, so it has no
deck that outgrows its space and nothing here to compare against — recorded in
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md)
and cited as such when the cap was decided. The absence is the finding: every value in
this territory was settled by this repo's own measurement.

## Cross-cutting invariants
- [Distances are measured from the position's own edge](../invariant/distances-from-the-positions-edge.md)
- [Drawnness is the key](../invariant/drawnness-is-the-key.md)
- [A clip survives a transform applied outside it](../invariant/a-clip-survives-an-outside-transform.md)
- [A held deck stretches to the layer's edge](../invariant/a-held-deck-stretches-to-the-layer-edge.md)

## Blast radius
- [Deck layout](deck-layout.md) — the cut reads what that territory drew.
- [Backdrop](backdrop.md) — drawn outside this cut with a hard one of its own at both ends.
- [Deck controls](deck-controls.md) — the dismiss-all control sits against the far end
  and is drawn outside the cut so it is not eaten by it.
- [Pointer hold](pointer-hold.md) — the region runs to the far edge's `offset` past the cap.

## Known holes / open
- Whether a `ShaderMask` save layer now appears where none did before — a fading cap
  whose far end is not cut, scrolled past the near edge — is **unmeasured**. The
  backdrop is unaffected: its own cut box never fades.
- Nobody has decided whether a toast cut at the **near** end should stay in the
  semantics tree. It does, following the rule §12 records for the cap, but that rule
  was decided against the cap alone.
