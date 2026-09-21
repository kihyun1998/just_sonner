# A clip survives a transform applied outside it

## The fact
Whatever bounds the deck must keep bounding it when something **outside** moves or
scales the whole deck. A clip that only holds while the deck stands still is not a
clip; it is a coincidence of the deck's resting position.

## Why it is cross-cutting
The deck's contents are laid out well beyond the layer — a large deck puts its oldest
toasts off screen entirely — and what keeps them out of sight is the bound, not the
screen. Anything that transforms the deck brings that off-screen content back on.

The sites are unconnected by construction: the bound lives in the cut's render object,
the transforms live in the stow motion and in whatever the **app** wraps the host in,
and the backdrop's filter sits outside the cut for a different reason and is caught by
the same fact. None of them calls another; they meet only in the compositor.

## Territories it holds in
- [Deck reach and cut](../territory/deck-reach-and-cut.md) — the clip is this territory's, at both ends.
- [Deck controls](../territory/deck-controls.md) — the stow motion transforms the whole deck.
- [Backdrop](../territory/backdrop.md) — a save layer between the filter and the app defeats the filter.

## What a violation looks like
Nothing at rest, and a flash during a motion: content that is off screen appears for the
first half of a stow and disappears as the motion settles. Or the inverse — a filter that
worked on a short deck draws nothing on a long one, because the layer it was put inside
grew a mask.

## Discovery history
- **#75** — pressing Hide on a deck of 20 with the default fading cap drew roughly
  15,000 px past the cap at 50 and 100 ms under `slide`, and 7,000–12,000 under
  `shrink`; `fade`, which moves nothing, drew none. The fading cut was a mask whose
  rect reached only as far as the box, so content laid out beyond it was never masked.
- **#78** — with the same fading cap a ten-toast deck's stripes kept a contrast of 255
  with the blur on — the blur drew nothing — against 5 with no fade and 5 with no cap.
  A `ShaderMask` is drawn as a save layer and a `BackdropFilter` inside one filters that
  layer rather than the app. `BackdropGroup` did not escape it either.

Two, found three weeks apart, in opposite directions: once content escaped the bound,
once the bound trapped a filter.

## Where it will recur
Any new layer, mask or filter put in the deck's paint path, and any new transform put
around it. The test: **does this survive being translated or scaled by something that
does not know about it?** §12 records that transforms an app puts around the host may
expose the same thing, and that this has **not** been probed.
