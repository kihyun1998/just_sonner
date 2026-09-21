# just_sonner

A stacking toast system for Flutter: toasts pile into a deck, fan out, and can be changed in place.

## Language

**Action slot**:
The place at a toast's trailing edge that the caller fills with its own widget. The widget is
handed the toast, so it decides for itself whether acting on it also dismisses it.
_Avoid_: action button, primary action

**Backdrop**:
What is drawn behind the **deck** while it is fanned out, as `config.deckBackdrop` gives it: a blur
of what the app painted, and a cover over it at `dim`'s share of `color`. It follows the expansion,
so a collapsed deck has none. It is drawn **under** the toasts — never over them, which is what
**covered** means — and outside the deck's cut, and it takes no pointer: the deck's own box claims
the clicks in its gaps, and a click in the `padding` the backdrop reaches into goes to the app.
_Avoid_: scrim (that is the theme role it defaults to, not this), overlay, dim (for the whole
thing — that is one of its fields), blur (for the whole thing)

**Cap**:
How far the expanded deck reaches from its edge before its toasts scroll, as `config.deckCap`
gives it, and never short of the newest toast. It is the **cut**'s far end, and nothing is drawn
past it; the near end is the deck's other end and is not the cap's doing. A scrollbar beside the
deck shows where in the scroll the toasts in view are.
_Avoid_: max height, limit (for this)

**Covered**:
How much of a toast the deck hides: the running product of the presences of the toasts in front of
it, 0 for the front and 1 behind one fully present. A covered toast draws no content and its
controls are not there to be used, while its card stays. The expansion undoes it.
_Avoid_: hidden (that is a toast outside the window), behind, obscured

**Cut**:
Where the deck stops being drawn, at **both** ends of it: the far end at the **cap**, the near end
at the edge's own `offset`, so a scroll that pushes toasts past either stops drawing them there.
Each end fades over the cap's `fade` or cuts hard, and the near end holds with no cap at all. It is
a **paint** cut: only the far end is read for the pointer.
_Avoid_: clip, mask (those are how it is drawn, not what it is)

**Deck**:
The group of visible toasts, in one of two states: collapsed (front toast in full, the rest peeking out) or expanded (fanned out into a list). It can also be **stowed**, which is neither: out of sight, with its toasts kept.
_Avoid_: stack (for the visible group), collapsed stack

**Dismissed**:
A toast whose exit has started. It is no longer on screen for the API's purposes: `update` on it fails and `show` with its id creates a new toast.
_Avoid_: closed, hidden

**Removed**:
A dismissed toast whose exit animation has finished and which has left the widget tree.
_Avoid_: dismissed (for this moment), unmounted

**Dismiss-all control**:
The control past the expanded deck's far end that dismisses every toast the user may dismiss at
once, as `config.dismissAll` draws it. A toast that is not **Dismissible** stays; `dismissAll()` on
the controller is the app's, and dismisses every toast.
_Avoid_: clear all (for the control), close all

**Dismissible**:
Whether the **user** may dismiss a toast, by the close button, a swipe or the **dismiss-all
control**. Never about the app or a
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

**Stowed**:
The deck put out of sight and out of the pointer's reach, keeping its toasts and their countdowns,
until the next **new** toast brings it back. A toast whose time runs out while it is stowed is
gone when the deck comes back. `config.stowControl` draws the control that stows it, `stowMotion`
how it goes, and `stowHandle` what it leaves at the edge; `stow()` and `unstow()` on the
controller are the app's.
_Avoid_: hidden (that is a toast outside the window), minimized, collapsed (that is the deck's
other state)

**Swipe**:
Dragging a toast off the screen to dismiss it. The ways out come from the position's own words
unless `config.swipeDirections` names them; a drag any other way, on either axis, is damped rather
than blocked, and one let go short of the threshold springs back. What **Dismissible** governs, along with the close
button and the **dismiss-all control**.
_Avoid_: drag (for this), fling, pan, swipe-to-dismiss

**Time left**:
How much of its duration a counting toast has left, from 1 as its countdown starts to 0 as it runs
out. It stands still while the timers are paused, and a toast loading or with no duration has none.
It is the countdown's own number filled in between ticks, never a second count of its own: each
tick puts it back on the countdown, so it stands still while nothing draws it — a stowed deck, or a
toast beyond the window — and comes back on the number rather than where it stood.
The default look draws it as `config.timeLeft` says; a builder is handed it either way.
_Avoid_: progress (that reads as a loading toast's), countdown (that is the controller counting), timer bar

**Toast**:
One notification, with an id, content and a lifetime.
_Avoid_: toast (for the thing that shows toasts — that is the controller)

**Update**:
Changing a toast on screen field by field; every field not given keeps its value. Its place in the deck is kept.
_Avoid_: patch, edit

**Replace**:
Showing new content at the id of a toast on screen: the old content goes whole, and only the toast's place in the deck is kept. Showing at the id of a dismissed toast is not a replace — it creates a new toast.
_Avoid_: update (for this), overwrite
