# just_sonner example

A desktop harness that makes every behaviour just_sonner has today pressable, so the package can
be felt rather than only tested.

```sh
cd example
flutter run -d windows   # or -d linux
```

## How it is meant to be used

The package is built one issue at a time, and each one is verified here before the next starts.
Every section of the panel names the issue it came from, and the last section, **Not built yet**,
lists the issues still to come. When one lands, it gets its own section here in the same change.

The harness is also where the values `docs/spec.md` §9 left provisional get settled by feel.

## What to look for

- **Show and dismiss** (#17, #18) — a toast enters, counts itself down and leaves. `Duration.zero`
  keeps it until something dismisses it.
- **The deck** (#19, #22, #23, #41) — rest the pointer on the deck. It fans out, draws every toast
  rather than `visibleToasts`, and every timer stops while the pointer is there. A deck taller
  than the screen scrolls, and the toast under the pointer keeps its place while it does.
- **Update and replace** (#21) — both keep the toast's place and restart its countdown. Update
  patches the fields passed; replace swaps the content whole, so a description it is not given
  disappears. "Update in a loop" shows a toast staying up while updates keep arriving.
- **Over a dialog** (#20) — mount mode 1 puts the toasts in the root navigator's overlay, so they
  sit above a dialog and its barrier, whether they were shown before it opened or while it is open.
- **Config** — `SonnerConfig` is fixed at construction today, so changing one of these controls
  builds a new controller and the toasts on screen go with it. #28 makes it live, and the panel
  says so.
- **Light and dark** — the toggle in the app bar. The default look takes its colours from the
  ambient `Theme`.

## Platforms

Windows and Linux are scaffolded. macOS still needs its `macos/` runner generated on a Mac
(`flutter create --platforms=macos .`); nothing in the app is Windows-specific.
