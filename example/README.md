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

- **Show and dismiss** (#17, #18) — a toast enters, counts itself down and leaves. `Duration.zero`
  keeps it until something dismisses it.
- **The deck** (#19, #22, #23, #41) — rest the pointer on the deck. It fans out, draws every toast
  rather than `visibleToasts`, and every timer stops while the pointer is there. A deck taller
  than the screen scrolls, and the toast under the pointer keeps its place while it does.
- **Mixed heights** (#19, #45) — press one, then the other. A toast behind the front is drawn at the
  front's height, and draws no content while it is covered: the deck is a pile of cards with only
  the front one written on. Hovering fans them out and every toast reads again.
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
  `covered` to draw no content under the front, as the default look does. The FlashBar buttons
  come through `lib/flash_adapter.dart`, which keeps flash's own motion at rest. With
  `dismissDirections: const []` the toast's swipe stays; with flash's default its swipe wins,
  `dismissible: false` springs back rather than going, and a trackpad pan on it never scrolls the
  deck: one way it drags the toast away, the other does nothing.
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
