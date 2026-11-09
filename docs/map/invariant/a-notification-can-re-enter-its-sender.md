# A notification can re-enter its sender

## The fact
The controller's listeners run inside `notifyListeners`, and an app's listener can call
`reveal()`, `open()`, `hide()`, `show()` or `update()` there. That call notifies in turn, so
the host's listener and every other one run again, nested, before the line after the first
notification. A method that notifies part way through has to have finished what it owes by
then, and must not act afterwards on what it read before.

## Why it is cross-cutting
The sites are a hide in the host, a press in the host and a loop in a control's callback.
None calls another, and each reads correct with no listener in the room, which is every test
that does not put one there. The rule is about what comes **after** a notification, and
nothing at the notification's own site shows it.

## Territories it holds in
- [Zone](../territory/zone.md) — hiding sets the hide target before it lets go of the pointer.
- [Pointer hold](../territory/pointer-hold.md) — `held` notifies from inside the host's own
  handling of a hover, a press and a hide.
- [Deck controls](../territory/deck-controls.md) — the dismiss-all control dismisses one toast
  at a time, and each dismissal notifies.

## What a violation looks like
A later line overwrites the listener's change, or carries on from a list or a flag read before
it. It settles into a state that disagrees with itself: the zone reads as shown with the deck
out of sight, or as hidden with `held` true. It needs a listener that acts in that exact
notification, so a suite with no such listener stays green.

The test: **put a listener in the notification, have it change what this method just decided,
and see whether its change stands.** Register it on both sides of the host's listener, and key
it on both the state and `held`, since they are told apart by when they fire.

## Discovery history
- **#124** — hiding under the pointer set the hide target after the `held` notification, so a
  `reveal()` in it was overwritten: the toast's text at 682 against 540. Fixed by setting the
  target first.
- **#128** — a press adds itself after the notification `_movePointer` sends, so a `hide()` in
  it is followed by a new hold. Open.
- **#129** — dismiss-all walks a list read at build, past a listener's `update` in the first
  dismissal. Open.

Three, none calling another.

## Where it will recur
Any new line after something that can notify: a call to `_publishHold`, `dismiss`, `show`,
`update` or a zone method, in the host or in a control's callback. `_onToastsChanged` and
`_setHeld` defer to the end of a frame only during a build, layout or paint; a pointer event
and an app's own call are neither.
