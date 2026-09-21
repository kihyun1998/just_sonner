# Drawnness is the key

## The fact
What the deck does about a toast is keyed on **whether and where that toast is drawn**,
never on whether the scroll overflows or on the toast's index. Two consequences that
look unrelated: what is cut is decided from the drawn positions, and what schedules
frames is decided from drawnness.

## Why it is cross-cutting
The deck's state changes over 400 ms while the pointer leaves, and during that time a
toast can be outside the window, still fanned out, and still on screen. Every question
of the form *"does this toast still count?"* has to be answered from where it is drawn,
because every other proxy — the scroll overflowing, the window index, the expansion flag
— is already false while the toast is still visible.

**The two sites do not call each other.** The cut reads the drawn reach and the drawn
near edge inside the layout delegate; the frame gate reads `_Slot.hidden` and the stow
in the host. Neither knows the other exists, which is why no territory-to-territory edge
could have carried this fact.

## Territories it holds in
- [Deck reach and cut](../territory/deck-reach-and-cut.md) — both ends of the cut are reported from drawn positions.
- [Toast lifetime](../territory/toast-lifetime.md) — frames run for the time left only while a counting toast is drawn.
- [Default look](../territory/default-look.md) — the time left stands still while nothing draws it, and comes back on the number.

## What a violation looks like
Something keyed on the proxy is right while the deck is still and wrong for the length
of an animation. It is invisible in a settled frame and shows only in the transition,
which is why it survives a test suite that pumps to completion.

## Discovery history
- **#62** — a cut keyed on the overflow let the toasts beyond the window show past the
  cap for the whole 400 ms collapse. Read from pixels at 50, 100 and 150 ms.
- **#67** — a stowed deck with one counting toast scheduled a frame on 20 of 20 pumps,
  as did a deck whose only counting toast was beyond `visibleToasts`; both are 0 of 20
  with drawnness as the gate.
- **#86** — the near end of the cut was keyed the same way for the same reason, and a
  probe confirmed it holds through the collapse with an exiting toast frozen past the
  edge: 0 px throughout, against ~7,400 px with the cut off.

Three, the third of which reused the rule rather than rediscovering it — which is what
this note is for.

## Where it will recur
Any new behaviour that asks *"is this toast still in the deck?"* — a semantics
decision, a new control's visibility, an announcement, a second cut. The test: **would
this answer change during the 400 ms after the pointer leaves?** If yes, it must read
the drawn position and not the overflow, the index or the expansion flag.
