# Mounting

## What it is
How the host gets into the tree and where the toasts are drawn relative to the app's
own routes, dialogs and overlays. Two modes, and the z-order rule that follows.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the mounting rows, including the
  z-order rule rewritten on the corrected overlay premise.
- [spec §5](../../spec.md#5-mounting).

## Design model
**Wrapped**: `SonnerHost` in `MaterialApp.builder` sits above the app's `Navigator` for
the life of the app. **Attached**: the controller is given a navigator key and the
toasts are drawn in the root navigator's overlay, above its dialogs and pages, from the
first toast shown or the zone first opened.

The difference is not cosmetic and it reaches the caller's widgets: wrapped, a widget in
a slot finds no `Navigator` and no `Overlay`, so a `Tooltip` throws. `attach` may be
called before the app is built; once attached, a toast with no navigator to draw in is
an error in debug and dropped in release.

## Code
`root_overlay.dart` — RootOverlayMount
`host.dart` — SonnerHost, ToastLayer

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
- **Not covered**: a mode-2 host that is itself first mounted while the app is hidden —
  nothing draws it, so a `show` on a never-attached controller is not reached.
