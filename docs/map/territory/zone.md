# Zone

## What it is
The layer the deck lives in, which the app opens and closes and which exists with no
toast in it: its three states — hidden, shown, open — the banner a hidden zone puts up,
the empty card an open one draws, and `toast.zone`, the app's handle on all of it.

## Governing decisions
- [spec §12](../../spec.md#12-decision-record) — the zone and its three states, `close()`
  returning to the state `open()` came from, the banner, an open zone surviving its last
  toast, Hide on an empty open zone, opening taking the banner down, "hidden" being the
  zone's word (#97, maintainer); what #97 derived, and the #60 and #88 rows it
  supersedes.
- [spec §12](../../spec.md#12-decision-record) — a banner not exposed to an app reading
  `count` (#122, maintainer).
- [spec §6](../../spec.md#6-layout-and-animation), [spec §7](../../spec.md#7-timers).

## Design model
The state is the controller's and does not depend on how many toasts are alive. The one
exception is the **banner**, and the controller owns it too: it knows which toasts arrived
since the zone was hidden and whether the pointer holds the deck, the two halves of the
rule that ends it. The host only reads whether a hidden zone draws its deck.

A banner is put up by a **new** toast only — the same line #60 drew for what brought a
stowed deck back — and every change of state takes it down, which is why opening can
clear it without a separate rule: nothing but `close()` can reach hidden from open, and
`close()` clears it anyway.

The empty card is a child of the deck's layout rather than a layer beside it, so the
hover region, the controls past the far end and the backdrop take it in as they take in
a toast. A host reads the zone's state as it mounts, because a zone now keeps a state a
host can mount into — a hidden zone with toasts, an open one with none.

Opening pauses nothing, and hiding neither; both carry #88's rule that only the pointer,
a drag or a hidden app pauses.

An app that brings the zone back when it empties has to act as `count` **falls** to zero,
not whenever it reads zero. `hide()` notifies too, so a listener testing
`state == hidden && count == 0` undoes a hide on an empty zone at once, and the same for a
`close()` back to hidden.

## Code
`controller.dart` — SonnerZone, ZoneState, zoneBanner
`host.dart` — ToastLayer
`look/zone_empty.dart` — ZoneEmptyCard
`zone_view.dart` — ZoneEmptyView, ZoneEmptyBuilder
`deck_layout.dart` — ToastDeckDelegate

## Reference behaviour

**None.** sonner has no layer that outlives its toasts, no hidden state and no empty
state — [the store](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md)
records no equivalent. Every value here was settled in #97's design session.

## Cross-cutting invariants
- [Drawnness is the key](../invariant/drawnness-is-the-key.md)
- [Distances are measured from the position's own edge](../invariant/distances-from-the-positions-edge.md)

## Blast radius
- [Deck controls](deck-controls.md) — the hide control shows on an open zone with no
  toast, past the empty card.
- [Pointer hold](pointer-hold.md) — `held` ends a banner, and hiding lets the pointer go.
- [Toast lifetime](toast-lifetime.md) — a new toast is what puts a banner up, and its
  leaving is what takes it down.
- [Mounting](mounting.md) — `open()` inserts a mode-1 host as a new toast does.
- [Deck layout](deck-layout.md) — the empty card sits where the front toast would.

## Known holes / open
- **Not covered**: which of "opening clears the banner" and "closing brings it back" the
  code does can only be seen through `close()`, which clears it either way; the mutation
  that keeps the banner through `open()` survives every test. Recorded in §12.
- **Not covered**: several hosts on one zone, as for the hold.
- **Not covered**: an app reading `zone.state == ZoneState.hidden && count > 0` as "something
  is hidden" also reads a banner that way, since the banner is not exposed (#122). Whether a
  dot lit during a banner reads wrong has not been seen in a real app.
- **Open** (#123): a toast that runs out in a hidden zone is drawn for about 100 ms when the
  app calls `reveal()` at that moment, which an app bringing the zone back as it empties does.
  §7 says such a toast does not come back into view, and does not cover an app revealing it.
