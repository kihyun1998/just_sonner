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
- [spec §12](../../spec.md#12-decision-record) — `wheelMotion` as the package's own
  `WheelMotion`, re-exported (#110).
- [spec §12](../../spec.md#12-decision-record) — `enterMotion` and its `ToastEnterMotion`
  (#141).
- [spec §12](../../spec.md#12-decision-record) — `contentChange` and its `ContentChange`
  (#157).
- [spec §12](../../spec.md#12-decision-record) — `motionDurations` and its `MotionDurations`
  (#162): the maintainer's row (all six motions, one `Duration` each, no curve) and the
  derived one (the names, zero allowed, a running motion keeping its duration, the
  couplings kept).
- [spec §4](../../spec.md#4-api).

## Design model
A field is assigned, not rebuilt: changing one keeps the toasts on screen where they
are. Nullable fields are given through a getter in `copyWith`, since null is a value
they can take — `duration` among them since #97, where null keeps every toast shown
without a duration until it is dismissed.

`wheelMotion` is the one field whose type is not this package's: `WheelMotion` from
`flutter_smooth_wheel_scroll`, re-exported so an app sets it without listing the package
itself. A breaking change to that type is a breaking change here. The host hands it to the
deck's scroll controller on every config it follows, so it reaches the next wheel turn; a
config assigned while toasts are on screen also starts them gliding to it, so a wheel turned
in that glide is drawn through it. A `WheelMotion` compares by value (from the package's
0.1.5, #118), so a config rebuilt with an equal motion is equal and the host does not follow
it again. A curve motion compares its curve with the curve's own `==`: the `Curves` constants
are equal, two separately built `Cubic`s are not.

`enterMotion` names a side as `left` or `right` and never reads `position`, so a centered
position needs no rule of its own; `edge` is the one value that follows the position. The
side is physical, as `offset`'s edges are: a right-to-left app's `left` is still the left.

`contentChange` is read by a builder's content only; the default look has no setting for
how its content changes. Its `duration` is checked by the controller, as `duration` and
`visibleToasts` are, since a `Duration` cannot be compared in a const constructor.

`motionDurations` times the deck's six motions and nothing else: enter, exit, expand,
glide, spring back and hide. Each duration drives what the host's constant drove before
#162, couplings included — enter also moves the toasts behind and fades the empty card,
exit also takes a swiped toast out and closes the gap, expand also fades the toasts beyond
the window and eases the scroll back to the edge. Curves, the scrollbar's linger and fade,
the content-change resize, the time-left ease and the timer tick stay fixed. The host reads
a duration from the controller's config as it **starts** a motion, so one already running
keeps the duration it started with: an `AnimationController` keeps its simulation when its `duration` changes, and
`_Eased` and `_Sprung` build a `_Progress` per motion. A config assignment's own glide is
started after the host takes the new config, so it runs on the assigned config's glide.
The durations are checked by the controller, as `contentChange.duration` is. Zero is
allowed. A zero `forward()` completes inside the call, so `_enter` adds the listener that marks
a toast arrived before it starts the enter. `_Progress` answers 1 from the start for a zero duration rather than computing
`0 / 0`. The NaN that division gives would have worked too, since `AnimationController`
clamps it with `clampDouble`, which returns the upper bound for NaN — so no test can tell
the guard is there (every test in `host_test.dart`'s zero group passes without it); it is kept so a zero duration
does not rest on that.

`offset` is an `EdgeInsets` of **physical** edges. The edge the position names holds the
deck off it and measures `DeckCap.pixels`, the scroll track and the scrollbar from it;
the opposite one is where the expanded deck stops. A centered position reads neither
left nor right.

## Code
`config.dart` — SonnerConfig, DeckCap, DeckScrollbar, DeckBackdrop, DeckDismissAll, DeckHideControl, DeckHideMotion, ZoneEmpty, ToastTimeLeft, ContentChange, MotionDurations, SonnerPosition, ToastEnterMotion

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
- [Deck layout](deck-layout.md), [Swipe](swipe.md), [Zone](zone.md),
  [Deck reach and cut](deck-reach-and-cut.md), [Toast lifetime](toast-lifetime.md) —
  `motionDurations` times their motions, and a note there that states a duration states
  the default.
- [Publishing](publishing.md) — a change to a field's shape is a breaking release.

## Known holes / open
- `DeckScrollbarPlacement`, `DeckDismissAllLook`, `DeckHideLook` and the four builder
  typedefs appear in **no** decision row. At the map's build 15 of the 35 exported names
  were ungoverned, and most of them are here; `DeckHideMotionLook` has been the subject of
  a row since #141, which added it `slideLeft` and `slideRight`.
