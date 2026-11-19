# Toast lifetime

## What it is
A toast from `show` to gone: its id, its content, its countdown, and every way it can
be changed or dismissed while on screen. Owns the controller's list and the single
tick that serves every counting toast.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the rows on the countdown, on
  resuming skipping the partial tick, on update and replace, and on the visible window
  counting only toasts not yet dismissed.
- [spec §12](../../spec.md#12-decision-record) — the two kinds of toast and `duration:
  null` (#97, maintainer); the sentinel default (derived); the sentinel made public as
  `SonnerConfig.configDuration` (maintainer).
- [spec §12](../../spec.md#12-decision-record) — `count` on the controller, §2's non-goal
  not covering it, a banner not exposed (#122, maintainer); what it counts (derived).
- [spec §12](../../spec.md#12-decision-record) — `isAlive(id)` on the controller, §2's non-goal
  not covering it, a callback and a reason still barred (#150, maintainer for the read and its
  name); what it answers across a replace and on a disposed controller (derived).
- [spec §12](../../spec.md#12-decision-record) — no exit for a toast beyond the window with
  nothing drawing it (#126, maintainer), decided from what the last build kept offstage (derived).
- [spec §12](../../spec.md#12-decision-record) — the timers pausing on the pointer, a drag and a
  hidden app and not on `inactive` (maintainer), amended with what `inactive` means on desktop
  (#149); the app's `TimerHold` (#149, maintainer for the API and names, derived for the rest).
- [spec §12](../../spec.md#12-decision-record) — `SonnerConfig.pauseTimersOn` naming the lifecycle
  states that pause, reversing #149's "no config field" (#172, maintainer for the field, its name
  and the default); how the controller reads it (derived).
- [spec §12](../../spec.md#12-decision-record) — no exit for a toast that leaves while frames are
  disabled, enters kept (#174, maintainer); decided from `framesEnabled` as it leaves (derived).
- [spec §12](../../spec.md#12-decision-record) — `dismiss` and `dismissAll` asserting at entry on
  a disposed controller, a `promise` state due after `dispose` dropped with no report, and the
  other direct calls left assert-only (#155, maintainer).
- [spec §4](../../spec.md#4-api), [spec §7](../../spec.md#7-timers).

## Design model
One tick serves every counting toast and stops with the last. A **transient** toast has
a timer; one whose duration is null, or that `isLoading`, has **no** timer, so nothing
removes it but an explicit dismiss.

Every `duration` defaults to `SonnerConfig.configDuration`, a zero-valued `Duration`
subclass told apart **by identity** — never by `==`, which a zero `Duration` would pass.
Omitted takes `config.duration`, null takes the timer away. The trap it exists for: a
function that passes a `Duration?` on to `show` with no default turns every omission
into null, and so into a toast with no timer, with nothing to warn of it. That is why it
is public. A duration that is not positive asserts; in release it keeps the toast. Resuming skips the partial tick, because a pause released just before a tick
would otherwise subtract a whole one.

Nothing the app does to the zone pauses: neither hiding nor opening it. A deck left
open with nobody on it counts down, and so does a hidden one.

What does pause every timer: the pointer on the deck, a drag, `ToastView.holdTimer`, the
app in a lifecycle state `config.pauseTimersOn` names, and a `TimerHold` the app took with
`holdTimers()`. The lifecycle pause is a flag of its own; each of the others is a separate
key in the controller's set of holders. The `TimerHold` object is its own key, so each call
is a hold apart from every other and a release is idempotent.

The lifecycle flag is set when the current state is in the set; a null state never sets it.
The set defaults to `hidden`, `paused` and `detached`, so by default `inactive` does not
pause, and on Windows and Linux it covers a window fully covered by another as well as one
beside the user's work (#149). The field does not try to tell the two apart, since no state
does; it lets the app choose, in both directions (#172): add `inactive`, or give an empty set
so toasts run out while the app is minimised, which a hold, only ever adding a pause, could
not do. Assigning a config reads the state again through the lifecycle watch, so a changed
set applies at once, where the controller already watches; when watching starts is
unchanged. `resumed` in the set asserts.
A `release()` once the controller is disposed does nothing; `holdTimers()` then asserts.

`update` changes the fields passed; `show` at a live id **replaces**, taking the
content whole and keeping only the place. Both count down again. A dismissed toast is
already off screen for the API's purposes.

`count` is the list's length: how many are alive, never which one went or why, which
is the line §2's non-goal draws. It falls the moment a
toast is dismissed, so it can reach zero while an exit is still drawing. It counts the
same toasts as `DeckHideView.count`, and not the ones `DeckDismissAllView.count` does,
which are only those its `dismiss()` removes.

`isAlive(id)` is a lookup of the id in the same list, so it answers with `count`: true
from `show`, through an update or a replace, which keep the record, and false the moment
the toast is dismissed or runs out, its exit still drawing or not. It is present state, the
same line from the other side as `count`: whether this id is alive now, never when it went
or why. The trap is in reading it from a listener as a before and after: a listener that
re-shows the id inside the same notification, registered before the one comparing, turns
it back to true before the comparing listener runs, so the leaving is never seen
([A notification can re-enter its sender](../invariant/a-notification-can-re-enter-its-sender.md)).
Reading it when the app next acts on the id has no such order. On a disposed controller it
reads the list as `dispose` left it, as `count` does, so the two never disagree.

After `dispose`, every call that changes the controller asserts at entry, before anything
changes: `show`, `update`, `dismiss`, `dismissAll`, `promise`, the `config` setter,
`holdTimers`, `attach`, `raise` and the zone's `open`, `close`, `hide` and `reveal`. The
entry assert matters for `dismiss` and `dismissAll` in particular: without it they removed
the record and only then hit `notifyListeners`'s assert, so a debug run threw with the toast
already gone (#155). In release the asserts are gone and these calls act; that was chosen
over ignoring them. Reads, `TimerHold.release()` and `detach` do not assert.

A `promise` whose future settles after `dispose` drops its `success` or `error` state: the
callback is not called, nothing is shown and nothing is reported, in debug and release, and
the caller still gets the future's outcome. The check sits in `promise` after the `await`,
not in `show` or `_promiseState`, so `show` keeps its assert and only a state that falls due
after `dispose` is dropped. A screen closed mid-request is the ordinary flow, and a report
there failed an app's widget test; `FutureBuilder` drops a late result the same way (#155).

A toast beyond the window with nothing drawing it has **no exit**. Running one would draw it if
`open()` or a pointer fanned the deck out inside its exit (`motionDurations.exit`, 200 ms by
default): 9 to 11 frames of a toast already
gone, about 7,700 px at the peak (#126). The test is `_Slot.hidden`, what the last build kept
offstage, and not the toast's place in the window. A toast crossing the window's edge, one a lowered window is
fading out and one leaving a deck fanned out or folding are all beyond the window and on screen.

A toast that leaves while the app draws no frames has **no exit** either, whichever way it left
(#174). An exit started then gets no start time for its ticker, so every such exit played at once
on restore: cards drawn per 50 ms after restore `[3, 3, 3, 3, 3, 0, 0, 0]`. The test is
`SchedulerBinding.framesEnabled` as the toast leaves, not the controller's lifecycle pause, which
`pauseTimersOn` can leave off while the app is hidden. An exit already running as the app hides is
left alone; it is over on the first frame after restore, since its ticker started before. A toast
that arrives then keeps its enter, which plays from the first frame after restore, several
together: the maintainer chose that over arriving already in place.

## Code
`controller.dart` — SonnerController, TimerHold, holdTimersFor, releaseTimersFor
`host.dart` — ToastLayer
`toast_id.dart` — ToastId
`toast_state.dart` — ToastState
`toast_content.dart` — ToastContent
`config.dart` — debugCheckDuration
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
- [Deck controls](deck-controls.md) — `count` counts what `DeckHideView.count` counts, so a
  change to one is a question for the other.
- [Zone](zone.md) — a new toast puts a banner up on a hidden zone, and an update or a
  replace does not; a toast leaving a deck wholly out of sight has no exit.

## Known holes / open
- **Not covered**: a config assigned while the app draws no frames starts its glide then, so it
  plays on restore. #174 dropped the exits and kept the enters; the glide was not shown to the
  maintainer, and it has not been reproduced or measured.
- **Nothing caps the list.** A persistent toast can never leave by the tick, and every
  toast is built and laid out however few are drawn. The cost has never been measured,
  so it is a shape rather than a defect.
- **Not covered**: a mode-2 host first mounted while the app is hidden.
- **Not covered**: in release the calls that change the controller act after `dispose`,
  and `promise` called on a disposed controller shows its loading state while its result is
  dropped (#155).
- **Not covered**: a `TimerHold` the app never releases keeps every timer paused for the
  controller's life, and nothing reports it (#149).
- **Open**: a toast already inside the window at a window fade of exactly 0 is not `_Slot.hidden`,
  so it runs an exit that is drawn if the deck fans out. With a window of 1, dismissing the front
  toast, the one behind it on exactly the next frame, then `open()`: 12 frames on stage. A frame
  later it is fading in and its exit is right. A timer cannot reach this, since toasts running
  out in one tick share one notification (#126).
