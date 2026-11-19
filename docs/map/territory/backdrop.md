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
  following the expansion, and the warm-up deferred (#142, the maintainer's), then refused
  (#146), then added as an app call (#168, the maintainer's).
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

The first open after launch is slow because the backdrop, the card and the deck's layout
are all drawn for the first time then, not because of anything the backdrop does each frame.
`warmUp()` does that first draw ahead of time: it draws the real deck once, fanned out, under
the app's screen ([Mounting](mounting.md) holds where). The deck it draws is built from the controller's
config, so it runs with no backdrop too. An app-side blur alone (#146) moved nothing that the
noise between launches did not cover. The warm-up draws the whole deck, and that is what the
#168 triage measured: the first open went from 1–2 slow frames to 0–1 with one toast.

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
  noise between launches covers. **No warm-up** was the maintainer's call on that (#146),
  reversed by #168 on a re-measure (Flutter 3.44.8, same machine and method). The real deck drawn
  under the app's opaque screen took the first open, as slow frames : longest ms per launch, from
  2:37 1:31 2:39 to 0:11 1:19 0:15 with one toast, and from 4:48 6:87 5:40 to 2:58 1:19 0:16 with
  eight. The cost moves to startup, 1–3 slow frames of 22–56 ms. With eight toasts, slow frames
  remain after a one-card warm-up.
  The backend, Skia or Impeller, was not identified, and one machine is not a survey.
- **Not covered**: the first open with the package's own `warmUp()` on a real GPU. The numbers
  above are the triage's app-side stand-in for it.
