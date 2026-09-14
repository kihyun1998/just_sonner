# Can an overlay host detect entries above it and re-raise itself?

Resolves [#3](https://github.com/kihyun1998/just_sonner/issues/3). Question against
[spec §5 "The z-order rule"](../docs/spec.md#the-z-order-rule-mode-1).

**Sources.** Flutter **3.41.9** stable, framework revision `00b0c91f06` (Dart 3.11.5), read from the
local SDK at `D:\flutter\packages\flutter\lib\src\`. All `file:line` refer to that tree
(`widgets/overlay.dart`, `widgets/navigator.dart`, `widgets/routes.dart`, `widgets/framework.dart`,
`widgets/heroes.dart`, `widgets/drag_target.dart`, `material/dialog.dart`).

**Probe.** Every runtime claim below marked *(probe)* was pinned with a throwaway `flutter test`
on the same SDK (scenarios A–E, output quoted at the end). Z-order was read from element pre-order
inside the overlay (a later sibling subtree paints on top); State identity from `initState`/`dispose`
counters; tickers from an `AnimationController` started in `initState`.

## Short answer

1. **The premise of §5 is wrong for routes.** A dialog or route pushed through the `Navigator` does
   **not** land above a host that was inserted into `navigator.overlay`. Every push flushes history
   with `overlay.rearrange(routeEntries)`, and `rearrange` puts every *non-route* entry back on top.
   The host rises above the new dialog / page automatically, on the very first frame.
2. What *can* sit above the host is only an entry inserted **directly** into the same overlay after
   it (another overlay package such as flash, drag feedback, hero flights during a transition), or
   something in a **different, higher** overlay (nested navigator + `useRootNavigator: true` dialog,
   an `Overlay` added in `MaterialApp.builder`).
3. `OverlayState` exposes **no** public entry order and **no** insertion hook. There is no cheap
   public "is something above me" test.
4. Re-raising is cheap and **keeps State and running AnimationControllers**, provided it happens in
   one synchronous step: `overlay.rearrange([host], below: host)` (one call) or `host.remove()`
   immediately followed by `overlay.insert(host)`. The entry's built subtree is keyed by a private
   per-entry `GlobalKey`, so it is moved, not rebuilt. A frame in between removal and re-insertion
   loses the State.

## 1. Does `OverlayState` expose entry order or an insertion hook?

No.

- The list is private: `final List<OverlayEntry> _entries` — `overlay.dart:627`. Nothing public
  reads it; it only appears in `debugFillProperties` — `overlay.dart:901`.
- `insert` / `insertAll` / `rearrange` just mutate `_entries` inside `setState`; no callback, no
  notifier — `overlay.dart:718-725`, `734-747`, `789-822`.
- `OverlayEntry implements Listenable`, but it notifies only when **`mounted`** flips (its
  `_OverlayEntryWidgetState` is created or disposed), not on reordering — `overlay.dart:192-205`,
  set in `initState` / `dispose` at `overlay.dart:389-393`, `409-414`.
- `OverlayState.debugIsVisible(entry)` walks the list top-down but only answers "is it behind an
  *opaque* entry", and is **debug-only — always `false` in release** — `overlay.dart:830-853`.
- `Overlay` has no `onChanged`-style parameter; `Navigator` exposes route events through
  `NavigatorObserver` (`navigator.dart:755-805`) and `didChangeTop` (`navigator.dart:4547-4553`),
  but those cover routes only, never raw `overlay.insert` calls.

## 2. Cost and side effects: `remove()` + `insert()` vs `rearrange(...)`

### Why State survives a synchronous move

- Each `OverlayEntry` owns `final GlobalKey<_OverlayEntryWidgetState> _key` — `overlay.dart:213`.
- `OverlayState.build` emits one `_OverlayEntryWidget(key: entry._key, ...)` per built entry —
  `overlay.dart:864-893`. All entries are children of one `_Theater`
  (`MultiChildRenderObjectWidget`, `overlay.dart:948`).
- Reordering therefore goes through keyed child reconciliation (`framework.dart:4125`, keyed match
  at `4217-4246`): the existing element is **moved** to its new slot (`_TheaterElement.moveRenderObjectChild`,
  `overlay.dart:1003-1017`), the entry's State and everything under it are kept.
- `remove()` only takes the entry out of `_entries` and marks the overlay dirty
  (`overlay.dart:225-242`); it does not unmount anything by itself. If `insert` runs before the next
  build, the build sees the same key again and moves the element.
- If a **frame passes** between `remove()` and `insert()`, the element goes inactive and is unmounted
  in `BuildOwner.finalizeTree` (`framework.dart:3339-3344`) — State disposed, controllers disposed,
  re-insertion creates fresh State.

*(probe B3)* synchronous `remove(); insert()` → host on top, same State (`init#2` only), controller
kept advancing (`0.1 -> 0.11`, `isAnimating=true`).
*(probe B5)* `remove(); pump(); insert()` → `dispose#2, init#3`: State recreated.

### `rearrange` semantics and the one-call re-raise

`rearrange(newEntries, {below, above})` — `overlay.dart:772-822`: the listed entries are laid out in
the given order; **every unmentioned entry is kept as a group**, placed just `below:` / `above:` the
anchor, or, with no anchor, **on top** (`_insertionIndex` returns `_entries.length`,
`overlay.dart:636-645`; group insert at `820`).

So `overlay.rearrange([host], below: host)` = "everything else, then host" = host on top in one
call, no `_overlay` reset, no assertion risk from double insert. It returns early only when
`_entries` already equals `[host]` (`overlay.dart:809`). When the host is already on top it still
does one `setState` on the overlay.

*(probe E2/E3)* host raised above a foreign entry, same State (`init#1`), controller advancing; a
repeat call when already on top is harmless.

Cost of any variant: one rebuild of `OverlayState` — O(entries) widget construction, and for each
**onstage** entry `_OverlayEntryWidgetState.build` re-creates `Builder(builder: entry.builder)`
(`overlay.dart:418-428`), so every visible entry's `builder` closure runs again. That is exactly what
the Navigator already pays on every push (§4 below); route builders return cached subtrees.

Do **not** use `rearrange` with a partial list and no anchor to "put these two in order": the
unmentioned route entries go on top of them. *(probe B4)* `rearrange([other, host], above: other)`
put the routes between `other` and `host`; `other` ended up under the opaque home route and was not
built at all.

### `OverlayEntry(maintainState:)`

It matters only when the host is **below an opaque entry** — `overlay.dart:147-161`, `864-893`:

- `maintainState: false` (default): entries under the first opaque entry are **not built** → State
  disposed; when uncovered, State is recreated. *(probe C1/C2)* `init#4, dispose#4, init#5`.
- `maintainState: true`: built offstage with `tickerEnabled: false` → `TickerMode(enabled: false)`
  (`overlay.dart:877-885`, `419-420`) → State kept, but **every ticker-driven animation is frozen**
  while covered. *(probe C3)* controller `0.0 -> 0.0` over 1 s. Dart `Timer`s are unaffected.
- Route page entries become opaque when their transition completes
  (`TransitionRoute._handleStatusChanged`, `routes.dart:292-306`); dialogs never do (`PopupRoute.opaque
  => false`, `routes.dart:2393-2394`).

Because pushes lift the host (§4), a host in `navigator.overlay` is not normally under an opaque page;
the case arises only if something re-orders entries so that route entries are above it (e.g. the
partial `rearrange` above) or the host is in a lower overlay than the page.

### Keeping state across re-insertion by other means

The built-in per-entry `GlobalKey` already does it within one frame. A user-level `GlobalKey` on the
host widget can additionally move the host subtree between two `OverlayEntry` objects (or overlays)
in the same frame via `_retakeInactiveElement` (`framework.dart:4481-4500`), but it has the same
"same frame" limit (`finalizeTree`, `framework.dart:3339-3344`). The robust design is to keep toast
data and timers in the controller (outside the widget) so that a recreated host is only a visual loss.

## 3. `navigatorKey.currentState!.overlay` vs `Overlay.of(context, rootOverlay: true)`

- `NavigatorState.overlay` is simply that navigator's own `Overlay` — `navigator.dart:4102`, built
  with `key: _overlayKey` at `navigator.dart:5928-5933`.
- `Overlay.of(context, rootOverlay: true)` returns the **furthest** `Overlay` ancestor of `context`
  (within the nearest `LookupBoundary`) — `overlay.dart:542-545`, `610-616`, `2226-2235`.
- `WidgetsApp` / `MaterialApp` add no `Overlay` of their own above the navigator (no `Overlay(` or
  `Overlay.wrap` in `widgets/app.dart`, `material/app.dart`, `cupertino/app.dart`).

They are equal in a plain app and differ when:

| Setup | Equal? | Probe |
|---|---|---|
| Plain `MaterialApp(navigatorKey:)` | yes | D0 `true` |
| `MaterialApp(builder: (c, child) => Overlay.wrap(child: child!))` (or any `Overlay` in `builder`) — the wrapper overlay is above the navigator | **no**; the navigator overlay is only the *nearest* one | D1 `root? false, nearest? true` |
| `navigatorKey` on a nested `Navigator` | **no** | D2 `false` |

Also: `NavigatorState.restoreState` replaces `_overlayKey` with a fresh `GlobalKey`, i.e. **a new
`OverlayState`** (`navigator.dart:3825-3828`); a host inserted into the old overlay is gone
(its `remove()` becomes a no-op because `!overlay.mounted`, `overlay.dart:228-232`). A cached
`OverlayState` must be re-read from `navigatorKey` rather than kept.

## 4. Where `showDialog` and `Navigator.push` put their entries

- `showDialog` → `Navigator.of(context, rootNavigator: useRootNavigator).push(DialogRoute(...))`
  — `material/dialog.dart:1484-1507`; `useRootNavigator` defaults to **`true`** (`dialog.dart:1491`).
  `rootNavigator: true` picks `findRootAncestorStateOfType<NavigatorState>()` — `navigator.dart:2917-2925`.
- A route's entries are created in `OverlayRoute.install` (`routes.dart:68-72`) — for `ModalRoute`
  two entries, barrier + scope (`routes.dart:2353-2362`). `install` does **not** insert them.
- The navigator inserts them only through `_flushHistoryUpdates` →
  `if (rearrangeOverlay) overlay?.rearrange(_allRouteOverlayEntries)` — `navigator.dart:4568-4570`,
  where `_allRouteOverlayEntries` is the route entries in history order (`navigator.dart:4104-4106`).
  No `insert`/`insertAll(above:)` is used for routes.
- `rearrange` with no anchor leaves **all non-route entries on top, in their existing relative
  order** (§2). `push`, `pushReplacement`, `pushAndRemoveUntil`, `replace`, `replaceRouteBelow`, the
  `pages` API (`_updatePages`, `navigator.dart:4395`) and the push-completion flush
  (`navigator.dart:3254`) all use the default `rearrangeOverlay = true`
  (e.g. `_pushEntry`, `navigator.dart:5063-5078`). `pop`, `removeRoute`, `removeRouteBelow`,
  `finalizeRoute` pass `rearrangeOverlay: false` (`navigator.dart:5611`, `5687`, `5724`, `5771`) —
  they only remove entries, which cannot put anything above the host.

*(probe A1-A5)* host inserted into `navigatorKey.currentState!.overlay`, then `showDialog` → host on
top on the first frame and after settling; then `push(MaterialPageRoute)` → host on top on the first
frame and after settling; same State throughout (`init#1` only).

**`useRootNavigator` does matter**, but only when the host is not in the root navigator's overlay:
*(probe D3)* host in a nested navigator's overlay + `showDialog` (default `true`) → dialog on top
(it is in the outer overlay; no re-raise inside the inner overlay can help). *(probe D4)* same host +
`useRootNavigator: false` → host on top.

What does go above the host in its own overlay:

- **Direct `overlay.insert` after the host** — another package's entries (flash's per-toast entries),
  `Draggable` feedback (`drag_target.dart:849`), hero flights inserted into `navigator.overlay` during
  a route transition and removed when it ends (`heroes.dart:965`, `710`). *(probe B1)* a foreign
  entry inserted after the host is on top; *(probe B2)* a later push keeps it above the host (the
  non-route group keeps its order).
- Not above it: `OverlayPortal` children (Autocomplete, menus) are painted just above the
  **entry they live in** (`overlay.dart:315-321`), i.e. above their route's entry and below the host.

## 5. A public, cheap way to decide "something is above me"?

None that is complete.

- No public order (§1). `debugIsVisible` is debug-only and opacity-based.
- `NavigatorObserver` / `didChangeTop` see routes, but routes never end up above the host (§4), so
  they answer a question that does not need asking.
- Direct inserts by other code are invisible to public API.

What *is* cheap and needs no detection: **re-raise unconditionally** with
`overlay.rearrange([host], below: host)`. It is idempotent in outcome, preserves State (§2), and
costs one overlay rebuild — the same rebuild every `Navigator.push` already triggers. An owner who
needs to skip no-op calls can track its own inserts, but cannot see other code's.

## Implication for spec §5

**The rule is implementable, but its stated reason is wrong and its trigger ("if anything has been
inserted above it since") is not observable with public API.**

- Wrong premise: "a dialog or route pushed afterwards is inserted above it and covers the whole deck"
  — false for a host in the navigator whose overlay the dialog goes into; `Navigator` lifts the host
  above every pushed route (`navigator.dart:4568-4570` + `overlay.dart:772-822`). The consequence
  line "a toast shown before a dialog opens is covered by that dialog" is therefore also false in the
  common case: toasts stay **above** dialogs and pages (which also means they sit above a modal
  barrier and remain tappable over it).
- What still needs the rule: entries inserted directly into the same overlay by other code (flash,
  drag feedback, hero flights). For those, detection is impossible, so the rule must be
  unconditional.
- What the rule cannot fix: a dialog on a **different, higher** overlay (host attached to a nested
  navigator while `showDialog` uses the root navigator; an `Overlay` in `MaterialApp.builder`).
  `attach` should document that `navigatorKey` must be the root navigator's.

Minimal rewording of the §5 subsection:

> `flash` inserts a **new** overlay entry per toast, so a new toast is always on top. A stack host is
> inserted **once**. Routes pushed through the same navigator do not cover it — `Navigator` re-orders
> its overlay on every push and leaves non-route entries on top — but entries that other code inserts
> directly into that overlay afterwards (another toast package, drag feedback) do. `OverlayState` does
> not expose entry order, so in mode 1:
>
> > **Every `show` and every `update` that changes the type re-raises the host to the top of the
> > overlay**, unconditionally, with `overlay.rearrange([host], below: host)` — a single synchronous
> > call that keeps the host's State and running animations.
>
> Consequence: toasts render above dialogs and pushed pages. A toast is covered only by an entry
> inserted directly into the overlay after the last `show`/type-changing `update`, or by a dialog on a
> higher overlay — `attach` must be given the **root** navigator's key, and an `Overlay` added in
> `MaterialApp.builder` sits above it (use mode 2 there). Mode 2 has no such rule — the host is above
> every route.

Related follow-ups this raises (not decided here): whether toasts *should* sit above a modal barrier
(sonner on the web does sit above dialogs); whether §11 Q2 ("re-raise on every update") is now moot
given the call is cheap; and that the controller should re-read `navigatorKey.currentState!.overlay`
on each `show` because state restoration replaces the `OverlayState`.

## Probe output (Flutter 3.41.9)

```
A1 showDialog first frame: host-on-top
A2 showDialog settled: host-on-top
A3 dialog popped: host mounted=true
A4 push page first frame: host-on-top
A5 push page settled: host-on-top log=[init#1]
B1 direct insert after host: other-on-top
B2 after a push, host vs foreign: other-on-top
B3 sync remove+insert: host-on-top log=[init#2] ctrl 0.1 -> 0.11000000000000001 animating=true
B4 rearrange([other, host], above: other): other-not-built log=[init#2]
B5 remove, pump a frame, insert: log=[init#2, dispose#2, init#3]
E1 before: other-on-top
E2 after rearrange([host], below: host): host-on-top log=[init#1] ctrl 0.0 -> 0.01
E3 repeat when already on top: host-on-top log=[init#1]
E4 dialog after: host-on-top other vs host: host-on-top
C1 maintainState:false under opaque: mounted=false log=[init#4, dispose#4]
C2 opaque removed: log=[init#4, dispose#4, init#5]
C3 maintainState:true under opaque: mounted=true log=[init#6] ctrl 0.0 -> 0.0
D0 plain MaterialApp: nav.overlay == root? true
D1 builder Overlay.wrap: nav.overlay == root? false nav.overlay == nearest? true
D2 nested: inner.overlay == root? false
D3 host in inner overlay, showDialog(useRootNavigator: true): other-on-top
D4 host in inner overlay, showDialog(useRootNavigator: false): host-on-top
```

(`other` = the dialog / page / foreign entry named in each line; `init#n`/`dispose#n` = host State
instances; `ctrl a -> b` = the host's `AnimationController.value` across a pump.)
