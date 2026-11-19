# Mounting

## What it is
How the host gets into the tree and where the toasts are drawn relative to the app's
own routes, dialogs and overlays. Two modes, and the z-order rule that follows.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the mounting rows, including the
  z-order rule rewritten on the corrected overlay premise.
- [spec §12](../../spec.md#12-decision-record) — the `warmUp()` rows (#168): its deck under
  the host's child in mode 2, and nothing in mode 1 (the maintainer's).
- [spec §5](../../spec.md#5-mounting).

## Design model
**Wrapped**: `SonnerHost` in `MaterialApp.builder` sits above the app's `Navigator` for
the life of the app. **Attached**: the controller is given a navigator key and the
toasts are drawn in the root navigator's overlay, above its dialogs and pages, from the
first toast shown or the zone first opened — or from `attach` itself, when a toast is
alive or the zone open.

The difference is not cosmetic and it reaches the caller's widgets: wrapped, a widget in
a slot finds no `Navigator` and no `Overlay`, so a `Tooltip` throws. `attach` may be
called before the app is built; once attached, a toast with no navigator to draw in is
an error in debug and dropped in release.

Attached, the toasts are moved to the top of the overlay by every `show`, by `open()`
on a zone that was not open, and by the app's `raise()`. An entry another package
inserts after them covers them until one of those runs: `Overlay` has no insertion hook,
so the package cannot follow it, and `raise()` is how the app says it inserted one.
`raise()` moves only a host already inserted. Before the first `show` or `open()`
since `attach`, with nothing alive and the zone not open, nothing is drawn to cover, and
the one that comes inserts on top, so `raise()` never puts the host into an overlay for
the first time. A host whose overlay
was replaced by state restoration is put into the new one, as a `show` would put it,
since those toasts were drawn. Wrapped, `raise()` does nothing: the host is above the
`Navigator`, and no entry of the root overlay reaches it.

`attach` to another key removes the old entry, and `detach` removes it altogether. A
later `attach` — another key, or any key after `detach` — inserts the new entry at once
when there is something to draw, so the toasts on screen are not left undrawn until the
next `show` (#152). "Something to draw" is a live toast or an open zone: those are what
`ToastLayer` draws. A hidden zone's banner needs a live toast shown since it was hidden,
so a live toast already covers it, and the pointer's hold that keeps a banner up after
they have gone ends when the old host is disposed. A hidden zone with toasts alive is
inserted, as a `show` while hidden inserts it. A first `attach` with toasts
already alive inserts the same way, since after `detach` the controller is in the state
of one never attached; the maintainer kept that neighbour once shown it after the change. During a build the insert waits for the
end of the frame, as every insert does; with no navigator built under the key it does
nothing and the next `show` inserts. It watches the lifecycle as it inserts, as a `show`
does, since a host inserted while the app is hidden is not built and its toasts would
count down unseen. Checking for a navigator reads the binding; debug `attach` already
did, through the root assert, so only release reads it newly, and only with something to
draw. The entry is built anew in the new overlay: State, and an exit under way, stay
with the old one.

**The warm-up's deck is mode 2's only, and it goes under the child.** `SonnerHost` is one
`Stack` of three children that never changes shape — the warm-up slot, the child, the toasts'
layer — so the app's screen keeps its element whether a warm-up runs or not, and the warm-up deck
paints first, under the app's opaque screen. That placement is the one the #168 triage measured to
keep its effect: off the window it gave none, and under `Opacity` 0.01 it was erratic. Mode 1 has no
such place. "Below every route" needs an entry to `insert` or `rearrange` below, `OverlayState`
keeps `_entries` private, and no public API lists a navigator's routes, so `warmUp()` does nothing
once attached. The maintainer chose that over an app-given placement and over a private
element-tree lookup. That also leaves out the triage's "no navigator yet: wait and try once".

The deck is driven by a package-private controller, not the app's, so nothing the app reads
moves: `count`, `isAlive`, `zone.state`, the listeners, the timers, the lifecycle watch. The
triage's own measurement had exactly this shape, a second controller's `SonnerHost`. Under
`MaterialApp.builder` the route's opaque box already takes every press over it, and the navigator
keeps a screen reader off it. The deck still carries `IgnorePointer`, `ExcludeSemantics` and
`ExcludeFocus`, because a host whose child lets presses through, or is not a route, reaches it:
the tests put the host inside the page to see each guard fail.

## Code
`controller.dart` — SonnerController
`root_overlay.dart` — RootOverlayMount
`host.dart` — SonnerHost, ToastLayer
`warm_up.dart` — WarmUpRun, WarmUpDeck

## Reference behaviour
sonner mounts one `<Toaster/>` and has no second mode — its equivalent question does not
arise, and
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md)
holds nothing that settles the overlay premise. The premise was corrected against the
Flutter SDK's own `Overlay` source instead.

## Cross-cutting invariants

**None.** Nothing in this territory shares an assumption with another one; its facts
stop at the boundary where the layer is created.

## Blast radius
- [Toast lifetime](toast-lifetime.md) — a `show` with nowhere to draw is this
  territory's failure, and the controller's behaviour there is that one's.
- [Deck layout](deck-layout.md) — the layer's size is what every distance is measured in.
- [Example harness](example-harness.md) — the harness presses both modes.
- [Zone](zone.md) — an open zone with no toast is drawn, so `open()` inserts the host too.

## Known holes / open
- **Not covered**: a toast whose exit is under way when `attach` moves the host — the
  exit was drawn by the old entry and goes with it.
- **Not covered**: a mode-2 host that is itself first mounted while the app is hidden —
  nothing draws it, so a `show` on a never-attached controller is not reached.
- A warm-up ended while the app draws no frames leaves its deck in the tree until the host's
  next build, which is the first frame back; its controller is disposed then. Nothing draws or
  ticks it meanwhile. **Not covered**: two `SonnerHost`s on one controller each draw the deck.
