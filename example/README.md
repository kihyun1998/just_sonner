# just_sonner example

A desktop harness that makes every behaviour just_sonner has today pressable, so the package can
be felt rather than only tested.

```sh
cd example
flutter run -d windows   # or -d linux
```

## How it is meant to be used

The package is built one issue at a time, and each one is verified here before the next starts.
Every section of the panel names the issue it came from. Every feature issue of v0.1 has its
section now; a change to a behaviour changes its section in the same change.

The harness is also where the values `docs/spec.md` §9 left provisional get settled by feel.

## What to look for

- **Show and dismiss** (#17, #18) — a toast enters, counts itself down and leaves. `duration: null`
  keeps it until something dismisses it.
- **The deck** (#19, #22, #23, #41) — rest the pointer on the deck. It fans out, draws every toast
  rather than `visibleToasts`, and every timer stops while the pointer is there. A deck taller
  than the screen scrolls, and the toast under the pointer keeps its place while it does.
- **Dismiss all** (#59) — put two or more up and rest the pointer on the deck. A pill past its far
  end dismisses every toast you may dismiss; a loading toast stays. With twenty up it waits at the
  cap while they scroll. The controls below switch it to a header, a Korean label and count, or
  the app's own builder.
- **The zone** (#97) — `open()` fans every toast out with no pointer, and with none draws the
  empty card; `close()` goes back to where `open()` came from. Press Hide, or `hide()`, and the deck
  goes with its toasts kept and counting; "In 3 s: a new toast" then shows as a banner until it has
  gone and the pointer has left, while "Loading, done in 5 s" shows an update putting up none. With
  the switch on, an open zone closes once the pointer has been on it and left. The controls below
  pick the hide control, the motion and the empty card, each with a builder.
- **A still pointer** (#39) — press a button and leave the mouse where toasts appear. A toast
  that lands under a pointer nobody moves counts down and goes with the deck collapsed; move the
  mouse, press or turn the wheel there and it fans out and stops.
- **Mixed heights** (#19, #45, #72) — press one, then the other. A toast behind the front is drawn at
  the front's height, and draws no content while it is covered: the deck is a pile of cards with
  only the front one written on. A taller one behind keeps its whole card, bottom edge and corners
  included. Hovering fans them out and every toast reads again.
- **promise** (#46) — one toast for the whole arc: loading, then the result. The future’s own
  value or error goes back to the caller untouched, so a button that drives one handles the error
  itself. Dismiss the loading toast mid-flight and the result still arrives, as a new toast.
- **Update and replace** (#21) — both keep the toast's place and restart its countdown. Update
  patches the fields passed; replace swaps the content whole, so a description it is not given
  disappears. "Update in a loop" shows a toast staying up while updates keep arriving.
- **Action slot and close button** (#25) — the slot is yours and is handed the toast, so its widget
  decides whether pressing also dismisses; the X is the package's. `dismissible` governs both, and
  unset means "not while it loads" — watch the X appear the moment loading stops.
- **Builder** (#27) — a builder replaces the whole look and is handed the toast, which still enters,
  leaves, stacks and swipes on its own. Put three up and watch the ones behind: a builder reads
  `covered` to draw no content under the front, as the default look does. The panel's own look is
  built by `toastCardBuilder`, which does that and fits the text to the card: "A tall one in your
  look, then a short one" keeps the tall card whole behind the short one. The FlashBar buttons
  come through `lib/flash_adapter.dart`, which keeps flash's own motion at rest. With
  `dismissDirections: const []` the toast's swipe stays; with flash's default its swipe wins,
  `dismissible: false` springs back rather than going, and a trackpad pan on it never scrolls the
  deck: one way it drags the toast away, the other does nothing.
- **Time left** (#38) — a toast counting down draws its time left, the border sweeping round the
  card by default. Rest the pointer on the deck and every one stands still; "Updated at 3 s"
  eases it back up. Every `ToastTimeLeft` field is on a control below the buttons, and the
  `timeLeft` switch takes it away.
- **Deck cap and scrollbar** (#62) — put twenty up and rest the pointer on the deck. It reaches
  no further than the cap; the rest scroll with the wheel or by dragging the scrollbar beside the
  deck, and nothing shows past the cut, not even while the deck folds up as the pointer leaves.
  Every `DeckCap` and `DeckScrollbar` field is on a control below the buttons, with a switch to
  take each away.
- **Offset per edge** (#74) — turn on the title bar the app draws and put five up at
  topRight: with 24 on every edge they sit under it. "Clear a title bar" holds the deck 68 from the
  top and still 16 from the right. "Wide left" moves a deck at a left position and leaves a
  centered one in the middle.
- **The near end of the cut** (#86) — with the title bar on and "Clear a title bar" held, put
  twenty up and turn the wheel at the deck. The toasts pushed past the top `offset` stop being
  drawn rather than crossing the title bar; with the cap's `fade` they go out over it, and with
  `fade: 0`, or no cap at all, they stop hard. Clicks in that band behave as they did before.
- **Over a dialog** (#20) — mount mode 1 puts the toasts in the root navigator's overlay, so they
  sit above a dialog and its barrier, whether they were shown before it opened or while it is open.
- **Config** (#28) — put "Three that stay" up, then change a control. Each is assigned to the one
  controller, so the toasts stay and move to the new config over 400 ms: across the screen for a
  position on another side, fading out or in for `visibleToasts`. A toast dismissed just before
  keeps its place on screen while it leaves.
- **Light and dark** — the toggle in the app bar. The default look takes its colours from the
  ambient `Theme`.

## Platforms

Windows and Linux are scaffolded. macOS still needs its `macos/` runner generated on a Mac
(`flutter create --platforms=macos .`); nothing in the app is Windows-specific.
