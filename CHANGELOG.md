## 0.2.0

- **A taller toast behind a shorter front keeps its whole card** (#72). It is laid out at the
  front's height rather than cut to it, so its bottom edge and corners are drawn. Before, only the
  two side edges of its card peeked out past the front.
- **Breaking for a builder:** a builder is now laid out below its own height whenever its toast is
  behind a shorter front. Wrap what is written on the card in the new **`ToastFit`**, inside the
  card, or build the look with the new **`toastCardBuilder`**, which takes the card and its
  content apart and also fades the content by `covered`. A builder that does neither reports an
  overflow in debug, which fails a widget test showing toasts of mixed heights. In release the
  deck clips it, so nothing shows past the card.

## 0.1.0

First release. Desktop only: Windows, macOS and Linux.

- **Toasts from anywhere.** `toast.show` needs no `BuildContext` and returns a `ToastId`.
  `update` changes a toast field by field; `show` at the id of a toast on screen replaces its
  content whole. Either way the toast keeps its place and counts down again. `dismiss` and
  `dismissAll` take toasts away.
- **`promise`.** One toast for the whole of a future: loading, then its result or its error. The
  future's own value or error goes back to the caller unchanged.
- **Two mount modes.** `toast.attach(navigatorKey)` draws the toasts in the root navigator's
  overlay, above dialogs and pages. `SonnerHost` wraps the app from `MaterialApp.builder`.
- **The deck.** Toasts stack into a deck that draws `visibleToasts` of them and fans out, every
  toast drawn, while the pointer is over it. Six positions; width, gap and offset.
- **Timers** pause while the pointer is over the deck, while a toast is dragged, and while the app
  is hidden. Toasts beyond the deck's window count down like the rest.
- **Swipe to dismiss**, in the directions the position names or the ones `swipeDirections` gives.
- **A default look** that follows the theme, light and dark, with a leading slot, an action slot,
  a close button, and a spinner while a toast loads. `dismissible` governs every way a user
  dismisses a toast.
- **A builder** that replaces the whole look, per toast or for every toast, handed a `ToastView`:
  the toast's state, its animation, how much the deck covers it, its time left, and `dismiss`.
- **Time left**, drawn by the default look as a border, a bar, or a ring, each with settings of
  its own (`config.timeLeft`).
- **A cap on the expanded deck** (`config.deckCap`, 400 px by default), past which the toasts
  scroll, with a draggable scrollbar beside them (`config.scrollbar`).
- **Dismiss all** from the deck (`config.dismissAll`): a pill or a header, or the app's own
  control through a builder.
- **Stow the deck**: `stow()` puts it out of sight, keeping its toasts, until the next new toast
  or `unstow()` brings it back. A control on the deck (`config.stowControl`), a motion
  (`config.stowMotion`) and a handle left at the edge (`config.stowHandle`), each with built-in
  looks and a builder.
- **Changing the config with toasts on screen**, which the deck follows in place.
