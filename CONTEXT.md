# just_sonner

A stacking toast system for Flutter: toasts pile into a deck, fan out, and can be changed in place.

## Language

**Deck**:
The group of visible toasts, in one of two states: collapsed (front toast in full, the rest peeking out) or expanded (fanned out into a list).
_Avoid_: stack (for the visible group), collapsed stack

**Dismissed**:
A toast whose exit has started. It is no longer on screen for the API's purposes: `update` on it fails and `show` with its id creates a new toast.
_Avoid_: closed, hidden

**Removed**:
A dismissed toast whose exit animation has finished and which has left the widget tree.
_Avoid_: dismissed (for this moment), unmounted
