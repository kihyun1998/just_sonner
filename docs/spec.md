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
- A default look for `success`, `info`, `warning`, `error`, `loading`, plain — light and dark from
  `Theme.of(context)`
- A builder that fully replaces the look and receives the animation and a dismiss handle
- Android, iOS, web, Windows, macOS, Linux; no dependency beyond Flutter

### Non-goals (v0.1)

- Several independent toasters at once (one host per app)
- A toast history / notification center
- Rich colors, custom fonts, icon packs — the builder is the escape hatch
- Keyboard shortcut to focus the toast region (sonner's `hotkey`)
- RTL mirroring beyond what `Directionality` gives for free

## 3. Vocabulary

| Term | Meaning |
|---|---|
| **toast** | One notification. Has an id, a state (type, title, description, …) and a lifetime |
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
  SonnerController({SonnerConfig config, Clock? clock});

  /// Mount mode 1 — insert this controller's host into the root overlay of [navigatorKey].
  void attach(GlobalKey<NavigatorState> navigatorKey, {SonnerConfig config});

  /// Shows a toast. An [id] that is on screen **replaces** that toast (see Update rules).
  ToastId show(String title, {
    String? description,
    ToastType type = ToastType.normal,
    Duration? duration,          // null → config.duration; Duration.zero → stays until dismissed
    bool dismissible = true,
    ToastAction? action,
    ToastId? id,
    ToastBuilder? builder,       // replaces the look for this toast only
  });

  // Every type helper takes what `show` takes except `type`; `loading` also drops `duration`.
  ToastId success(String title, {String? description, Duration? duration, bool dismissible = true,
      ToastAction? action, ToastId? id, ToastBuilder? builder});
  ToastId info(...);     // same parameters as success
  ToastId warning(...);  // same parameters as success
  ToastId error(...);    // same parameters as success
  ToastId loading(String title, {String? description, bool dismissible = true,
      ToastAction? action, ToastId? id, ToastBuilder? builder});   // no timer

  /// **Updates** a toast on screen: only the fields passed change. Returns false if it is gone.
  bool update(ToastId id, {String? title, String? description, ToastType? type,
      Duration? duration, bool? dismissible, ToastAction? action, ToastBuilder? builder});

  Future<T> promise<T>(Future<T> future, {
    required ToastContent loading,
    required ToastContent Function(T value) success,
    required ToastContent Function(Object error) error,
    ToastId? id,                 // same rule as show(id:)
  });

  void dismiss(ToastId id);
  void dismissAll();
}

/// The content of one `promise` state. Everything a type helper takes except `type` and `id`.
class ToastContent {
  const ToastContent(String title, {String? description, Duration? duration,
      bool dismissible = true, ToastAction? action, ToastBuilder? builder});
}

typedef ToastBuilder = Widget Function(BuildContext context, ToastView toast);

/// What a builder gets.
abstract interface class ToastView {
  ToastId get id;
  ToastState get state;                  // type, title, description, action, dismissible
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
`swipeDirections` (derived from position), `builder` (the default look when null). Hosts of two
controllers mounted at once are not coordinated (§2 non-goal).

### Update rules

Two ways to change a toast that is on screen, and they differ only in what happens to the fields
not given:

- **Update** — `update(id, …)`: a patch. A field passed as `null` or not passed keeps its value, so
  `update` cannot clear a field.
- **Replace** — `show(id: x)`, a type helper with `id: x`, or a `promise` state, where `x` is on
  screen: the new content replaces the old whole. A field not given takes its default —
  `description` and `action` disappear, `builder: null` returns to the default look.

Both:

- keep the toast's place in the deck and its enter animation; only the content changes.
- A toast leaving `loading` starts a timer of its (new or configured) duration. A toast entering
  `loading` stops its timer.
- A change of `builder` cross-fades the two builders' output (§6); the outgoing one ignores the
  pointer, so a builder with its own gestures (flash's `FlashBar`) cannot act while fading out.

Also:

- `show(id: x)` with an `x` that was already dismissed creates a **new** toast — the old one's
  fields do not leak into it (sonner `state.ts`, same rule).
- `promise` shows `loading` immediately (replacing the toast at `id` if one is on screen), then
  replaces it with `success(value)` or `error(error)`; the future's own result or error is returned
  unchanged to the caller. `duration` on the `loading` content is ignored (asserted in debug).
- A multi-step flow holds the id: `final id = toast.loading('Checking credentials…')`, then
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

> **Every `show` and every `update` that changes the type re-inserts the host at the top of the
> overlay** if anything has been inserted above it since.

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

## 7. Timers

- Each toast counts down its own remaining time.
- **All** timers pause while the deck is expanded by hover, while any toast is being dragged, or
  while the app is not `AppLifecycleState.resumed`; they resume with the time that was left.
- `loading` toasts and `Duration.zero` toasts have no timer.
- `holdTimer()` exists for builders that run their own gestures (flash's `FlashBar` calls
  `deactivate` when a fling starts): it pauses that toast until it is dismissed, updated or replaced.

## 8. Swipe

- Directions default from the position's own words (sonner `getDefaultSwipeDirections`):
  `top-right` allows up and right, `bottom-left` allows down and left, `top-center` allows up only.
- Dismiss when the drag passes 45 px or its speed is above 0.11 px/ms (distance over the time since
  the pointer went down), in an allowed direction; otherwise spring back.
- `dismissible: false` disables swipe and the close button.

## 9. Default look

- Surface from `Theme.of(context).colorScheme` (`surfaceContainerHigh`, `outlineVariant` border,
  8 px radius), text from `textTheme` — a just_sonner proposal, to be settled in the example app.
- Leading slot: an icon per type; **`loading` puts a spinner in the same slot**. The slot is a fixed
  20×20 centred box, so a parent that imposes a minimum width cannot stretch the spinner into an
  ellipse (observed with flash's `FlashBar`, which wraps its icon in `minWidth: 42`).
- Title, optional description, optional action button, optional close button.
- `Semantics(liveRegion: true)` on each toast; toasts never request focus.

## 10. Proof

### Controller (unit, fake clock)

- `show` returns distinct ids; newest first
- `update` changes only the fields passed and keeps position; returns false for an unknown id
- `show(id:)` on a toast on screen replaces it whole: an omitted `description`, `action` or `builder` is cleared
- `loading` → `success` starts the timer; `success` → `loading` stops it
- `show(id:)` after dismissal creates a new toast with no leaked fields
- `promise` success and failure both replace the same id, each with its own content, and return the future's own outcome
- `promise(id:)` takes over a toast already on screen
- timers pause on hover, drag and lifecycle; resume with the remaining time

### Host (widget tests)

- Collapsed offsets and scales for 1, 2, 3 and 5 toasts
- Expanded offsets with toasts of **different heights**
- Only `visibleToasts` are hit-testable
- Swipe below and above the threshold
- **Mode 1 z-order: a toast shown while a dialog is open appears above the dialog**
- Show before `attach` throws in debug
- A builder receives an animation that runs 0→1 on enter and 1→0 on exit
- A change of builder cross-fades, and the outgoing builder does not receive pointer events

Every test is reddened once before it is trusted: remove the rule it guards and watch it fail.

### Example app

Mirrors the checks above as buttons: each type, five in a row, loading → success, loading → error,
two promises at once, a toast over an open dialog (mode 1), position / expand / visible-count
controls, light and dark, and a builder that wraps a flash `FlashBar` through the adapter in §1.

## 11. Open questions (for review)

2. Should an `update` that does not change the type also re-raise the host in mode 1?
3. Should older toasts beyond `visibleToasts` still count down, or wait their turn?
4. `ToastType.normal` vs no type at all for the plain toast
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
| Entry point is an exported default instance `final toast = SonnerController()`, no static facade and no `call` | maintainer | one API surface instead of a forwarding copy; `toast.success(…)` reads without knowing sonner; name clashes fail at compile time |
| Type helpers take every `show` parameter except `type` | maintainer | an error with a Retry action is the common case; sonner's helpers take the full option set |
| `attach` is an instance method; `SonnerHost` takes an optional controller, `toast` by default | maintainer | follows from the instance entry point; widget tests get their own controller |
| `promise` states take a `ToastContent` each, replacing the shared `description`; `promise` accepts `id` | maintainer | one description under loading and result reads wrong; sonner's extended result without a union type; a multi-step flow hands its loading toast to `promise` |
| Update patches, replace swaps whole (§4) | maintainer | Dart cannot tell a parameter not passed from `null`, so clearing a field needs its own verb |
| `update` and replace can change the builder | maintainer | replace already takes `builder`; sonner's `custom` replaces a toast's look in place |

### Verified in a throwaway spike (consumer repository, 2026-09-14)

- A real `FlashBar`-based widget renders inside a self-managed stack when each item implements
  `FlashController` itself — no `showFlash`, no flash overlay.
- flash's swipe flings the animation to 0 and only then calls `deactivate`; a host must treat
  **animation reaching `dismissed`** as removal, not wait for `dismiss`.
- In-place update (loading → result) and a spinner in the icon slot read as one toast.
- A fixed-overlap collapsed deck breaks when toasts differ in height — the reason §6 measures.
