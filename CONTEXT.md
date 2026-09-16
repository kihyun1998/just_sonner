# just_sonner

A stacking toast system for Flutter: toasts pile into a deck, fan out, and can be changed in place.

## Language

**Action slot**:
The place at a toast's trailing edge that the caller fills with its own widget. The widget is
handed the toast, so it decides for itself whether acting on it also dismisses it.
_Avoid_: action button, primary action

**Covered**:
How much of a toast the deck hides: the running product of the presences of the toasts in front of
it, 0 for the front and 1 behind one fully present. A covered toast draws no content and its
controls are not there to be used, while its card stays. The expansion undoes it.
_Avoid_: hidden (that is a toast outside the window), behind, obscured

**Deck**:
The group of visible toasts, in one of two states: collapsed (front toast in full, the rest peeking out) or expanded (fanned out into a list).
_Avoid_: stack (for the visible group), collapsed stack

**Dismissed**:
A toast whose exit has started. It is no longer on screen for the API's purposes: `update` on it fails and `show` with its id creates a new toast.
_Avoid_: closed, hidden

**Removed**:
A dismissed toast whose exit animation has finished and which has left the widget tree.
_Avoid_: dismissed (for this moment), unmounted

**Dismissible**:
Whether the **user** may dismiss a toast, by the close button or a swipe. Never about the app or a
widget in a slot: `dismiss(id)` and `ToastView.dismiss()` work whatever it says. Unset means
`!isLoading`, and is resolved on each read rather than when the toast was shown.
_Avoid_: closeable, locked, pinned

**Leading slot**:
The box before a toast's title. The caller fills it with a `leading` widget; while the toast is
loading it holds the configured loading indicator instead. A toast with neither has no slot, and
its title starts at the padding edge.
_Avoid_: icon, icon slot

**Loading**:
A toast that has no timer and shows the loading indicator in its leading slot. A flag the toast
carries, not a kind of toast — a toast can start loading, stop, and start again at the same id.
_Avoid_: loading type, pending, busy

**Swipe**:
Dragging a toast off the screen to dismiss it. The ways out come from the position's own words
unless `config.swipeDirections` names them; a drag the other way is damped rather than blocked, and
one let go short of the threshold springs back. What **Dismissible** governs, along with the close
button.
_Avoid_: drag (for this), fling, pan, swipe-to-dismiss

**Toast**:
One notification, with an id, content and a lifetime.
_Avoid_: toast (for the thing that shows toasts — that is the controller)

**Update**:
Changing a toast on screen field by field; every field not given keeps its value. Its place in the deck is kept.
_Avoid_: patch, edit

**Replace**:
Showing new content at the id of a toast on screen: the old content goes whole, and only the toast's place in the deck is kept. Showing at the id of a dismissed toast is not a replace — it creates a new toast.
_Avoid_: update (for this), overwrite
