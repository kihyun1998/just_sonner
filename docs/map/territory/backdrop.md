# Backdrop

## What it is
What is drawn behind the deck while it is fanned out — a blur of what the app painted
and a cover over it — following the expansion, so a collapsed deck has none. Null by
default, so an app that does not ask for it is unchanged.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the backdrop's own file; and its being
  drawn outside the deck's cut with a hard cut of its own, placed at paint rather than
  at layout.
- [spec §6](../../spec.md#6-layout-and-animation).

## Design model
It is drawn **under** the toasts and **outside** the deck's cut, with a hard cut of its
own at the same places. That is not tidiness: a fading cut is a `ShaderMask`, the engine
draws a `ShaderMask` as a save layer, and a `BackdropFilter` inside one filters that
fresh transparent layer rather than the app. Inside the deck's cut the blur drew nothing
on exactly the deck sizes it was added for.

Its box is read at **paint**, not at layout — the deck reports its box while it lays
out, so a builder on it would schedule a build mid-frame.

It takes no pointer: a click in the `padding` it reaches into goes to the app.

It never reaches nearer the edge than `offset`, scrolled or not. The box it follows is
the deck's drawn box, and the deck's near cut exists only once a toast is pushed past
the offset — so before a scroll nothing stops its `padding` at the offset. It carries a
hard cut of its own at `nearOffset` for that; the `padding` gives way to it.

## Code
`look/deck_backdrop.dart` — DeckBackdropBox
`config.dart` — DeckBackdrop
`deck_cut.dart` — DeckCutBox

## Reference behaviour

**None.** sonner has no backdrop —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md)
holds nothing on it. The defaults were settled by feel in the example app.

## Cross-cutting invariants
- [A clip survives a transform applied outside it](../invariant/a-clip-survives-an-outside-transform.md)
- [Hit-testing follows paint](../invariant/hit-testing-follows-paint.md)

## Blast radius
- [Deck reach and cut](deck-reach-and-cut.md) — the backdrop's own cut is taken from the
  same report, so both of its ends move when that one does.
- [Deck layout](deck-layout.md) — its box is the deck's box.
- [Configuration](configuration.md) — every field is on `DeckBackdrop`.

## Known holes / open
- A `BackdropFilter` costs about **2.4x a frame's whole raster cost** on the deck it was
  measured against, and 84% of that is there at sigma 2 — the layer costs, not the blur.
  The numbers come from the software rasterizer, so what transfers is the structure.
