# Hit-testing follows paint

## The fact
The deck takes the pointer where it is **drawn**, and nowhere else: the box around its
toasts cut where the deck is cut, plus the controls past the far end and a draggable
scrollbar's thumb. A band the deck leaves empty — the `offset` band at the near end,
the band past the cap at the far end — is the app's, for a click and for the hold,
before and after a scroll.

A pointer resting inside the drawn band cannot be slid off it by the scroll, because
both ends are cut: while the toasts do not fit they cover everything from the `offset`
edge to the cap, whatever the scroll. That is what lets hit-testing follow paint
without a stretched box.

## Why it is cross-cutting
It is a single box read by several questions that otherwise have nothing to do with each
other: whether the pointer is still on the deck, whether a click reaches the app, and
whether the timers stay paused. The layout reports that box and the cut clips and
hit-tests from one report, so a change that cuts the deck somewhere new moves all three
at once — and a change that reports one box for paint and another for the pointer
reopens the gap this closes.

## Territories it holds in
- [Pointer hold](../territory/pointer-hold.md) — the region is the drawn box.
- [Deck reach and cut](../territory/deck-reach-and-cut.md) — hit-testing reads both ends of the same cut paint does.
- [Swipe](../territory/swipe.md) — the one exception: a press carried off the drawn deck still holds it, as a press that stays put does.
- [Deck controls](../territory/deck-controls.md) — the controls past the far end are drawn, so they fall inside it.
- [Backdrop](../territory/backdrop.md) — the box it follows is the drawn box, and it takes no pointer of its own.

## What a violation looks like
The pointer rests over nothing drawn — the band an app keeps clear for its own title
bar, or the empty band past the cap — and the deck stays fanned out with its timers
stopped, or a click there never reaches the app. Or the inverse: a toast is drawn in a
band the deck should have cut, which is the paint half of the same gap.

## Discovery history
- **#41** — the stretch this replaces. A pointer resting in the far margin at y = 10
  was left outside the region as the scroll brought the oldest toast to 24, collapsing
  the deck; the fix stretched the box to the layer's edge rather than cutting the far
  end, which with no cap was not cut at all.
- **#86** — cut the near end, and left hit-testing there alone to keep #41's stretch.
- **#101** — the backdrop followed the stretched box into the `offset` band and needed
  a clip of its own.
- **#104** — the pointer resting in the `offset` band above a deck held it with nothing
  drawn there. Probed: with no cap, 8544 px painted in the far `offset` band — #86's
  report at the other end; with a 200 px cap, a tap 12 px past the far cut did not
  reach the app. Cutting the far end with no cap too removed the only case the stretch
  had been for, and hit-testing took the cut.

Each change that cut the deck (#62, #86, #101) had to be kept from disagreeing with the
stretch; that recurrence is what this note replaces.

## Where it will recur
Any change that makes the deck drawn somewhere new or stop being drawn somewhere — a
new cut, a new control outside the toasts, a new reason to clip. The test: **does the
pointer still land where the deck is drawn?** If the box for the pointer has to differ
from the box for paint, the cause is usually a part of the deck left uncut, and that is
what to fix.
