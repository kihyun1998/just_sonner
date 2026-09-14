# just_sonner — v0.1 specification

Status: **draft** (2026-09-14). Implementation has not started.

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
4. **Desktop first.** Hover expands the deck and pauses every timer; pointer drag swipes.

## 2. Goals and non-goals

### Goals (v0.1)

- Stack, collapse, expand on hover, pause on hover/interaction/app-hidden, swipe to dismiss
- Six positions, max visible count, width, gap, offset
- `show` returns an id; `update(id)`, `dismiss(id)`, `dismissAll()`, `promise(future)`
- Two mount modes (§5), root overlay by default
- One default look — light and dark from `Theme.of(context)` — with a leading slot the caller
  fills, and a spinner in that slot while a toast is loading
- A builder that fully replaces the look and receives the animation and a dismiss handle
- Android, iOS, web, Windows, macOS, Linux; no dependency beyond Flutter

### Non-goals (v0.1)

- Several independent toasters at once (one host per app)
- A toast history / notification center
- Semantic toast types (`success` / `error` / …) and the rich colors, custom fonts and icon packs
  that would follow from them — the caller fills the leading slot with its own widget, and the
  builder is the escape hatch for everything else
- Reporting that a toast went away and why — no callback, future or reason enum (sonner's
  `onDismiss` / `onAutoClose`, `SnackBarClosedReason`). A caller learns about its own button
  through the `action` slot's callback, and nothing else
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

  /// Shows a toast. An [id] that is on screen **replaces** that toast (see Update rules).
  ToastId show(String title, {
    String? description,
    bool isLoading = false,      // no timer; the leading slot holds config.loadingIndicator
    Widget? leading,             // fills the leading slot when the toast is not loading
    Duration? duration,          // null → config.duration; Duration.zero → stays until dismissed
    bool dismissible = true,
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
      bool dismissible = true, ToastSlot? action, bool? closeButton, ToastBuilder? builder});
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
```

A test, or an app that wants its own instance, constructs another `SonnerController`; it has the
same methods as `toast`. There is no static facade.

`SonnerHost({SonnerController? controller, required Widget child})` (mount mode 2) draws
`controller`, or `toast` when omitted. `SonnerConfig` carry: `position`, `width` (356), `gap` (14),
`offset` (24, mobile 16), `visibleToasts` (3), `duration` (4 s), `expandByDefault` (false),
`swipeDirections` (derived from position), `builder` (the default look when null),
`loadingIndicator` (what the leading slot holds while a toast is loading), `leadingSize` (20),
`closeButton` (false). It is immutable and has a `copyWith`, so one field changes with
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
- A toast leaving `isLoading` starts a timer of its (new or configured) duration. A toast
  entering it stops its timer.
- A change of `builder` cross-fades the two builders' output (§6); the outgoing one ignores the
  pointer, so a builder with its own gestures (flash's `FlashBar`) cannot act while fading out.

Also:

- `show(id: x)` with an `x` that was already dismissed creates a **new** toast — the old one's
  fields do not leak into it (sonner `state.ts`, same rule).
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
inserted **once** — a dialog or route pushed afterwards is inserted above it and covers the whole
deck, new toasts included. So in mode 1:

> **Every `show`, and every `update` that changes what the toast looks like, re-inserts the host
> at the top of the overlay** if anything has been inserted above it since.

Consequence, stated so nobody expects otherwise: a toast shown *before* a dialog opens is covered
by that dialog until the next toast or update, exactly as with flash. Mode 2 has no such rule —
the host is above every route.

Mode 1 must fail loudly rather than silently: showing a toast before `attach`, or while the
navigator has no overlay, throws a `StateError` in debug and drops the toast with a single
`debugPrint` in release.

## 6. Layout and animation

Numbers from sonner (`src/index.tsx`, `src/styles.css`) unless marked.

### Collapsed (the deck)

- Only `visibleToasts` are laid out; older ones are kept in the list but not painted and not
  hit-testable.
- The front toast is drawn at its own height.
- Toast *i* behind the front (i = 1, 2, …) is drawn **at the front toast's height**, shifted away
  from the screen edge by `gap × i`, and scaled by `1 − 0.05 × i`. Its content is not faded — a
  builder decides that (sonner fades only its own styled toasts).
- The deck occupies the front toast's height plus `gap × (visible − 1)` (just_sonner — sonner
  leaves the region to CSS).

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
| Update / replace | content cross-fades (the two builders' output, if the builder changed); no re-enter | 200 ms | just_sonner |
| `config` assigned | offsets, scales and heights animate to the new config, in place; no toast re-enters or exits. Toasts that fall outside a lowered `visibleToasts` stop being painted, exactly as when a newer toast pushes them out | 400 ms | just_sonner |

## 7. Timers

- Each toast counts down its own remaining time.
- **All** timers pause while the deck is expanded by hover, while any toast is being dragged, or
  while the app is not `AppLifecycleState.resumed`; they resume with the time that was left.
- Toasts with `isLoading` and `Duration.zero` toasts have no timer.
- **How the countdown runs.** One `Timer.periodic` of **100 ms**, alive only while some toast has
  a timer, subtracts a tick from every counting toast; a toast whose remainder reaches zero is
  dismissed. Pausing is not subtracting. **The controller never reads a clock**, so it needs no
  time source injected and none of `package:clock`, `Stopwatch` or `DateTime.now` appears in it —
  `Timer` alone is what the tests fake (§10).

  The cost is granularity: a toast shown between ticks runs up to one tick long. That is invisible
  against the 200-400 ms motion in §6, and it is not configurable.

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
- `show(id:)` after dismissal creates a new toast with no leaked fields
- `promise` success and failure both replace the same id, each with its own content, and return the future's own outcome
- `promise(id:)` takes over a toast already on screen
- timers pause on hover, drag and lifecycle; resume with the remaining time
- the tick stops when the last counting toast goes, and starts again with the next one
- assigning `config` notifies, and a lowered `visibleToasts` leaves the hidden toasts in the list

### Host (widget tests)

- Collapsed offsets and scales for 1, 2, 3 and 5 toasts
- Expanded offsets with toasts of **different heights**
- Only `visibleToasts` are hit-testable
- Swipe below and above the threshold
- **Mode 1 z-order: a toast shown while a dialog is open appears above the dialog**
- Show before `attach` throws in debug
- A builder receives an animation that runs 0→1 on enter and 1→0 on exit
- A change of builder cross-fades, and the outgoing builder does not receive pointer events
- An `action` slot receives the toast, and can dismiss it or leave it standing
- `closeButton` on a toast wins over the config; `dismissible: false` disables swipe and the close
  button but not `dismiss(id)`

Every test is reddened once before it is trusted: remove the rule it guards and watch it fail.

### Example app

Mirrors the checks above as buttons: five toasts in a row, a toast with a `leading` widget and one
without, loading → done, loading → failed, two promises at once, a toast over an open dialog
(mode 1), position / expand / visible-count controls, light and dark, and a builder that wraps a
flash `FlashBar` through the adapter in §1.

## 11. Open questions (for review)

2. Should an `update` re-raise the host in mode 1, or only a `show`?
3. Should older toasts beyond `visibleToasts` still count down, or wait their turn?
5. Mobile: honour `MediaQuery.viewPadding` for the offset automatically?

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
| The countdown is one 100 ms `Timer.periodic` that subtracts; the controller reads no clock and takes none | maintainer | `Clock` is `package:clock`, which Flutter does not depend on — the old `SonnerController({Clock? clock})` already broke the §2 goal, and `Stopwatch` is not faked by `FakeAsync` so it cannot replace it. `Timer` is faked by both `testWidgets` and `fakeAsync`, so subtracting ticks needs no injection and leaves no test-only hole in the public API. It also removes the pause arithmetic that sonner needs a guard for |
| The close button is the package's, resolved `show(closeButton:) ?? config.closeButton` (false) | maintainer | a dismissal affordance, not content — the pointer equivalent of a swipe, which `dismissible` already governs; desktop-first (§1) makes drag-to-dismiss undiscoverable. Flutter's `SnackBar` and sonner resolve it the same way, instance over config |

### Verified in a throwaway spike (consumer repository, 2026-09-14)

- A real `FlashBar`-based widget renders inside a self-managed stack when each item implements
  `FlashController` itself — no `showFlash`, no flash overlay.
- flash's swipe flings the animation to 0 and only then calls `deactivate`; a host must treat
  **animation reaching `dismissed`** as removal, not wait for `dismiss`.
- In-place update (loading → result) and a spinner in the leading slot read as one toast.
- A fixed-overlap collapsed deck breaks when toasts differ in height — the reason §6 measures.
