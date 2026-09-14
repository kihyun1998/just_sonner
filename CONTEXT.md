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

**Leading slot**:
The box before a toast's title. The caller fills it with a `leading` widget; while the toast is
loading it holds the configured loading indicator instead. A toast with neither has no slot, and
its title starts at the padding edge.
_Avoid_: icon, icon slot

**Loading**:
A toast that has no timer and shows the loading indicator in its leading slot. A flag the toast
carries, not a kind of toast — a toast can start loading, stop, and start again at the same id.
_Avoid_: loading type, pending, busy

**Toast**:
One notification, with an id, content and a lifetime.
_Avoid_: toast (for the thing that shows toasts — that is the controller)

**Update**:
Changing a toast on screen field by field; every field not given keeps its value. Its place in the deck is kept.
_Avoid_: patch, edit

**Replace**:
Showing new content at the id of a toast on screen: the old content goes whole, and only the toast's place in the deck is kept. Showing at the id of a dismissed toast is not a replace — it creates a new toast.
_Avoid_: update (for this), overwrite
