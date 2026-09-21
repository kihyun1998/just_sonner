# Toast lifetime

## What it is
A toast from `show` to gone: its id, its content, its countdown, and every way it can
be changed or dismissed while on screen. Owns the controller's list and the single
tick that serves every counting toast.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the rows on the countdown, on
  resuming skipping the partial tick, on update and replace, and on the visible window
  counting only toasts not yet dismissed.
- [spec §4](../../spec.md#4-api), [spec §7](../../spec.md#7-timers).

## Design model
One tick serves every counting toast and stops with the last. A toast with
`Duration.zero` or `isLoading` has **no** timer, so nothing removes it but an explicit
dismiss. Resuming skips the partial tick, because a pause released just before a tick
would otherwise subtract a whole one.

Nothing the app does to the deck pauses: neither `stow()` nor `expand()`. A deck left
expanded with nobody on it counts down.

`update` changes the fields passed; `show` at a live id **replaces**, taking the
content whole and keeping only the place. Both count down again. A dismissed toast is
already off screen for the API's purposes.

## Code
`controller.dart` — SonnerController
`toast_id.dart` — ToastId
`toast_state.dart` — ToastState
`toast_content.dart` — ToastContent
`time_left.dart` — TimeLeftFollower

## Reference behaviour
sonner's timer resets on update, and its exit window re-creates —
[the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md).
Those rows are what the code says rather than something observed, which the store
states outright, so anything resting on them carries forward as needing confirmation.

## Cross-cutting invariants
- [Drawnness is the key](../invariant/drawnness-is-the-key.md)

## Blast radius
- [Pointer hold](pointer-hold.md) — the hold is what pauses these timers.
- [Deck layout](deck-layout.md) — presence drives every placement, and it comes from here.
- [Default look](default-look.md) — the time left is the countdown's own number filled in.
- [Configuration](configuration.md) — `duration`, `visibleToasts` and the defaults live there.

## Known holes / open
- **Nothing caps the list.** A persistent toast can never leave by the tick, and every
  toast is built and laid out however few are drawn. The cost has never been measured,
  so it is a shape rather than a defect.
- **Not covered**: a mode-2 host first mounted while the app is hidden.
