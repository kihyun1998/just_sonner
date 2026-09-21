# just_sonner

Stacking toasts for Flutter desktop, in the spirit of [sonner](https://github.com/emilkowalski/sonner).

Toasts pile up instead of replacing each other. They collapse into a deck and fan out when the
pointer comes over it, pausing while it stays. A toast can change in place, so a loading toast
becomes its result without a second one. You call it from anywhere, with no `BuildContext`, and it
ships a default look that a builder can replace whole.

- `toast.show` returns an id; `update`, `dismiss`, `dismissAll` and `promise` take it from there
- A deck that fans out on hover, with a cap, a scrollbar, and controls to dismiss or hide it all
- A backdrop that softens what is behind the deck as it fans out, if you ask for one
- Swipe to dismiss, a close button, and an action slot you fill
- Each toast's time left, drawn as a border, a bar or a ring
- No dependency beyond Flutter

**Desktop only, for now: Windows, macOS and Linux.** The package builds for mobile and web, but it
makes no promises there: nothing is specified or tested for touch, notches or the keyboard.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:just_sonner/just_sonner.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => SonnerHost(child: child!),
    home: Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () =>
              toast.show('Saved', description: 'Your changes are stored.'),
          child: const Text('Save'),
        ),
      ),
    ),
  );
}
```

`toast` is the package's default `SonnerController`. It holds the toasts, their ids and their
timers, and no widgets, so any code can call it.

### Two ways to mount

**Wrap the app** (above): `SonnerHost` in `MaterialApp.builder` sits above the app's `Navigator`
for the life of the app.

**Or attach to the root overlay:** give the app a navigator key and attach the controller to it.
The toasts are drawn in the root navigator's overlay, above its dialogs and pages, from the first
toast shown.

```dart
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  toast.attach(navigatorKey);
  runApp(MaterialApp(navigatorKey: navigatorKey, home: const HomePage()));
}
```

`attach` can be called before the app is built. Once attached, a toast shown with no navigator to
draw in is an error in debug and dropped in release.

The difference matters for the widgets you put in a toast. Wrapped, the toasts sit **above** the
`Navigator`, so `Navigator.of(context)` finds no navigator there, and a `Tooltip` or anything else
that looks for an `Overlay` throws "No Overlay widget found". Attached, they sit inside the root
overlay and find both.

## Showing, updating and dismissing

```dart
final id = toast.show('Uploading…', isLoading: true);

// Only the fields passed change. The toast keeps its place and counts down again.
toast.update(
  id,
  title: 'Uploaded',
  isLoading: false,
  duration: const Duration(seconds: 3),
);

toast.dismiss(id);
toast.dismissAll();
```

- **Duration.** A toast stays `config.duration`, 4 s by default, or the `duration` it is shown
  with. `Duration.zero` keeps it until it is dismissed.
- **Loading.** A toast with `isLoading: true` has no timer, and draws a spinner in its leading slot.
  Give it a duration when it stops loading, as above.
- **Update and replace.** `update` changes the fields passed and keeps the rest. `show` at the id of
  a toast on screen **replaces** it: the content is taken whole, every field not given goes back
  to its default, and the toast keeps its place. Both count down again. `update` returns false when
  no toast with that id is on screen.
- **Your own ids.** `ToastId('connection')` names a toast you can reach again without keeping the
  id `show` returned. Ids are equal when their values are.
- **Leading.** `leading:` takes any widget, such as an icon, drawn in a box of
  `config.leadingSize`.

## promise

One toast for the whole of a future: loading at once, then its result or its error.

```dart
import 'dart:async'; // unawaited

unawaited(
  toast
      .promise(
        saveDocument(),
        loading: const ToastContent('Saving…'),
        success: (_) => const ToastContent('Saved'),
        error: (error) => ToastContent('Could not save', description: '$error'),
      )
      .then<void>((_) {}, onError: (Object _) {}),
);
```

`promise` hands the future's own value back to the caller, and **rethrows its own error
unchanged**. So a call nobody awaits, such as one in an `onPressed`, needs its error handled, or it
reaches the zone as an unhandled error. The handling above is the one to copy. Do not use
`.catchError((Object _) => null as T)`: it analyses clean and throws a `TypeError` for any
non-nullable `T`, exactly when the error path runs. Awaiting it in a `try` / `catch` works too.

- Nothing the toast does changes what the caller gets. A state that cannot be shown, or a
  `success` or `error` callback that throws, is reported through `FlutterError.reportError`, and
  the future's outcome still arrives.
- A loading toast the user dismisses does not stop the result: it arrives as a new toast.
- `id:` takes over a toast already on screen, which is how a flow of several steps hands one
  loading toast on.

## The deck

The newest toast is at the front. The deck draws `visibleToasts` of them, 3 by default, and keeps
the rest undrawn. Those count down like any other, and one whose time runs out goes without coming
back into view.

**The pointer over the deck** fans it out and draws every toast. A deck taller than its cap
scrolls, and the toasts being read keep their place as others come and go. The pointer counts once
it moves, presses or turns the wheel there. A toast that lands under a pointer nobody moves counts
down as usual.

**Every timer pauses** while the pointer is over the deck, while a toast is being dragged, and
while the app is hidden. Each resumes with the time it had left. A window that only lost focus
does not pause them.

**`expandByDefault`** fans the deck out with no pointer. It draws only `visibleToasts` and does not
pause the timers.

**Swipe** a toast to dismiss it, in the directions its position names: `bottomRight` takes down and
right, `topCenter` up only. A drag any other way moves the toast a little and springs it back.
`config.swipeDirections` gives your own set, and an empty set lets no swipe dismiss; to take the
drag away altogether, make the toast not `dismissible`. A two-finger trackpad pan scrolls the deck
rather than swiping a toast.

## Slots, the close button and dismissible

```dart
toast.show(
  'Message archived',
  action: (context, archived) => TextButton(
    onPressed: () {
      restoreMessage();
      archived.dismiss();
    },
    child: const Text('Undo'),
  ),
  closeButton: true,
);
```

- **`action`** is yours. It is handed the toast, so the widget decides whether pressing it also
  dismisses the toast.
- **`closeButton`** draws the package's close button. `config.closeButton` sets it for every toast,
  and `show(closeButton:)` wins over it.
- **`dismissible`** governs every way a **user** dismisses a toast: the swipe, the close button and
  the dismiss-all control. Unset, it means "not while it loads". The app's own `dismiss` and
  `ToastView.dismiss` dismiss the toast whatever it says.

Wrapped in `SonnerHost`, a widget in a slot cannot look up an `Overlay` or the app's `Navigator`
([Two ways to mount](#two-ways-to-mount)). Give it a semantics label rather than a `Tooltip`, and
reach the navigator through a key.

## Your own look

A builder replaces the whole look. Give one to `show(builder:)` for one toast, or to
`config.builder` for every toast. The toast still enters, leaves, stacks and swipes on its own.

```dart
Widget myToast(BuildContext context, ToastView view) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: ToastFit(
      child: FadeTransition(
        opacity: ReverseAnimation(view.covered),
        child: Text(view.state.title),
      ),
    ),
  ),
);
```

The builder is handed a `ToastView`:

| Member | What it is |
|---|---|
| `id`, `state` | The toast's id, and what it shows now: title, description, `isLoading`, `dismissible`… |
| `animation` | 0 → 1 as the toast enters, 1 → 0 as it leaves |
| `covered` | How much the deck covers the toast: 0 at the front or expanded, 1 behind the front |
| `timeLeft` | 1 → 0 over the toast's countdown, or null while it has no timer |
| `dismiss()` | Dismisses the toast, whatever `dismissible` says |
| `holdTimer()` | Pauses the timers until the toast is dismissed or changed, for a gesture of your own |

**Read `covered`.** The default look draws no content while a toast is covered and keeps its card,
so the deck reads as a pile of cards with only the front one written on. A builder does that only if
it reads `covered`, as above. One that ignores it paints its text under the front toast.

**Fit the content to the card.** A toast behind a shorter front is laid out at the front's height,
below its own, so its card is drawn whole at that height. Whatever is written on the card has to
take that: wrap it in `ToastFit`, inside the card as above, and it keeps its own height, drawn
from the top and clipped at the card's edge. A builder that does not reports an overflow in debug whenever it
is behind a shorter front. In release the deck clips it, so nothing shows past the card.

`toastCardBuilder` does both for you. Give it the card and the content, and it puts the content in
the card with `ToastFit` and fades it by `covered`:

```dart
final myToast = toastCardBuilder(
  card: (context, view, child) =>
      Card(child: Padding(padding: const EdgeInsets.all(16), child: child)),
  content: (context, view) => Text(view.state.title),
);
```

## Time left

A toast counting down draws its time left, as a border sweeping round the card by default.

```dart
toast.config = toast.config.copyWith(
  timeLeft: () => const ToastTimeLeft(look: TimeLeftLook.bottomBar),
);
```

- **Looks:** `border`, `bottomBar`, `topBar`, `cornerRing`, `leadingRing`.
- **Settings:** `start` and `clockwise` for the border, `strokeWidth`, `color`, `keepBorder`,
  `easeRestart` and `fadeWhenCovered`.
- **None:** `copyWith(timeLeft: () => null)`.
- **A builder** reads `ToastView.timeLeft` whatever `config.timeLeft` says. It stands still while the
  timers are paused, and eases back up when an update or a replace starts the countdown again.

## Configuration

```dart
toast.config = toast.config.copyWith(
  position: SonnerPosition.topRight,
  visibleToasts: 5,
  closeButton: true,
);
```

Assigning a new config moves the toasts on screen with it. Countdowns already under way keep the
duration they started with; a new `duration` reaches the next toast.

A field that can be null is passed to `copyWith` as a function, so null can be given:
`copyWith(deckCap: () => null)`.

| Field | Default | |
|---|---|---|
| `position` | `bottomRight` | One of six: top or bottom, left, center or right |
| `width` | 356 | The width of every toast |
| `gap` | 14 | The space between two toasts |
| `offset` | `EdgeInsets.all(24)` | The distance from each screen edge. A centered position ignores left and right |
| `visibleToasts` | 3 | How many toasts the deck draws with no pointer over it, 1 to 20 |
| `duration` | 4 s | How long a toast stays; `Duration.zero` keeps it |
| `expandByDefault` | false | Fan the deck out with no pointer |
| `loadingIndicator` | `CircularProgressIndicator` | What a loading toast's leading slot holds |
| `leadingSize` | 20 | The side of the leading slot's box |
| `closeButton` | false | A close button on every toast |
| `swipeDirections` | null | The position's own directions |
| `builder` | null | The default look |
| `timeLeft` | `ToastTimeLeft()` | A border; null draws none |
| `deckCap` | `DeckCap.pixels(400)` | Null lets the deck reach the whole window |
| `deckBackdrop` | null | What is drawn behind the fanned-out deck; null draws nothing |
| `scrollbar` | `DeckScrollbar()` | Null draws none |
| `dismissAll` | `DeckDismissAll()` | Null draws none |
| `stowControl` | `DeckStowControl()` | Null draws none |
| `stowMotion` | `DeckStowMotion()` | A slide; not nullable |
| `stowHandle` | null | Nothing left at the edge |

**Your own controller.** `SonnerController(config: …)` makes one, which `SonnerHost(controller:)`
draws, or which you `attach` yourself.

## A long deck: cap, scrollbar, dismiss all

**The cap.** The expanded deck reaches no further than `config.deckCap` from its edge, and fades out
over 24 px there. Past it the toasts scroll. The cap never cuts the newest toast short.

```dart
toast.config = toast.config.copyWith(
  deckCap: () => const DeckCap.share(0.5), // half the window
);
```

A cap is `DeckCap.pixels(400)`, a share of the window with `DeckCap.share`, or a number of toasts
with `DeckCap.toasts`. Each takes `fade:`, and `fade: 0` cuts hard. `deckCap: () => null` lets
the deck reach the whole window.

**Both ends are cut.** Scrolling a deck that overflows pushes toasts past the edge's own `offset`
too, and they stop being drawn there — so the band you keep clear with `offset` stays clear, title
bar and all. That end fades over the same `fade`, inward from the `offset` edge, and needs no cap:
a deck taller than the window is cut there whether you set one or not. Clicks are unaffected.

**The scrollbar.** `DeckScrollbar()` is a draggable thumb outside the deck's right edge, shown all
the while the deck can scroll. `placement: DeckScrollbarPlacement.inside` puts it over the toasts,
`alwaysShown: false` shows it only while the deck scrolls, and `draggable: false` makes it take no
pointer.

**Dismiss all.** `DeckDismissAll()` draws a pill reading "Clear all" past the deck's far end. It
shows while the pointer holds the deck and at least two toasts the user may dismiss are up.

- Pressing it leaves loading toasts and `dismissible: false` ones. `toast.dismissAll()` still
  dismisses everything.
- `look: DeckDismissAllLook.header` draws a bar as wide as the deck, with the count.
- `builder:` draws your own control. It is handed a `DeckDismissAllView`: `count`, `dismiss` and
  the deck's `expansion`.

**In another language**, set the label, and the count for the header look. Flutter's localizations
have no "clear all" string.

```dart
toast.config = toast.config.copyWith(
  dismissAll: () => DeckDismissAll(
    look: DeckDismissAllLook.header,
    label: '모두 지우기',
    countLabel: (count) => '알림 $count개',
  ),
);
```

## Behind the fanned-out deck

`config.deckBackdrop` is null by default and draws nothing. With one, the deck softens what is
behind it as it fans out under the pointer, and fades it back as it collapses.

```dart
toast.config = toast.config.copyWith(
  deckBackdrop: () => const DeckBackdrop(),           // blur 4, nothing else
);

toast.config = toast.config.copyWith(
  deckBackdrop: () => const DeckBackdrop(
    blur: 12,                                          // the filter's sigma
    dim: 0.2,                                          // a cover over the blur
    color: null,                                       // null: colorScheme.scrim
    padding: EdgeInsets.all(20),                       // how far past the deck
    radius: 20,                                        // its corners
  ),
);
```

**It blurs what your app painted, not the desktop behind your window.** A `BackdropFilter` reaches
the content under it inside the window; the wallpaper needs a transparent native window, which is
the app's own decision and not this package's.

It is drawn to the deck's own box and reaches `padding` further. **A click in that padding still
reaches your app** — what the backdrop draws over claims no pointer the deck did not already claim.
`blur: 0` draws no filter and `dim: 0` no cover, so the default softens what is behind the deck
without darkening it.

## Hiding the deck

`toast.stow()` puts the deck out of sight, keeping its toasts. They count down as they would on
screen. The next **new** toast brings the deck back with whatever is left, as does
`toast.unstow()`. An update, a replace, and a `promise` state landing on a toast already on screen
do not. `toast.stowed` says whether it is hidden.

- **`stowControl`**, `DeckStowControl()` by default, is a pill reading "Hide". It shows while the
  pointer holds the deck. Its looks are `pill`, `header` and `icon`, and `builder:` draws your own
  from a `DeckStowView`. Where either control asks for a header look, the two share one bar.
- **`stowMotion`**, `DeckStowMotion()` by default, slides the deck past its edge. Its looks are
  `slide`, `fade` and `shrink`, and `builder:` takes the deck out of sight your own way. It is not
  nullable: an app that calls `stow()` needs a motion whether or not a control is drawn.
- **`stowHandle`** is null by default. `DeckStowHandle()` leaves a button at the edge reading how
  many toasts are hidden, which brings them back. `countLabel:` words it, and `builder:` draws your
  own from a `DeckStowHandleView`.

```dart
toast.config = toast.config.copyWith(
  stowControl: () => const DeckStowControl(look: DeckStowLook.icon),
  stowMotion: const DeckStowMotion(look: DeckStowMotionLook.fade),
  stowHandle: () => const DeckStowHandle(),
);
```

## Coming from flash

A `FlashBar` from [flash](https://pub.dev/packages/flash) can be a toast's look through a small
adapter. It lives in the example app rather than in the package:
[`example/lib/flash_adapter.dart`](https://github.com/kihyun1998/just_sonner/blob/main/example/lib/flash_adapter.dart).
Copy it into your app.

```dart
toast.show(
  'Saved',
  builder: flashToast(
    (context, controller, view) => FlashBar(
      controller: controller,
      dismissDirections: const [],
      content: Text(view.state.title),
    ),
  ),
);
```

- The adapter gives the `FlashBar` an animation of its own, resting at 1. The toast already enters
  and leaves by itself, and sharing its animation would run the motion twice.
- **Give it `dismissDirections: const []`.** On flash's default a `FlashBar` swipes in every
  direction, and its drag wins over the toast's: it ignores `dismissible`, which the adapter can
  only spring back, and takes trackpad pans that would scroll the deck. With no directions of its
  own, the swipe is the toast's.
- A `FlashBar` draws its card and its content as one, so fading the content by `view.covered` is
  up to your builder.

## Widget tests

Six things an app's widget tests meet with toasts on screen.

**A counting toast's timer outlives the widget tree.** The timer belongs to the controller, not to
the host, so unmounting the app does not stop it. `testWidgets` checks for pending timers before
`tearDown` runs, so a test that leaves a counting toast up fails with "A Timer is still pending even
after the widget tree was disposed". Before the test body ends, dismiss the toast, or pump past its
duration. Or show it with `duration: Duration.zero`.

```dart
testWidgets('saving shows a toast', (tester) async {
  await tester.pumpWidget(const App());
  await tester.tap(find.text('Save'));
  await tester.pump();
  expect(find.text('Saved'), findsOneWidget);

  toast.dismissAll();
  await tester.pump(const Duration(milliseconds: 200));
});
```

**`pumpAndSettle` runs out a counting toast.** While a toast counting down is drawn, the host
schedules frames for it, so `pumpAndSettle` keeps pumping until the toast's time runs out and it is
dismissed. Pump by hand, as above.

**`pumpAndSettle` never settles with a loading toast on screen.** The default `loadingIndicator` is
an indefinite `CircularProgressIndicator`, which never stops scheduling frames, like any spinner in
a Flutter test. Pump by hand, or pass an indicator that ends.

**The deck's controls are on by default.** `deckCap`, `dismissAll` and `stowControl` change where a
hovered deck takes the pointer and what it draws. A test that relies on the deck taking a click
anywhere down the window's side, or pins the deck's own geometry, sets them to null.

**A builder that does not fit its content fails a test with toasts of mixed heights.** Behind a
shorter front, its content overflows the height it is laid out at, and a widget test fails on the
overflow. Use `ToastFit` or `toastCardBuilder` ([Your own look](#your-own-look)).

**`toast` is one controller for the whole test run.** A test that wants a clean slate gives
`SonnerHost` a `SonnerController` of its own and disposes of it at the end.

## More

- [`example/`](https://github.com/kihyun1998/just_sonner/tree/main/example): a desktop harness with
  every behaviour on a button
- [`docs/spec.md`](https://github.com/kihyun1998/just_sonner/blob/main/docs/spec.md): the full
  specification, and the reason behind each decision

## License

MIT
