# Backdrop

## What it is
What is drawn behind the deck while it is fanned out — a blur of what the app painted
and a cover over it — fading in and out with the expansion, so a collapsed deck has none. Null by
default, so an app that does not ask for it is unchanged.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the backdrop's own file; and its being
  drawn outside the deck's cut with a hard cut of its own, placed at paint rather than
  at layout.
- [spec §12](../../spec.md#12-decision-record) — the blur at a fixed sigma, its opacity
  following the expansion, and the warm-up deferred (#142, the maintainer's).
- [spec §6](../../spec.md#6-layout-and-animation).

## Design model
It is drawn **under** the toasts and **outside** the deck's cut, with a hard cut of its
own at the same places. That is not tidiness: a fading cut is a `ShaderMask`, the engine
draws a `ShaderMask` as a save layer, and a `BackdropFilter` inside one filters that
fresh transparent layer rather than the app. Inside the deck's cut the blur drew nothing
on exactly the deck sizes it was added for.

The blur's sigma is `blur` whenever it is drawn; an `Opacity` over the filter is what
follows the expansion. A sigma that followed it walked through every value from 0 to
`blur` on each open, and each value the engine had not drawn yet cost a slow raster frame
on the first opens after launch. The `Opacity` sits inside the backdrop's own clip, and
that clip stays a plain one, never `antiAliasWithSaveLayer`: a save layer that trapped the
filter there would undo the reason the backdrop is drawn outside the deck's cut. An `Opacity` is a save layer too, yet it does not trap the
filter the way a `ShaderMask` does: probed in flutter_test's rasterizer, sigma 4 over
24 px stripes blurred all 100 rows at opacity 1.0, 0.99 and 0.5, and none under a
`ShaderMask`. So "a save layer traps the filter" holds for the `ShaderMask`, and has not
been measured for other save layers, a save-layer clip among them.

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
- The fixed sigma was measured on one Windows GPU (#146): Flutter 3.41.9 profile builds,
  1280x800, a throwaway app opening and closing the zone by code, 3 fresh launches each.
  Against the ramp it ended the slow first close (8 toasts: 13-18 ms max raster, against
  40-455), the opacity changing each frame brought no slow frames in the second and third
  opens, and the `Opacity` layer over a fanned-out deck cost nothing in median raster (about
  1 ms either way). The first open still has 1-5 raster frames over 16.7 ms, and so does a
  deck with no backdrop (1-3), so most of it is not the blur's. An app-side warm-up (a 120 px
  `Opacity` 0.5 over a rounded `BackdropFilter` of sigma 4, 300 ms at startup) changed
  nothing with no toast and took the 8-toast first open from 2-5 slow frames to 2, which the
  noise between launches covers. **No warm-up** is the maintainer's call on that (#146).
  The backend, Skia or Impeller, was not identified, and one machine is not a survey.
