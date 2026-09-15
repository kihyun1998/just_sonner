# just_sonner — v0.1 specification

Status: **settled** (2026-09-14). Every question §11 held is decided and written up; §12 records
each one with its basis. Implementation is under way, one slice per issue (#17–#29). Scope is **desktop only** for v0.1 (§2).

A stacking toast system for Flutter in the spirit of [sonner](https://github.com/emilkowalski/sonner):
toasts pile up instead of replacing each other, collapse into a deck and fan out on hover, and a
toast can be **updated in place** — a loading toast becomes its result without a second toast.
It can be called from anywhere, with no `BuildContext`, and ships a default look that any
builder can replace.

---

## 1. Why another toast package

Checked against the source on 2026-09-14, not against pub.dev summaries:

| | Called without `BuildContext` | Mounts without wrapping the app | Update a toast in place / promise | Stack + expand on hover | Default look |
|---|---|---|---|---|---|
| [`sonner_toast`](https://github.com/suryasarisa99/sonner-toast) 2.0.2 | ✅ `Sonner.toast()` | ❌ `SonnerOverlay` + `GlobalKey` | ❌ `toast()` returns `void`; API is `toast` / `hide` / `dismissAll` | ✅ | ❌ headless |
| [`zentoast`](https://github.com/definev/zentoast) 0.2.2 | ❌ `Toast.show(context)` via `ToastProvider.of(context)` | ❌ `ToastProvider.create` | ❌ `show` / `hide` only | not found in source | ❌ headless |
| **just_sonner** | ✅ | ✅ root overlay, or a wrapper if preferred | ✅ `update(id)`, `promise()` | ✅ | ✅ + builder |

What just_sonner adds, in the order a real consumer needed them:

1. **Update in place and `promise`.** The motivating case is a connection that takes seconds:
   one toast goes *checking credentials… → opening the session… → connected* and never flickers
   into a second toast. This is sonner's own model (`state.ts`: creating a toast with an existing
   id updates it; `promise` is built on that).
2. **Root-overlay mounting, flash-style.** Call it from a service layer with nothing but a
   navigator key, the way [`flash`](https://pub.dev/packages/flash) and hand-rolled toast services
   already work.
3. **A builder that receives the animation.** Each toast hands its builder an
   `AnimationController` and a `dismiss`, so an existing widget built on flash's `FlashBar`
   (which takes a `FlashController`: `controller`, `dismiss`, `deactivate`) plugs in through a
   three-member adapter. Migrating off `showFlash` does not mean redrawing the toast.
4. **Desktop only, in v0.1.** Hover expands the deck and pauses every timer; pointer drag
   swipes. Touch has neither, and §2 says so rather than leaving it to be discovered.

## 2. Goals and non-goals

### Goals (v0.1)

- Stack, collapse, expand on hover, pause on pointer/drag/app-hidden (§7), swipe to dismiss
- Six positions, max visible count, width, gap, offset
- `show` returns an id; `update(id)`, `dismiss(id)`, `dismissAll()`, `promise(future)`
- Two mount modes (§5), root overlay by default
- One default look — light and dark from `Theme.of(context)` — with a leading slot the caller
  fills, and a spinner in that slot while a toast is loading
- A builder that fully replaces the look and receives the animation and a dismiss handle
- **Windows, macOS, Linux**; no dependency beyond Flutter

### Non-goals (v0.1)

- Several independent toasters at once (one host per app)
- A toast history / notification center
- Semantic toast types (`success` / `error` / …) and the rich colors, custom fonts and icon packs
  that would follow from them — the caller fills the leading slot with its own widget, and the
  builder is the escape hatch for everything else
- Reporting that a toast went away and why — no callback, future or reason enum (sonner's
  `onDismiss` / `onAutoClose`, `SnackBarClosedReason`). A caller learns about its own button
  through the `action` slot's callback, and nothing else
- **Mobile and web.** v0.1 targets desktop only, so nothing here is specified or tested for
  touch: how a deck expands without hover, whether pause-on-hover has a touch equivalent, and
  honouring `MediaQuery.viewPadding` / `viewInsets` for notches, the status bar and the keyboard.
  The package will still build for those platforms; it just makes no promises about them
- Keyboard shortcut to focus the toast region (sonner's `hotkey`)
- RTL mirroring beyond what `Directionality` gives for free

## 3. Vocabulary

| Term | Meaning |
|---|---|
| **toast** | One notification. Has an id, a state (title, description, `isLoading`, …) and a lifetime |
| **host** | The single widget that lays out and animates every toast |
| **deck** | The collapsed stack: the front toast in full, the ones behind peeking out |
| **front** | The newest visible toast |
| **expanded** | The deck fanned out into a list — on hover, or always if `expandByDefault` |
| **controller** | Owns the toast list, ids and timers. No widgets. The package's default one is the instance `toast` — in prose, "toast" alone always means one notification |
| **update** | Change a toast on screen field by field; fields not given keep their value |
| **replace** | Show new content at the id of a toast on screen; the old content goes whole, the place stays |

## 4. API

Dart signatures are the contract; names are open to review (§11).

```dart
/// The default controller, exported by the package and usable from anywhere.
final toast = SonnerController();

class SonnerController extends ChangeNotifier {
  SonnerController({SonnerConfig config});

  /// The live config. Assigning notifies, so a mounted host follows it (§6 Motion).
  /// This is the only way to configure the exported `toast`, which is already constructed.
  SonnerConfig config;

  /// Mount mode 1 — insert this controller's host into the root overlay of [navigatorKey].
  void attach(GlobalKey<NavigatorState> navigatorKey);

  /// Undoes [attach]: takes the host out of the overlay, and the controller is no longer in mode 1.
  void detach();

  /// Shows a toast. An [id] that is on screen **replaces** that toast (see Update rules).
  ToastId show(String title, {
    String? description,
    bool isLoading = false,      // no timer; the leading slot holds config.loadingIndicator
    Widget? leading,             // fills the leading slot when the toast is not loading
    Duration? duration,          // null → config.duration; Duration.zero → stays until dismissed;
                                 // negative → debug assert
    bool? dismissible,           // null → !isLoading (§8)
    ToastSlot? action,           // the caller's widget; it receives the toast (see Slots)
    bool? closeButton,           // null → config.closeButton
    ToastId? id,
    ToastBuilder? builder,       // replaces the look for this toast only
  });                            // debug assert: !isLoading || duration == null

  /// **Updates** a toast on screen: only the fields passed change. Returns false if it is gone.
  bool update(ToastId id, {String? title, String? description, bool? isLoading, Widget? leading,
      Duration? duration, bool? dismissible, ToastSlot? action, bool? closeButton,
      ToastBuilder? builder});

  Future<T> promise<T>(Future<T> future, {
    required ToastContent loading,
    required ToastContent Function(T value) success,
    required ToastContent Function(Object error) error,
    ToastId? id,                 // same rule as show(id:)
  });

  void dismiss(ToastId id);
  void dismissAll();
}

/// The content of one `promise` state. Everything `show` takes except `id` and `isLoading`,
/// which `promise` sets itself.
class ToastContent {
  const ToastContent(String title, {String? description, Widget? leading, Duration? duration,
      bool? dismissible, ToastSlot? action, bool? closeButton, ToastBuilder? builder});
}

typedef ToastBuilder = Widget Function(BuildContext context, ToastView toast);

/// A slot the caller fills. It receives the toast so the widget can act on it — the same
/// contract as [ToastBuilder], for one slot rather than the whole look.
typedef ToastSlot = Widget Function(BuildContext context, ToastView toast);

/// What a builder gets.
abstract interface class ToastView {
  ToastId get id;
  ToastState get state;                  // title, description, isLoading, leading,
                                         // action, closeButton, dismissible
  AnimationController get animation;     // enter 0→1, exit 1→0
  Future<void> dismiss();
  void holdTimer();                      // a widget-driven gesture started (see §7)
}

/// `show` returns one; a caller can make its own, `ToastId('connection')`. Ids are equal when
/// their values are, and a generated id's value is an object no caller holds, so the two never meet.
extension type const ToastId(Object value) {}

enum SonnerPosition { topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight }
```

A test, or an app that wants its own instance, constructs another `SonnerController`; it has the
same methods as `toast`. There is no static facade.

`SonnerHost({SonnerController? controller, required Widget child})` (mount mode 2) draws
`controller`, or `toast` when omitted. `SonnerConfig` carry: `position` (`bottomRight`), `width` (356), `gap` (14),
`offset` (24), `visibleToasts` (3), `duration` (4 s), `expandByDefault` (false),
`swipeDirections` (derived from position), `builder` (the default look when null),
`loadingIndicator` (what the leading slot holds while a toast is loading), `leadingSize` (20),
`closeButton` (false), `backlogDuration` (300 ms — a just_sonner proposal, to be felt out in the
example app and likely shortened). It is immutable and has a `copyWith`, so one field changes with
`toast.config = toast.config.copyWith(position: …)`.

**The config lives on the controller and nowhere else.** `attach` does not take one and neither
does `SonnerHost`, so there is a single place to set it and no precedence to define — both mount
modes read the same value and both follow a change through the `ChangeNotifier` the controller
already is. Changing `position` also changes the `swipeDirections` derived from it, and changing
`builder` re-draws every toast that has no builder of its own.
Hosts of two controllers mounted at once are not coordinated (§2 non-goal).

### Slots

The default look has two slots the caller fills, and one affordance the package owns.

- **`leading`** — a widget placed before the title. While `isLoading` the slot holds
  `config.loadingIndicator` instead.
- **`action`** — a `ToastSlot`. The caller returns the whole widget and the package only places
  it. It receives the toast, so the widget decides for itself whether acting also dismisses:

  ```dart
  toast.show('Item deleted', action: (context, t) => TextButton(
    onPressed: () { undo(); t.dismiss(); },       // closes the toast
    child: const Text('Undo'),
  ));

  toast.show('Connection failed', action: (context, t) => TextButton(
    onPressed: () => toast.update(t.id, isLoading: true, title: 'Retrying…'),
    child: const Text('Retry'),                   // keeps it, and its place in the deck
  ));
  ```

  There is one slot; two buttons are a `Row` inside it.
- **The close button** is not caller content — it is the pointer equivalent of a swipe, so the
  package owns it and `dismissible` governs both (§8). `show(closeButton:)` wins over
  `config.closeButton` (false); `null` means "follow the config".

This follows flash's `FlashBar`, which takes `Widget? icon` and `Widget? primaryAction` and wires
neither. flash can take a bare widget because its caller already holds the `FlashController`;
`show` returns the id only afterwards, so just_sonner hands the toast to the slot instead.

### Update rules

Two ways to change a toast that is on screen, and they differ only in what happens to the fields
not given:

- **Update** — `update(id, …)`: a patch. A field passed as `null` or not passed keeps its value, so
  `update` cannot clear a field.
- **Replace** — `show(id: x)` or a `promise` state, where `x` is on screen: the new content
  replaces the old whole. A field not given takes its default — `description`, `leading` and
  `action` disappear, `closeButton` goes back to following the config, and `builder: null` returns
  to the default look.

Both:

- keep the toast's place in the deck and its enter animation; only the content changes.
- **restart the countdown from the toast's duration**, every time and whatever changed — there is
  no list of fields that do and do not count. A toast that is updated is a toast with something
  new to read, and one that is updated repeatedly (`update(id, title: 'Uploading 43%')` in a loop)
  stays up for as long as the updates keep coming, then goes its full duration after the last one.

  The duration it restarts from is the toast's own: whatever it resolved to when it reached the
  visible window (§7), or whatever a later `duration:` set. An `update` keeps that value unless
  `duration:` is passed; a **replace** resets it like any other field not given, and a reset
  duration is `config.duration`. `backlogDuration` applies only when a toast *first reaches* the
  visible window and never to one already in it — a toast already being read never has its
  remaining time shortened underneath the reader.
- A toast entering `isLoading` stops counting; one leaving it counts again under the rule above.
- A change of `builder` fades the new builder's output in over the old one's (§6); the old one
  ignores the pointer, so a builder with its own gestures (flash's `FlashBar`) cannot act while
  the new one fades in.

Also:

- `show(id: x)` with an `x` that was already dismissed creates a **new** toast — the old one's
  fields do not leak into it (sonner `state.ts`, same rule).
- A `promise` whose loading toast the user dismissed still shows its result, as a **new** toast.
  That follows from the rule above rather than being an exception to it, and it is the wanted
  behaviour: what the user swept away was the progress indicator, not the outcome. A failure is
  not swallowed because someone tidied the screen.
- `promise` shows `loading` immediately (replacing the toast at `id` if one is on screen), then
  replaces it with `success(value)` or `error(error)`; the future's own result or error is returned
  unchanged to the caller. `duration` on the `loading` content is ignored (asserted in debug).
- A multi-step flow holds the id:
  `final id = toast.show('Checking credentials…', isLoading: true)`, then
  `toast.update(id, title: 'Opening the session…')`, then `toast.promise(open(), id: id, …)`.

## 5. Mounting

| Mode | Setup | Behaviour |
|---|---|---|
| **1. Root overlay** (default) | `toast.attach(navigatorKey)` once, e.g. after `runApp` | The host is inserted into `navigatorKey.currentState!.overlay` on the first toast |
| 2. Wrapper | `MaterialApp(builder: (context, child) => SonnerHost(child: child!))` | The host sits above the `Navigator` for the life of the app |

### The z-order rule (mode 1)

`flash` inserts a **new** overlay entry per toast, so a new toast is always on top. A stack host is
inserted **once**.

**Routes do not cover it.** `Navigator` re-orders its overlay on every push — `_flushHistoryUpdates`
calls `overlay.rearrange(_allRouteOverlayEntries)` (`navigator.dart:4568-4570`), and `rearrange`
keeps every **non-route** entry as a group on top (`overlay.dart:772-822`). The host rises above
each new dialog or page on the first frame, with no help from this package. Read and probed against
Flutter 3.41.9 (`00b0c91f06`) in the [overlay research](https://github.com/kihyun1998/just_sonner/blob/research/overlay-reraise/research/overlay-reraise.md).

What *can* sit above the host is an entry another package inserts **directly** into the same
overlay afterwards: flash's per-toast entries, `Draggable` feedback, a hero flight during a route
transition. `OverlayState` exposes no entry order and no insertion hook — `_entries` is private and
`debugIsVisible` is debug-only — so there is no way to ask whether anything is above. The rule is
therefore unconditional:

> **Every `show` re-raises the host to the top of the overlay**, with
> `overlay.rearrange([host], below: host)` — one synchronous call that keeps the host's State and
> its running animations.

**`update` does not re-raise.** Replace (`show(id:)`) and every `promise` state go through `show`,
so each transition that matters is covered, while a progress toast driven by repeated `update`
(§4) does not rebuild the overlay on every tick. (This settles §11 Q2.)

Consequences, stated so nobody expects otherwise:

- **Toasts render above dialogs and pushed pages**, including above a modal barrier: they stay
  visible and tappable while a dialog is open. This is what §10 already asks for, and it now holds
  whether the toast was shown before or after the dialog.
- A toast is covered only by an entry inserted directly into the overlay since the last `show`, or
  by an overlay **higher** than the host's.
- `attach` must be given the **root** navigator's key. A nested navigator's key puts the host in a
  lower overlay, where `showDialog` — whose `useRootNavigator` defaults to `true` — lands above it
  and no amount of re-raising helps. Caught in debug:

  ```dart
  assert(Overlay.maybeOf(navigator.context, rootOverlay: true) == null,
      'attach() needs the root navigator key, or dialogs will cover toasts. '
      'Use mount mode 2 (SonnerHost) instead.');
  ```

  `navigator.context` is above the navigator's own overlay, so the lookup finds an overlay only
  when there is one *above* the navigator — which is exactly the mistake. It runs in `attach` when
  the navigator is already built, and on every `show`.

  The same assert catches an `Overlay` added in `MaterialApp.builder`, which also sits above the
  navigator's — use mode 2 there.
- The overlay is read from `navigatorKey` on each use and **never cached**:
  `NavigatorState.restoreState` replaces its overlay key with a fresh `GlobalKey`
  (`navigator.dart:3825-3828`), after which a host held in the old overlay is gone and its
  `remove()` is silently a no-op.

Mode 2 has no such rule — the host is above every route for the life of the app.

Mode 1 must fail loudly rather than silently: once a controller is attached, showing a toast while
its navigator is not built or has no overlay throws a `StateError` in debug and drops the toast with
a single `debugPrint` in release. A **replace** in that state is applied all the same — the toast
takes the new content and counts down again, and only the raise is skipped — and then throws or
prints the same way. A controller that was never attached is not in mode 1 and is not
checked — mode 2 and unit tests show toasts on one.

The host goes into the overlay on the first `show`, so `attach` can be called before the app is
built. When a `show` during a build has to insert or raise the host, the overlay is changed at the
end of that frame, since it cannot change mid-build; attaching elsewhere or disposing before then
cancels it. When the overlay the host was inserted into has been replaced, the next `show` inserts it
into the new one. Attaching another navigator takes the host out of the old overlay; `detach` and
disposing the controller take it out altogether, and after `detach` the controller is not in mode 1.

The host's entry keeps its State under an opaque entry (`maintainState: true`), so being covered
and uncovered does not make the toasts enter again; their animations wait while it is covered.

## 6. Layout and animation

Numbers from sonner (`src/index.tsx`, `src/styles.css`) unless marked.

### Collapsed (the deck)

- Only `visibleToasts` are painted; older ones are kept in the list but not painted and not
  hit-testable. A toast outside the window is announced when it reaches it, not when it is shown.
- The front toast is drawn at its own height.
- Toast *i* behind the front (i = 1, 2, …) is drawn **at the front toast's height**, shifted away
  from the screen edge by `gap × i`, and scaled by `1 − 0.05 × i`. Its content is not faded — a
  builder decides that (sonner fades only its own styled toasts).
- The deck occupies the front toast's height plus `gap × (visible − 1)` (just_sonner — sonner
  leaves the region to CSS).
- The window counts only toasts that are not dismissed, so dismissing the front brings the next
  toast in at once. A toast crossing the window's edge fades as it moves across it, on the clock
  of the toast entering or leaving, and takes no taps once it is outside.
- A toast behind that is shorter than the front is stretched to its height, and one that is taller
  is cut to it.
- While a toast enters or leaves, the toasts behind it are drawn at a height between its own and
  the one before it, in proportion to how far in it is. A toast brought to the front grows or
  shrinks to its own height the same way.
- A front whose own height changes in place (an update or replace with a longer or shorter
  content, or anything else that re-wraps it) is drawn at its new height at once, and the toasts
  behind it ease from the old height to the new over 400 ms, `ease` (sonner transitions `height`
  on the toasts behind only; the front is `height: auto`). A change during the ease goes on from
  where the ease got to. Only the height a toast covers the ones behind with eases: a toast is
  always drawn from the height it measures, so one entering or leaving mid-ease moves no toast
  in a single frame.
- An exiting toast keeps the distance from the edge, the scale, the height and whether it takes
  taps that it had when it was dismissed.

### Expanded

- Every visible toast is drawn at its **measured** height, stacked with `gap` between them. Toast
  *i*'s offset is the sum of the heights before it plus `gap × i`.
- Heights are measured after layout. A toast whose height changes (an update with a longer
  description) re-lays the stack.
- The hover region includes the gaps, so moving the pointer between two toasts does not collapse
  the deck.

### Motion

| Event | Motion | Duration | Source |
|---|---|---|---|
| Enter | slide in from the screen edge + fade | 400 ms, `ease` | sonner `styles.css` (`transform 400ms, opacity 400ms, height 400ms`) |
| Collapse ↔ expand | offsets, scales and heights animate | 400 ms | same transition |
| Exit (dismiss or timeout) | slide toward the edge + fade; the rest close the gap | removed from the tree after 200 ms | sonner `TIME_BEFORE_UNMOUNT` |
| Swipe out | continue in the swipe direction + fade | 200 ms | just_sonner |
| Update / replace | the new content fades in over the old, linearly, while the old stays fully opaque underneath and goes once the new is in; an update arriving mid-fade makes the half-faded content the opaque base, so the card is never see-through and there are at most two layers (the two builders' output, if the builder changed). No re-enter. The new content sets the toast's height at once; the old lies over it from the top, cut to that height, and is not announced | 200 ms | just_sonner |
| `config` assigned | offsets, scales and heights animate to the new config, in place; no toast re-enters or exits. Toasts that fall outside a lowered `visibleToasts` stop being painted, exactly as when a newer toast pushes them out | 400 ms | just_sonner |

## 7. Timers

- Each toast counts down its own remaining time.
- **Only the toasts within `visibleToasts` count down.** The ones behind them wait their turn, so
  no toast expires without having been on screen.
- **A toast's duration is fixed when it reaches the visible window** and does not change
  afterwards. An explicit `duration` on `show` always wins. Otherwise it takes
  `config.backlogDuration` if any toast is still waiting behind it, and `config.duration` if none
  is — so a burst drains quickly while each toast is still seen, and the last one gets its full
  time. A toast whose backlog empties mid-countdown keeps the short duration it entered with;
  nothing stretches back out under the reader.
- **All** timers pause while any of these holds, and resume with the time that was left:
  - **the pointer is over the deck** (the hover region of §6, gaps included). The trigger is the
    pointer, not the expansion — a lone toast has nothing to fan out but still pauses under the
    cursor, which is the most common case of all. `expandByDefault` does **not** pause: it is not
    hover.
  - **a toast is being dragged**, and it keeps pausing after the drag carries the pointer off the
    deck.
  - the app is **`hidden`, `paused` or `detached`**.

  A pointer-down that never becomes a drag needs no rule of its own: pressing something in the
  deck means the pointer is over the deck, which already pauses. (sonner has a separate
  `interacting` flag for this; its other job, keeping the deck expanded until pointer-up, is a
  collapse rule, not a timer one.)

  **`inactive` does not pause.** The app is still on screen there — Flutter's own docs describe it
  as "at least one view is visible, but none have input focus" — on desktop, a window that merely
  lost focus while staying fully on screen. Pausing for
  those would leave a pile of stale toasts waiting whenever the user comes back. `hidden` is the
  state Flutter **synthesises** before `paused` so that one handler covers "conceptually hidden"
  on every platform, which is exactly what is wanted here.
- Toasts with `isLoading` and `Duration.zero` toasts have no timer.
- A toast stops counting when it is **dismissed**, not when it is **removed** — its exit takes
  200 ms more (§6) and there is nothing left to count.
- **How the countdown runs.** One `Timer.periodic` of **100 ms**, alive only while some toast has
  a timer, subtracts a tick from every counting toast; a toast whose remainder reaches zero is
  dismissed. Pausing is not subtracting. **The controller never reads a clock**, so it needs no
  time source injected and none of `package:clock`, `Stopwatch` or `DateTime.now` appears in it —
  `Timer` alone is what the tests fake (§10).

  The cost is granularity, and a toast never runs short. The toast that starts the tick runs its
  duration rounded up to a whole tick. One shown while the tick is already running cannot know
  how far into the current tick it arrived, so it lets that partial tick pass uncounted and runs
  up to one tick longer than that — a 4 s toast lives 4.0–4.1 s, a 150 ms one up to 300 ms. That
  is invisible against the 200-400 ms motion in §6, and it is not configurable.

  The gain is that "time left" is a number the controller owns rather than one it derives from two
  clock readings. sonner derives it, and needs a guard so a pause is not subtracted twice
  ([research #2 row 25](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md)).
  That bug cannot be written here.
- `holdTimer()` exists for builders that run their own gestures (flash's `FlashBar` calls
  `deactivate` when a fling starts): it pauses that toast until it is dismissed, updated or replaced.

## 8. Swipe

- Directions default from the position's own words (sonner `getDefaultSwipeDirections`):
  `top-right` allows up and right, `bottom-left` allows down and left, `top-center` allows up only.
- Dismiss when the drag passes 45 px or its speed is above 0.11 px/ms (distance over the time since
  the pointer went down), in an allowed direction; otherwise spring back.
- `dismissible: false` disables swipe and the close button — the two ways a **user** dismisses a
  toast. It does not affect `dismiss(id)` or `ToastView.dismiss()`, which the app, or a widget in
  the `action` slot, can always call.
- **`dismissible` is `bool?`, and unset means `!isLoading`.** A loading toast cannot be swept away
  by default, and becomes dismissible on its own the moment it stops loading. An app that wants a
  loading toast the user *can* close says `dismissible: true`; one that wants an ordinary toast
  pinned says `dismissible: false`.

  It is stored as given, **including unset**, and resolved against `isLoading` on each read rather
  than frozen when the toast was shown — that is what lets `update(id, isLoading: false)` hand the
  toast back to the user without the caller restating `dismissible`.

  This keeps one handle rather than two. sonner blocks swipe and the close button on `loading`
  outright, *on top of* its own `dismissible`, so an app there cannot ask for a closeable loading
  toast at all ([research #2 row 17](https://github.com/kihyun1998/just_sonner/blob/research/sonner-values/research/sonner-values.md)).

## 9. Default look

- Surface from `Theme.of(context).colorScheme` (`surfaceContainerHigh`, `outlineVariant` border,
  8 px radius), text from `textTheme` — a just_sonner proposal, to be settled in the example app.
- Leading slot: the toast's `leading` widget, or `config.loadingIndicator` while `isLoading`. A
  toast with neither gets **no slot at all** — the title starts at the padding edge. The slot is a
  centred box of `config.leadingSize` (20) and is **fixed**, so a parent that imposes a minimum
  width cannot stretch the spinner into an ellipse (observed with flash's `FlashBar`, which wraps
  its icon in `minWidth: 42`).
- Title, optional description, then the `action` slot at the trailing edge (§4 Slots). The close
  button sits in the corner whenever `closeButton` resolves true.
- `Semantics(liveRegion: true)` on each toast; toasts never request focus.

## 10. Proof

### Controller (unit, `fake_async` — a dev dependency; nothing is injected)

- `show` returns distinct ids; newest first
- `update` changes only the fields passed and keeps position; returns false for an unknown id
- `show(id:)` on a toast on screen replaces it whole: an omitted `description`, `action` or `builder` is cleared
- leaving `isLoading` starts the timer; entering `isLoading` stops it
- any `update` or replace restarts the countdown, including one that changes only `dismissible`
- a replace resets an unset `duration` to `config.duration`, not to `backlogDuration`
- `show(id:)` after dismissal creates a new toast with no leaked fields
- `update` and replace keep the toast's record, so the host keeps its slot
- `promise` success and failure both replace the same id, each with its own content, and return the future's own outcome
- `promise(id:)` takes over a toast already on screen
- timers pause on hover, drag and lifecycle; resume with the remaining time
- a single toast pauses under the pointer, and `expandByDefault` alone does not pause
- `inactive` does not pause; `hidden` does
- a toast beyond `visibleToasts` does not count down, and starts at `backlogDuration` when it
  reaches the window with toasts still behind it, at `duration` when none are
- an explicit `duration` on `show` is used even while there is a backlog
- the tick stops when the last counting toast goes, and starts again with the next one
- assigning `config` notifies, and a lowered `visibleToasts` leaves the hidden toasts in the list

### Host (widget tests)

- Collapsed offsets and scales for 1, 2, 3 and 5 toasts
- Expanded offsets with toasts of **different heights**
- Only `visibleToasts` are hit-testable
- Swipe below and above the threshold
- **Mode 1 z-order: a toast shown while a dialog is open appears above the dialog**
- **and a toast shown *before* a dialog opens is still above it afterwards**
- `update` does not re-raise the host; `show`, replace and each `promise` state do
- a re-raise keeps the host's State and a running animation
- `attach` with a non-root navigator key asserts in debug
- once attached, a `show` with no built navigator throws in debug and keeps no toast; a replace
  throws too but is still applied
- A builder receives an animation that runs 0→1 on enter and 1→0 on exit
- An update or replace changes the toast in place without entering again, and its new content
  fades in over the old in 200 ms with the old opaque underneath; one arriving mid-fade makes the
  half-faded content the base; the outgoing content is not announced, and the incoming is from its
  first frame
- An update mid-enter keeps the enter going
- A toast entering, leaving or updated as the front leaves moves no toast in one frame mid-ease
- A front whose height changes in place jumps to it, and the toasts behind ease to it over 400 ms
- A toast shown at the id of one still exiting enters beside it
- A change of builder fades the new one in over the old, and the old builder does not receive pointer events
- An `action` slot receives the toast, and can dismiss it or leave it standing
- an unset `dismissible` blocks swipe and the close button while `isLoading`, and stops blocking
  when `update(id, isLoading: false)` lands, with no second call
- `dismissible: true` on a loading toast leaves it swipeable
- a `promise` whose loading toast was dismissed still delivers its result, as a new toast
- `closeButton` on a toast wins over the config; `dismissible: false` disables swipe and the close
  button but not `dismiss(id)`

Every test is reddened once before it is trusted: remove the rule it guards and watch it fail.

### Example app

Mirrors the checks above as buttons: five toasts in a row, a toast with a `leading` widget and one
without, loading → done, loading → failed, two promises at once, a toast over an open dialog
(mode 1), position / expand / visible-count controls, light and dark, and a builder that wraps a
flash `FlashBar` through the adapter in §1.

## 11. Open questions (for review)

None. Each one is now a row in §12 with the reasoning behind it, and the work deliberately left
outside v0.1 is in §2's non-goals.

## 12. Decision record

| Decision | Who | Basis |
|---|---|---|
| Open source, separate repository, not a package inside the consuming app | maintainer | wants reuse beyond one app |
| Default look **and** a builder that replaces it | maintainer | adoption; existing packages are headless only |
| Both mount modes, root overlay by default | maintainer | service-layer callers, flash parity |
| v0.1 covers everything the first consumer needs (§2) | maintainer | the consumer's migration ends at v0.1 |
| Layout constants follow sonner | derived | the reference implementation; changeable by measurement |
| Mode-1 z-order rule (§5) | derived | follows from a single long-lived overlay entry |
| Item exposes `AnimationController` | derived | makes flash-based widgets fit without redrawing; verified in a spike |
| Entry point is an exported default instance `final toast = SonnerController()`, no static facade and no `call` | maintainer | one API surface instead of a forwarding copy; `toast.show(…)` reads without knowing sonner; name clashes fail at compile time |
| ~~Type helpers take every `show` parameter except `type`~~ | maintainer | **Superseded**: the type helpers and `ToastType` are gone (row below) |
| `attach` is an instance method; `SonnerHost` takes an optional controller, `toast` by default | maintainer | follows from the instance entry point; widget tests get their own controller |
| `promise` states take a `ToastContent` each, replacing the shared `description`; `promise` accepts `id` | maintainer | one description under loading and result reads wrong; sonner's extended result without a union type; a multi-step flow hands its loading toast to `promise` |
| Update patches, replace swaps whole (§4) | maintainer | Dart cannot tell a parameter not passed from `null`, so clearing a field needs its own verb |
| `update` and replace can change the builder | maintainer | replace already takes `builder`; sonner's `custom` replaces a toast's look in place |
| **Reversal**: `ToastType` and the `success` / `info` / `warning` / `error` / `loading` helpers are removed. `show(isLoading:)` carries the only type that ever meant anything, and a caller-supplied `leading` widget carries the look | maintainer | the package never read `type` to decide anything — it only picked an icon, and what counts as an error is the calling app's judgement. §1's four differentiators never included the preset set, so removing it does not weaken the case for the package. A `leading` widget gives the caller icon and colour in one parameter, without an enum the package would have to own and extend |
| The loading indicator and the leading slot's size live on `SonnerConfig` (`loadingIndicator`, `leadingSize` 20), not on `show` | maintainer | one spinner style per app; per-toast sizes would break the deck's alignment. The box stays fixed either way, for the `minWidth: 42` reason in §9 |
| A builder receives `isLoading` and `leading` through `ToastState` | maintainer | a builder that cannot see `isLoading` cannot know when to spin; `leading` beside it lets the flash `FlashBar` adapter place both |
| `action` is a `ToastSlot` — the caller's widget, handed the toast; one slot, not flash's `primaryAction` + `actions` | maintainer | flash takes widgets and wires neither, which is the `leading` decision again. Handing the toast over replaces flash's `controller` and spares the caller a `late final` id. It dissolves two questions: whether pressing dismisses (the widget's own callback decides) and whether a `cancel` slot is needed (a `Row` inside the one slot) |
| `config` is a settable property of the controller, with `copyWith`; `attach` and `SonnerHost` take none. On-screen toasts animate to a new config in place | maintainer | the exported `toast` is already constructed, so a post-construction path has to exist anyway — once it does, a second one on `attach` is duplication with a precedence rule to define. The controller is already a `ChangeNotifier`, so both mount modes get the same path for free, and §6 already animates offsets, scales and heights on collapse ↔ expand; a config change reuses it rather than inventing a rule |
| Re-raise the host on every `show` (so also on replace and each `promise` state), never on `update`; unconditionally, since nothing can be detected | maintainer | §5's premise was wrong: `Navigator` already lifts non-route entries above every pushed route, so dialogs and pages never covered the host (overlay research, probes A1-A5). What remains is another package's direct `overlay.insert`, which no public API can see — hence unconditional. Keying it to `show` covers every transition that matters, since replace and `promise` go through `show`, and spares an overlay rebuild per tick on the progress toast §4 now keeps alive |
| `dismissible` is `bool?`, unset meaning `!isLoading`, resolved on read rather than at `show` | maintainer | sonner blocks swipe and the close button on loading *in addition to* `dismissible`, giving one job to two handles and leaving "loading, but closeable" inexpressible — and that rule is policy, not a measurement, so the example reference does not carry it here. Deriving the default keeps a single handle, matches sonner out of the box, and makes a toast hand itself back when its work finishes. Resolving on read rather than at `show` is what makes that last part free |
| Any `update` or replace restarts the countdown, from the toast's own duration | maintainer | §1's motivating flow breaks otherwise — new content arriving on a toast with 1 s left would vanish before it is read. No field list: the only field that is not on screen is `dismissible`, so an exception would buy one case and cost a rule. Restarting also makes a frequently-updated progress toast stay up for free. `backlogDuration` is not re-applied, so a toast being read never shortens under the reader (§7) |
| Timers pause on **pointer-over-deck**, on a drag in progress, and on `hidden` / `paused` / `detached` — not on `inactive` | maintainer | keying the pause to the pointer rather than to expansion fixes the commonest case, one toast being read, which sonner misses by forcing `expanded` false at ≤ 1 toast (research #2 row 22). `inactive` means visible-but-unfocused, so pausing there banks stale toasts for the user's return; `hidden` is the state Flutter synthesises for "conceptually hidden" on every platform, and matches sonner's `document.hidden`. A bare pointer-down needs no rule — hover already covers it |
| Toasts beyond `visibleToasts` do not count down; a toast's duration is fixed on reaching the window — `backlogDuration` (300 ms) with a backlog behind it, `duration` without | maintainer | sonner counts hidden toasts down and lets them expire unseen, but its timer effect simply has no `isVisible` guard (research #2 row 26) — an omission rather than a decision, and sonner is an example. Waiting alone would make a burst of 10 take 13 s to clear; a short duration while backlogged clears it in about 2 s and still puts every toast on screen. Fixing it at entry keeps a nearly-expired toast from swelling back to full time under the reader |
| The countdown is one 100 ms `Timer.periodic` that subtracts; the controller reads no clock and takes none | maintainer | `Clock` is `package:clock`, which Flutter does not depend on — the old `SonnerController({Clock? clock})` already broke the §2 goal, and `Stopwatch` is not faked by `FakeAsync` so it cannot replace it. `Timer` is faked by both `testWidgets` and `fakeAsync`, so subtracting ticks needs no injection and leaves no test-only hole in the public API. It also removes the pause arithmetic that sonner needs a guard for |
| The tick is started again when a toast is shown in a different `Zone` from the one the running tick was created in | maintainer | a `Timer` is bound to its zone, and the exported `toast` outlives test zones: measured while working #18, a toast left counting by one test kept `_ticker` pointing at a timer in that test's finished fake-time zone, and every later test's toasts silently never expired. Shown against documenting "clean up inside the test body" instead, which leaves the failure silent. Only a zone change restarts it — restarting on every `show` would let a burst of toasts shown faster than one tick hold every countdown back. **Not decided**: whether the tick should move to the host, as `SnackBar`'s timer lives in `ScaffoldMessengerState`; §7 keeps it on the controller |
| A negative `duration` — on `show` or `SonnerConfig` — is a debug assertion; in release it keeps the toast like `Duration.zero` | maintainer | a duration computed as a deadline minus now can go negative, and silently pinning that toast hides the bug. Shown against dismissing at once (sonner's result, where a negative delay closes the toast) and against documenting it as pinned. `SonnerConfig`'s const constructor cannot compare `Duration`s, so the config is checked when a controller is constructed |
| `ToastId` is `extension type ToastId(Object value)`: a caller may make one, and a generated id's value is an object compared by identity | derived | sonner takes a caller's id, which §4's `show(id:)` already implies; an identity-compared value keeps a caller's `ToastId(0)` from ever colliding with a generated id, with no reserved range to document. An extension type costs nothing at runtime and keeps `==` on the value |
| Exit runs the enter's `ease` backwards over 200 ms, and the toasts behind close the gap over the same 200 ms, driven by the exiting toast's own animation | maintainer | shown sonner contradicting itself — `TIME_BEFORE_UNMOUNT = 200` is commented "equal to exit animation duration" while the front toast keeps its 400 ms transition and is cut off about 20% opaque, and neighbours move over 400 ms — against splitting the neighbours onto 400 ms, which needs a layout animation per toast. **Not decided**: whether neighbours move on their own 400 ms clock once §6's collapse ↔ expand animation exists (#22). The collapsed deck (#19) keeps them on the exiting toast's clock |
| A toast leaves the tree when its animation reports `dismissed`, which is the first tick **past** 200 ms; it is fully transparent at 200 ms | derived | #27 needs the animation reaching `dismissed` to count as removal, and `AnimationController` reports it only when elapsed time exceeds the duration (`_InterpolationSimulation.isDone` uses `>`, Flutter 3.41.9). An exiting toast keeps the distance from the edge it had when dismissed, as sonner freezes `offsetBeforeRemove`, and the newest toast paints on top, as sonner's `z-index: toasts.length - index` |
| The visible window counts only toasts not yet dismissed | derived | `CONTEXT.md`'s *dismissed* is already off screen for the API, and §7 fixes a toast's duration when it reaches the window, including from `dismiss` — so the host and the controller need the same window. sonner counts an exiting toast by its index until it is removed 200 ms later, so there the next toast appears only then (`isVisible = index + 1 <= visibleToasts`, `index.tsx:105`; `removeToast` after `TIME_BEFORE_UNMOUNT`) |
| A toast crossing the window's edge fades, driven by the toast entering or leaving; outside the window it takes no taps at once, and stops being painted when fully faded | derived | §6 says only that toasts outside are not painted; sonner fades `data-visible='false'` through its 400 ms opacity transition (`styles.css:319-322`) with `pointer-events: none` at once. Driving it by the moving toast's presence follows the exit row above rather than adding a clock |
| Toasts behind the front are stretched or cut to the front's height, and a toast's position in the deck is counted by the presence of the toasts in front of it, so offsets, scales, the window fade and drawn heights all move with the toast entering or leaving. A toast's position only ever moves toward its place in the deck, and stops there | derived | a toast entering (400 ms) and one leaving (200 ms) at once run on different clocks, so their presences alone would carry the toasts behind them forward and back again — fading a toast inside the window and flashing one outside it — although neither ends anywhere new; letting a position move only toward its place keeps a net-zero change still, and a mixed one from wobbling, without a layout animation per toast. sonner draws them at `--front-toast-height` and transitions `height` over 400 ms. just_sonner does not fade content behind the front (§6), so a taller toast's overflow would show below a top deck; cutting it is what "drawn at the front toast's height" leaves visible. Blending the height keeps a toast from jumping when one enters or leaves (a front whose own height changes in place is the row below); a toast's natural height is measured on every layout, as §6 Expanded already requires |
| When the front's own height changes in place, the toasts behind ease to it over 400 ms, `ease`, and the front itself is drawn at its new height at once | maintainer | shown while working #21 against leaving the toasts behind to jump in one frame and against easing the front as well. The spec was silent for the collapsed deck; sonner draws the toasts behind at `--front-toast-height` with `transition: height 400ms` and leaves the front at `height: auto`, which CSS does not transition (`styles.css:89, 297-301` at 8e4662b), so this follows sonner. **Not covered**: the expanded deck (#22), where every toast is drawn at its own measured height |
| A toast has two heights in the deck: the one it is **drawn** from (its measured height) and the one it **covers** the toasts behind with (the eased one). An exiting toast keeps the covering height it had when it was dismissed, as it keeps its drawn height | derived | found by the adversarial pass while working #21: with one height doing both jobs, a toast entering, leaving, or updated as the front leaves moved a toast 3.3–4.3 px in one frame (probes: 70 → 66.74 as a new toast entered mid-ease; 66.44 → 70 behind a front dismissed mid-ease; 65.72 → 70 when an exiting front was removed). The ease belongs to what the toasts behind are drawn at (sonner eases only their `height`), so only the covering height carries it; freezing it on exit extends the row above that an exiting toast keeps what it had |
| An update or replace changes the controller's `ToastRecord` in place — its state, its duration and its countdown — rather than making a new one | derived | the host matches slots to records by identity (#17), which is what lets a new toast at a dismissed id enter beside the old one while it exits; a new record for an update would make the toast exit and enter again. The countdown restarts through the same path `show` starts one by, so an update landing mid-tick skips the partial tick and never runs short (§7) |
| Once attached, a **replace** with no navigator to draw in is still applied to the controller — content, duration and restarted countdown — and only the raise is skipped; it throws `StateError` in debug after applying, as a new toast's `show` does | maintainer | shown while working #21 that the new-toast rule (drop in release) applied to a replace left the old toast on screen with its old content and countdown, so a pinned or loading toast could stay stuck, while `update` was never checked at all. Chosen over documenting that stale state, over dismissing the toast, and over deferring. Applying before the debug throw keeps the controller's state the same in both modes (derived), which is also what lets a test observe it |
| Update and replace **fade the new content in over the old**, which stays fully opaque underneath until the new is in; an update arriving mid-fade makes the half-faded content the opaque base | maintainer | shown while working #21, with probes: a symmetric 200 ms cross-fade fades the whole card, since the default look draws its own surface — one update dips it to about 75% opacity at 100 ms, and a toast updated in a loop (§4's progress example) never recovers, its newest content at 0.48 just before each next update at 100 ms, 0.24 at 50 ms, 0.00 at 16 ms; an update that changes nothing visible dips the same way. Chosen over no fade at all (sonner), over a cross-fade that snaps when interrupted (still 75% per lone update), and over keeping the cross-fade. **Not covered**: how a caller's builder with a translucent or rounded surface of its own reads over an opaque base (#27) |
| The fade is linear; the incoming content sets the height at once and the outgoing content lies over it from the top, cut to that height, ignoring the pointer and left out of semantics, while the incoming keeps its semantics at opacity 0. Content keeps its State as it moves underneath. The ease of the toasts behind starts in the frame that measures the new height | derived | sonner changes content with no fade at all, so the curve takes the framework's default. Sizing by the incoming content makes the front's height change once, at the start, where sizing by the taller of the two would hold a shrinking toast for 200 ms and then jump; it is also what the ease above eases toward. `RenderOpacity` drops a child's semantics at alpha 0 (`proxy_box.dart`), which left the toast with no label for one frame, hence `alwaysIncludeSemantics`. Keeping State matters once builders with state arrive (#27). Starting the ease in the measuring frame, with `animateWith` rather than a post-frame callback, keeps it from starting a frame late |
| An exiting toast keeps its scale, drawn height and whether it takes taps, as well as its distance from the edge, and still slides toward the edge | derived | a toast dismissed after leaving the window would otherwise take taps again while it fades out. It extends the frozen `offsetBeforeRemove` row above to the collapsed deck. §6 Motion says exit slides toward the edge, so sonner's `translateY(40%)` for a collapsed toast behind the front (`styles.css:339-343`) is not taken |
| `visibleToasts` outside 1 to 20 is a debug assertion, checked when a controller is constructed | maintainer | shown that 0 draws nothing and says nothing, and that the toast at the back is scaled by `1 − 0.05 × (visibleToasts − 1)`, which reaches 0 at 21. First shown, wrongly, as reaching 0 at 20 and approved as 1 to 19; corrected before it landed, and 1 to 20 was chosen over keeping 19 (5% is already unreadable) and over asserting only `≥ 1`, for the reason the negative-`duration` row gives: a silent result hides the bug |
| A toast outside the window is out of the semantics tree, and is announced as a live region when it reaches the window | maintainer | shown that hiding a toast with `Offstage` removes it from semantics, while sonner keeps hidden toasts inside its `aria-live` region and announces them when they are added. Chosen over announcing on `show` (which needs a hide that keeps semantics) and over deferring to #23, because it matches §7's promise that every toast reaches the screen — it is announced when it can be read. The wording of §6's first Collapsed line ("painted", not "laid out") is also the maintainer's: a hidden toast is laid out, since `Offstage` keeps its state |
| Mode 1 fails only on a controller that has been attached; a never-attached controller shows toasts as before | maintainer | shown that "show before `attach` throws" would also throw for every mode-2 app and every controller unit test, which never call `attach`. Chosen over also failing when no `SonnerHost` is listening (which throws for a `show` before `runApp` or before the host mounts) and over checking the exported `toast` alone; the cost accepted is that a mode-1 app which forgets `attach` shows nothing, silently |
| The root-navigator assert is `Overlay.maybeOf(navigator.context, rootOverlay: true) == null` | derived | the expression first written here, `Overlay.of(navigator.context, rootOverlay: true) == navigator.overlay`, throws for a correct root key: `navigator.context` is above the navigator's own overlay, so a plain `MaterialApp` has no overlay to find (probe while working #20, Flutter 3.41.9: `Overlay.of` throws for the root key, and `maybeOf` is null for it and non-null for a nested navigator and for an `Overlay` in `builder`) |
| A `show` during a build re-raises at the end of the frame; otherwise the re-raise is synchronous | derived | `OverlayState.insert` and `rearrange` call `setState`, which throws during a build (same probe). `OverlayEntry.remove` defers its own rebuild the same way (`overlay.dart`, `SchedulerPhase.persistentCallbacks`) |
| The host's entry is inserted on the first `show`, re-inserted when the navigator's overlay has been replaced, and removed by `attach` to another key and by `dispose` | derived | the navigator may not be built when `attach` is called after `runApp`. State restoration swaps the overlay and the old entry is no longer mounted (probe: `restartAndRestore` gives a new `OverlayState`), so the overlay the entry went into is compared with the one read from the key on each `show` |
| `SonnerController.detach()` undoes `attach`: the host leaves the overlay and the controller is no longer in mode 1 | maintainer | shown that once the exported `toast` is attached nothing returns it to "never attached", so a later mode-2 test that shows on `toast` throws `StateError` (probe while working #20) — the same shape as the tick outliving a test zone. Chosen over treating an unmounted navigator as unattached (which also silences a `show` before the app is built) and over only documenting it |
| The mode-1 host's entry uses `maintainState: true` | maintainer | shown that with the default `false` an opaque entry inserted over the host unbuilds it, and uncovering it replays every toast's enter while their countdowns kept running (probe while working #20); flash's own entries use `true`, which keeps State and freezes tickers while covered. Chosen over accepting the replay |
| `position` defaults to `bottomRight` | derived | the spec named no default; sonner's `Toaster` defaults to `'bottom-right'` (`index.tsx:608` at 8e4662b) |
| The close button is the package's, resolved `show(closeButton:) ?? config.closeButton` (false) | maintainer | a dismissal affordance, not content — the pointer equivalent of a swipe, which `dismissible` already governs; desktop-first (§1) makes drag-to-dismiss undiscoverable. Flutter's `SnackBar` and sonner resolve it the same way, instance over config |

### Verified in a throwaway spike (consumer repository, 2026-09-14)

- A real `FlashBar`-based widget renders inside a self-managed stack when each item implements
  `FlashController` itself — no `showFlash`, no flash overlay.
- flash's swipe flings the animation to 0 and only then calls `deactivate`; a host must treat
  **animation reaching `dismissed`** as removal, not wait for `dismiss`.
- In-place update (loading → result) and a spinner in the leading slot read as one toast.
- A fixed-overlap collapsed deck breaks when toasts differ in height — the reason §6 measures.
