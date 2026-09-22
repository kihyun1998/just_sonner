## 0.4.1

- **The backdrop stays out of the `offset` band before the deck is scrolled too** (#101). With
  `deckBackdrop` set and the pointer resting on a deck that can scroll, the backdrop was drawn
  from the window's edge rather than from `offset`, over the band an app keeps clear for its own
  title bar, until a scroll cut it there. It is now cut at the `offset` edge whether the deck has
  scrolled or not, and `DeckBackdrop.padding` gives way to it there. Clicks are unchanged.
- **The example app opens on a showcase** (#29): every argument of `show` and every part of
  `SonnerConfig` on a control, grouped on one page, beside buttons that show toasts with them. The
  harness each behaviour was verified in is on a page of its own, behind the app bar.

## 0.4.0

- **Breaking: a toast with no timer is shown with `duration: null`, not `Duration.zero`** (#97). A
  toast shown with a `duration` is a **transient** toast and goes when it runs out; one shown with
  `duration: null` stays until the user or your app dismisses it; one shown without a `duration`
  takes `config.duration` as before. `Duration.zero` now **asserts** in debug, on `show`, `update`
  and `SonnerConfig`, where it used to mean "no timer": write `duration: null` instead.
  `config.duration` is a `Duration?`, set to null with `copyWith(duration: () => null)`, which
  makes every toast shown without a duration stay. `update(id, duration: null)` takes a toast's
  timer away, and `ToastContent(duration: null)` makes a `promise` result stay.
  **A function that passes a duration on to `show` now needs a default**: with a plain
  `Duration? duration`, every call that leaves it out passes null and shows a toast with no timer.
  Give it `Duration? duration = SonnerConfig.configDuration`.
  A `promise`'s loading content takes no `duration` at all, and `ToastContent(duration: null)`
  there now asserts as any other duration does.
- **Breaking: the zone replaces stowing** (#97). `toast.zone` is the layer the deck lives in, your
  app's to open and close, and it exists with no toast up. Its state is **shown**, **open** or
  **hidden**:
  - `zone.open()` fans every toast out with no pointer, the ones beyond `visibleToasts` included,
    with the controls past the far end, and pauses nothing. With no toast it draws a card reading
    "No notifications" (`config.zoneEmpty`, null for none, or a builder of your own). The last toast
    leaving does not close it. `zone.close()` returns to the state `open()` was called from, so a
    zone opened from hidden hides again — a title-bar notification button needs no other code.
  - `zone.hide()` takes the deck out of sight with its toasts kept and counting down, as `stow()`
    did — but a new toast no longer brings the deck back: it shows the deck as a **banner**, the
    older toasts in it, until it has gone and the pointer has left, and the zone stays hidden. An
    empty zone stays hidden too. `zone.reveal()` brings it back.
  - `zone.held` says whether the pointer holds the deck, and the controller notifies when it
    changes, so your app decides what closes the zone.

  Removed: `stow()`, `unstow()` and `stowed`, and the edge handle — `stowHandle`, `DeckStowHandle`,
  `DeckStowHandleView` and `DeckStowHandleBuilder`; the entrance to a hidden zone is your app's own
  control. Renamed: `stowControl` → `hideControl` and `stowMotion` → `hideMotion`, with
  `DeckStowControl`, `DeckStowLook`, `DeckStowView`, `DeckStowBuilder`, `DeckStowMotion`,
  `DeckStowMotionLook`, `DeckStowMotionView` and `DeckStowMotionBuilder` → `DeckHide…`; a view's
  `stow` is `hide`, and a motion view's `stowed` is `hidden`. The Hide control now also shows on an
  open zone with no toast, and on a banner it takes the banner down. New: `SonnerZone`,
  `ZoneState`, `ZoneEmpty`, `ZoneEmptyView` and `ZoneEmptyBuilder`, and
  `SonnerConfig.configDuration` from the entry above.
- **Breaking: a drag a toast will not leave on moves it a little on either axis** (#87). A toast
  on a centered deck used not to move at all when dragged sideways, since neither left nor right is
  a way out there, while a drag down on the same toast moved it a little and sprang back. Every drag
  the toast will not leave on is now damped that way, whichever axis it takes. **`swipeDirections:
  {}` changes meaning with it**: it used to take the swipe away, and now lets no swipe dismiss while
  a drag still moves the toast and springs it back. To take the drag away altogether, make the
  toast not `dismissible`.
- **A scrolled deck no longer draws over the `offset` band** (#86). The deck is now cut at its
  **near** end as well as its far one. Scrolling a deck that overflows used to push toasts past the
  edge's own `offset` and go on painting them there — over the band an app keeps clear for its own
  title bar, and off the layer. The near end sits at that `offset`, fades over `DeckCap.fade`
  inward from it, and cuts hard where there is no fade; **it does not need a `deckCap` at all**, so
  a deck taller than the layer is cut there too. An exiting toast and the backdrop are cut with it.
  **Clicks are unchanged**: the near cut is paint only.

## 0.3.1

- **The fanned-out deck can blur what is behind it** (#78). `config.deckBackdrop` is null by
  default and draws nothing, so nothing changes until you ask for it. With a `DeckBackdrop` the
  deck softens what is behind it as it fans out under the pointer, and fades it back as it
  collapses: `blur` is the filter's sigma, `dim` and `color` a cover over it (`color` null follows
  the theme's `colorScheme.scrim`), `padding` how far past the deck it reaches, and `radius` its
  corners. **A click in that padding still reaches your app** — what it draws over claims no pointer
  the deck did not already claim. It blurs **what your app painted**, not the desktop behind your
  window.

## 0.3.0

- **Breaking: `offset` is an `EdgeInsets`** (#74). Each screen edge takes its own distance, so a deck
  can clear a title bar at the top and still sit close to the right edge. Write
  `offset: EdgeInsets.all(24)` where you wrote `offset: 24`. The edges are physical. A centered
  position ignores left and right. The edge the position names holds the deck off it; the
  opposite one is where the expanded deck stops.
- **Nothing is drawn past the deck's cap while it stows** (#75). With many toasts and a cap that
  fades (the default), pressing Hide drew the oldest toasts past the cap for the first half of a
  `slide` or `shrink` stow. The fading cut now keeps them out, as a hard cut already did.

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
