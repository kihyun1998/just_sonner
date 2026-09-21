# Configuration

## What it is
`SonnerConfig` and the rules a live config field brings: what is config-wide, what a
single `show` can override, and what happens to toasts on screen when a field changes.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — `offset` as an `EdgeInsets`, one inset
  per physical edge; the time left being config-only; the cap and scrollbar as separate
  fields; and the rules each live field brings.
- [spec §12](../../spec.md#12-decision-record) — `duration` nullable, and
  `SonnerConfig.configDuration` (#97).
- [spec §4](../../spec.md#4-api).

## Design model
A field is assigned, not rebuilt: changing one keeps the toasts on screen where they
are. Nullable fields are given through a getter in `copyWith`, since null is a value
they can take — `duration` among them since #97, where null keeps every toast shown
without a duration until it is dismissed.

`offset` is an `EdgeInsets` of **physical** edges. The edge the position names holds the
deck off it and measures `DeckCap.pixels`, the scroll track and the scrollbar from it;
the opposite one is where the expanded deck stops. A centered position reads neither
left nor right.

## Code
`config.dart` — SonnerConfig, DeckCap, DeckScrollbar, DeckBackdrop, DeckDismissAll, DeckStowControl, DeckStowMotion, DeckStowHandle, ToastTimeLeft, SonnerPosition

## Reference behaviour
sonner's `offset` takes a number or an object of `top`/`right`/`bottom`/`left`, and its
centered toaster reads neither left nor right —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md).
It settles the shape and the centered case. This repo **diverges on a missing edge**:
sonner fills it with its 24 px default, while `EdgeInsets.only` leaves it at 0.

## Cross-cutting invariants
- [Distances are measured from the position's own edge](../invariant/distances-from-the-positions-edge.md)

## Blast radius
- [Deck layout](deck-layout.md), [Deck reach and cut](deck-reach-and-cut.md),
  [Pointer hold](pointer-hold.md), [Deck controls](deck-controls.md) — every one of
  them reads `offset`, and which inset each reads was derived rather than asked.
- [Default look](default-look.md) — its settings are fields here.
- [Publishing](publishing.md) — a change to a field's shape is a breaking release.

## Known holes / open
- `DeckScrollbarPlacement`, `DeckDismissAllLook`, `DeckStowLook`, `DeckStowMotionLook`
  and the four builder typedefs appear in **no** decision row — 15 of the 35 exported
  names are ungoverned, and most of them are here.
