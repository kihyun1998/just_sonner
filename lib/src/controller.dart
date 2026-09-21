import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/widgets.dart'
    show
        AppLifecycleState,
        GlobalKey,
        NavigatorState,
        Widget,
        WidgetsBinding,
        WidgetsBindingObserver;

import 'config.dart';
import 'toast_content.dart';
import 'toast_view.dart';
import 'root_overlay.dart';
import 'toast_id.dart';
import 'toast_state.dart';

/// The default controller, usable from anywhere.
final toast = SonnerController();

/// Owns the toasts on screen, their ids and their countdowns. Holds no widgets;
/// a host draws it, either one the app mounts or one [attach] puts in the root
/// overlay.
///
/// One periodic tick subtracts from every counting toast, and runs only while
/// some toast is counting. Nothing here reads a clock. While the timers are
/// paused the tick still runs and subtracts nothing.
///
/// The tick belongs to the controller, not to the widget tree, so unmounting a
/// host does not stop it. A widget test that shows a toast with a timer must
/// dismiss it, or pump past its duration, before the test body ends:
/// `testWidgets` fails on a pending timer before `tearDown` runs.
class SonnerController extends ChangeNotifier {
  SonnerController({SonnerConfig config = const SonnerConfig()})
    : assert(_debugCheckConfig(config)),
      _config = config;

  static const _tick = Duration(milliseconds: 100);

  /// How this controller's toasts are laid out and how long they stay.
  ///
  /// Assigning a different one notifies, so a host drawing the toasts follows
  /// it with the toasts on screen. The countdowns under way keep the duration
  /// they started with; a new `duration` reaches the next toast shown or
  /// replaced.
  SonnerConfig get config => _config;
  SonnerConfig _config;

  set config(SonnerConfig value) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(_debugCheckConfig(value));
    if (value == _config) return;
    _config = value;
    notifyListeners();
  }

  /// Asserts what a [SonnerConfig]'s const constructor cannot check.
  static bool _debugCheckConfig(SonnerConfig config) {
    assert(
      debugCheckDuration(config.duration) &&
          !identical(config.duration, SonnerConfig.configDuration),
      'SonnerConfig.duration must be positive, or null to keep toasts until '
      'they are dismissed.',
    );
    assert(
      config.visibleToasts >= 1 && config.visibleToasts <= 20,
      'SonnerConfig.visibleToasts must be between 1 and 20; at 21 the toast '
      'at the back would be scaled to nothing.',
    );
    return true;
  }

  final List<ToastRecord> _toasts = [];
  int _serial = 0;
  Timer? _ticker;

  /// The zone [_ticker] runs in. A timer is bound to its zone, and one left in
  /// a zone that has finished, such as an earlier test's, never fires again.
  Zone? _tickerZone;

  RootOverlayMount? _mount;

  /// Whatever is pausing the timers other than the app's lifecycle, such as a
  /// host with the pointer over its deck.
  final Set<Object> _holders = {};

  /// Whether the app is `hidden`, `paused` or `detached`, once [_lifecycle]
  /// watches it.
  bool _appHidden = false;

  _LifecycleWatch? _lifecycle;

  bool get _paused => _appHidden || _holders.isNotEmpty;

  /// The layer the deck lives in, which the app opens and closes. It exists
  /// whether or not any toast is alive.
  late final SonnerZone zone = SonnerZone._(this);

  ZoneState _zoneState = ZoneState.shown;

  /// The state [SonnerZone.close] returns to.
  ZoneState _beforeOpen = ZoneState.shown;

  /// The toasts shown since the zone was hidden that are still alive.
  final Set<ToastRecord> _arrivals = {};

  /// Whether a hidden zone draws its deck for [_arrivals]: from the first of
  /// them until every one has gone and the pointer has let go of the deck.
  bool _banner = false;

  void _setZone(ZoneState state) {
    _zoneState = state;
    _arrivals.clear();
    _banner = false;
    notifyListeners();
  }

  /// Takes the banner down once nothing keeps it up.
  void _endBannerIfDone() {
    _arrivals.removeWhere((record) => !_toasts.contains(record));
    if (_banner && _arrivals.isEmpty && !_held) _banner = false;
  }

  /// Whether the pointer holds the deck, for [SonnerZone.held].
  bool get _held => _deckHolders.isNotEmpty;

  /// The hosts whose deck the pointer holds.
  final Set<Object> _deckHolders = {};

  /// [_held] as listeners were last told it.
  bool _heldNotified = false;

  bool _disposed = false;

  /// Applies [change] to what holds the deck and tells the listeners when
  /// [_held] has changed, at the end of the frame when it changes during one.
  void _setHeld(VoidCallback change) {
    change();
    if (_held == _heldNotified) return;
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      _notifyHeld();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _notifyHeld(),
      debugLabel: 'SonnerController.held',
    );
  }

  void _notifyHeld() {
    if (_disposed || _held == _heldNotified) return;
    _heldNotified = _held;
    _endBannerIfDone();
    notifyListeners();
  }

  /// Mount mode 1: draws this controller's toasts in the overlay of the root
  /// navigator [navigatorKey] names, above its dialogs and pages.
  ///
  /// Nothing is inserted until the first [show], so it can be called before
  /// the app is built. Once attached, a [show] with no navigator to draw in is
  /// an error in debug and drops the toast in release.
  void attach(GlobalKey<NavigatorState> navigatorKey) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    if (identical(_mount?.navigatorKey, navigatorKey)) return;
    final mount = RootOverlayMount(this, navigatorKey)..debugAssertRoot();
    _mount?.detach();
    _mount = mount;
  }

  /// Undoes [attach]: takes the toasts out of the overlay and leaves a
  /// controller that is not in mode 1, so a [show] with no navigator is no
  /// longer an error. Toasts stay in the controller.
  void detach() {
    _mount?.detach();
    _mount = null;
  }

  /// Shows a toast and returns its id.
  ///
  /// With a [duration] it is a **transient** toast, and dismisses itself once
  /// that has passed. A null [duration] keeps it until it is dismissed, by the
  /// user or the app. With none given it takes `config.duration`, which may be
  /// either. A [duration] that is not positive is an error.
  ///
  /// When [id] names a toast on screen, that toast is **replaced**: it keeps
  /// its place, takes this content whole, with every field not given back at
  /// its default, and counts down again. Any other [id], including one whose
  /// toast was dismissed, makes a new toast.
  ///
  /// Once attached, a new toast with no navigator to draw in is an error in
  /// debug and dropped in release; a replace is applied either way.
  ToastId show(
    String title, {
    String? description,
    bool isLoading = false,
    Widget? leading,
    Duration? duration = SonnerConfig.configDuration,
    bool? dismissible,
    ToastSlot? action,
    bool? closeButton,
    ToastId? id,
    ToastBuilder? builder,
  }) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(
      debugCheckDuration(duration),
      'A duration must be positive, or null to keep the toast until it is '
      'dismissed.',
    );
    assert(
      !isLoading ||
          identical(duration, SonnerConfig.configDuration) ||
          duration == null,
      'A loading toast has no timer, so a duration would be ignored. Give it '
      'one when it stops loading instead: update(id, isLoading: false, '
      'duration: ...).',
    );
    id ??= ToastId(AutoToastIdValue(_serial++));
    final existing = _recordOf(id);
    final problem = _mount?.problem();
    if (problem != null && existing == null) {
      if (kDebugMode) throw StateError(problem);
      debugPrint('just_sonner: $problem The toast "$title" was dropped.');
      return id;
    }
    final state = ToastState(
      title: title,
      description: description,
      isLoading: isLoading,
      leading: leading,
      action: action,
      closeButton: closeButton,
      dismissible: dismissible,
      builder: builder,
    );
    final lifetime = identical(duration, SonnerConfig.configDuration)
        ? config.duration
        : duration;
    if (existing != null) {
      existing
        ..state = state
        ..duration = lifetime;
      _startCountdown(existing);
    } else {
      final record = ToastRecord(id, state, lifetime);
      _toasts.insert(0, record);
      if (_zoneState == ZoneState.hidden) {
        _arrivals.add(record);
        _banner = true;
      }
      _startCountdown(record);
    }
    notifyListeners();
    // A replace still lands when the toasts cannot be drawn, so the toast is
    // not left counting down, or not, on content that is gone.
    if (problem != null) {
      if (kDebugMode) throw StateError(problem);
      debugPrint('just_sonner: $problem "$title" replaced a toast not drawn.');
      return id;
    }
    final mount = _mount;
    if (mount != null) {
      _watchLifecycle();
      mount.raise();
    }
    return id;
  }

  /// **Updates** the toast with [id]: only the fields passed change, and it
  /// keeps its place. Returns false when no toast with [id] is on screen.
  ///
  /// It counts down again whatever changed, from [duration] when it is passed
  /// and from the toast's own duration otherwise. A null [duration] keeps it
  /// until it is dismissed.
  bool update(
    ToastId id, {
    String? title,
    String? description,
    bool? isLoading,
    Widget? leading,
    Duration? duration = SonnerConfig.configDuration,
    bool? dismissible,
    ToastSlot? action,
    bool? closeButton,
    ToastBuilder? builder,
  }) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(
      debugCheckDuration(duration),
      'A duration must be positive, or null to keep the toast until it is '
      'dismissed.',
    );
    final record = _recordOf(id);
    if (record == null) return false;
    final state = record.state;
    record.state = ToastState(
      title: title ?? state.title,
      description: description ?? state.description,
      isLoading: isLoading ?? state.isLoading,
      leading: leading ?? state.leading,
      action: action ?? state.action,
      closeButton: closeButton ?? state.closeButton,
      dismissible: dismissible ?? state.dismissible,
      builder: builder ?? state.builder,
    );
    if (!identical(duration, SonnerConfig.configDuration)) {
      record.duration = duration;
    }
    _startCountdown(record);
    notifyListeners();
    return true;
  }

  /// Shows [loading] at once, then replaces it with `success(value)` or
  /// `error(error)` when [future] finishes, and hands the future's own result
  /// or error back to the caller **unchanged**.
  ///
  /// The three states share one toast: [id] follows the same rule as
  /// `show(id:)`, so a toast already on screen is taken over, which is how a
  /// multi-step flow hands its loading toast over. A loading toast the user
  /// dismissed in the meantime does not stop the result — it arrives as a new
  /// toast, by the same rule that `show` at a dismissed id makes a new one.
  /// What the user swept away was the progress, not the outcome.
  ///
  /// **Nothing the toast does can change what the caller gets.** A state that
  /// cannot be shown — no navigator to draw in, a disposed controller, a
  /// `success` or `error` callback that throws — is reported through
  /// [FlutterError.reportError] and the future's outcome still arrives. The
  /// caller's work is not the toast's to lose.
  ///
  /// `duration` on [loading] is ignored, since a loading toast has no timer,
  /// and asserts in debug.
  Future<T> promise<T>(
    Future<T> future, {
    required ToastContent loading,
    required ToastContent Function(T value) success,
    required ToastContent Function(Object error) error,
    ToastId? id,
  }) async {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(
      identical(loading.duration, SonnerConfig.configDuration),
      'A loading toast has no timer, so a duration on the loading content '
      'would be ignored. Put it on the success or error content instead.',
    );
    // Taken before the first state is shown, so the result still has an id to
    // land on when showing the loading toast goes wrong.
    final toastId = id ?? ToastId(AutoToastIdValue(_serial++));
    _promiseState(toastId, () => loading, isLoading: true);
    try {
      final value = await future;
      _promiseState(toastId, () => success(value));
      return value;
    } catch (thrown, stack) {
      _promiseState(toastId, () => error(thrown));
      Error.throwWithStackTrace(thrown, stack);
    }
  }

  /// Shows one `promise` state at [id], and lets nothing that goes wrong with
  /// it reach the caller of [promise].
  ///
  /// [content] is called here rather than passed, so a `success` or `error`
  /// callback that throws is reported like any other failure to show instead
  /// of replacing the future's outcome.
  void _promiseState(
    ToastId id,
    ToastContent Function() content, {
    bool isLoading = false,
  }) {
    try {
      final state = content();
      show(
        state.title,
        description: state.description,
        leading: state.leading,
        dismissible: state.dismissible,
        action: state.action,
        closeButton: state.closeButton,
        builder: state.builder,
        isLoading: isLoading,
        // What makes the spec's ‘ignored’ true in release. In debug the
        // assert in [promise] stops the caller first, so no test reaches this
        // branch; without it a release build would remember a duration the
        // loading toast is not allowed to have and count down from it when it
        // stopped loading.
        duration: isLoading ? SonnerConfig.configDuration : state.duration,
        id: id,
      );
    } catch (thrown, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: thrown,
          stack: stack,
          library: 'just_sonner',
          context: ErrorDescription('showing a promise toast'),
        ),
      );
    }
  }

  /// Dismisses the toast with [id]. An id not on screen is ignored.
  void dismiss(ToastId id) {
    final index = _toasts.indexWhere((record) => record.id == id);
    if (index < 0) return;
    _toasts.removeAt(index);
    _endBannerIfDone();
    _stopTickerIfIdle();
    notifyListeners();
  }

  /// Dismisses every toast on screen.
  void dismissAll() {
    if (_toasts.isEmpty) return;
    _toasts.clear();
    _endBannerIfDone();
    _stopTickerIfIdle();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _mount?.detach();
    _ticker?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Starts pausing the timers on the app's lifecycle, or reads the state
  /// again when already watching. Needs a binding, so it waits for something
  /// that has one: a host, or a [show] once attached.
  void _watchLifecycle() {
    final lifecycle = _lifecycle;
    if (lifecycle == null) {
      _lifecycle = _LifecycleWatch(_onLifecycle);
    } else {
      lifecycle.read();
    }
  }

  void _onLifecycle(AppLifecycleState? state) {
    _setPaused(() {
      _appHidden = switch (state) {
        AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached => true,
        AppLifecycleState.resumed ||
        AppLifecycleState.inactive ||
        null => false,
      };
    });
  }

  /// Applies [change] to what pauses the timers. Coming out of a pause, every
  /// counting toast lets the partial tick under way pass uncounted, as one
  /// shown between ticks does.
  void _setPaused(VoidCallback change) {
    final was = _paused;
    change();
    if (!was || _paused) return;
    for (final record in _toasts) {
      if (record.remaining != null) record.skipTick = true;
    }
  }

  void _onTick(Timer _) {
    if (_paused) return;
    for (final record in _toasts) {
      final remaining = record.remaining;
      if (remaining == null) continue;
      if (record.skipTick) {
        record.skipTick = false;
      } else {
        record.remaining = remaining - _tick;
      }
    }
    final before = _toasts.length;
    _toasts.removeWhere((record) {
      final remaining = record.remaining;
      return remaining != null && remaining <= Duration.zero;
    });
    if (_toasts.length == before) return;
    _endBannerIfDone();
    _stopTickerIfIdle();
    notifyListeners();
  }

  ToastRecord? _recordOf(ToastId id) {
    for (final record in _toasts) {
      if (record.id == id) return record;
    }
    return null;
  }

  /// Counts [record] down from its duration, from the start. A loading toast
  /// has no timer; its duration is kept, so the countdown it starts when it
  /// stops loading runs from the toast's own duration, as any restart does.
  void _startCountdown(ToastRecord record) {
    final duration = record.duration;
    // In release a duration that is not positive, which asserts in debug,
    // keeps the toast as a null one does.
    final counts =
        !record.state.isLoading && duration != null && duration > Duration.zero;
    record
      ..remaining = counts ? duration : null
      ..skipTick = false;
    if (record.remaining == null) {
      _stopTickerIfIdle();
      return;
    }
    if (!identical(_tickerZone, Zone.current)) _stopTicker();
    // Joining a tick already under way, the first tick comes early; skipping
    // it makes the toast run up to one tick long rather than short.
    record.skipTick = _ticker != null;
    if (_ticker == null) {
      _ticker = Timer.periodic(_tick, _onTick);
      _tickerZone = Zone.current;
    }
  }

  void _stopTickerIfIdle() {
    if (_toasts.any((record) => record.remaining != null)) return;
    _stopTicker();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _tickerZone = null;
  }
}

/// How long one of the countdown's ticks is: how far apart two values of
/// [ToastRecord.remaining] are, and so how far the host may interpolate
/// between them. For the host; not exported.
const countdownTick = SonnerController._tick;

/// The toasts on screen, newest first. For the host; not exported.
List<ToastRecord> toastsOf(SonnerController controller) =>
    List.unmodifiable(controller._toasts);

/// Whether [controller]'s timers are paused. For the host; not exported.
bool timersPaused(SonnerController controller) => controller._paused;

/// Dismisses [record] while it is on screen, and never a toast shown at its id
/// since. For the host; not exported.
void dismissRecord(SonnerController controller, ToastRecord record) {
  if (!controller._toasts.any((it) => identical(it, record))) return;
  controller.dismiss(record.id);
}

/// Pauses every timer of [controller] until [holder] lets go through
/// [releaseTimers]. Holding twice with one holder holds once. For the host;
/// not exported.
void holdTimers(SonnerController controller, Object holder) =>
    controller._setPaused(() => controller._holders.add(holder));

/// Lets go of a hold [holder] took with [holdTimers]; the timers resume once
/// nothing holds them. A holder that holds nothing is ignored.
void releaseTimers(SonnerController controller, Object holder) =>
    controller._setPaused(() => controller._holders.remove(holder));

/// Reports that the pointer holds the deck [holder] draws, for [SonnerZone.held].
/// Holding twice with one holder holds once. For the host; not exported.
void holdDeck(SonnerController controller, Object holder) =>
    controller._setHeld(() => controller._deckHolders.add(holder));

/// Lets go of a hold [holder] reported with [holdDeck]. A holder that holds
/// nothing is ignored.
void releaseDeck(SonnerController controller, Object holder) =>
    controller._setHeld(() => controller._deckHolders.remove(holder));

/// Whether [controller]'s hidden zone draws its deck for the toasts shown
/// since it was hidden. For the host; not exported.
bool zoneBanner(SonnerController controller) =>
    controller._zoneState == ZoneState.hidden && controller._banner;

/// Makes [controller] pause its timers while the app is `hidden`, `paused` or
/// `detached`. For the host, which has a binding; not exported.
void watchLifecycle(SonnerController controller) =>
    controller._watchLifecycle();

/// Reports the app's lifecycle state to [onChange], once with the state it is
/// in and again on each change.
class _LifecycleWatch with WidgetsBindingObserver {
  _LifecycleWatch(this.onChange) {
    WidgetsBinding.instance.addObserver(this);
    read();
  }

  final ValueChanged<AppLifecycleState?> onChange;

  /// Reports the state the app is in now. A binding can reset its state
  /// without telling its observers, as `flutter_test` does between tests.
  void read() => onChange(WidgetsBinding.instance.lifecycleState);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

/// One toast on screen, as the controller holds it. Each new toast gets a new
/// record, so a host can tell two toasts apart even where they share an id; an
/// update or a replace changes the record it already has.
final class ToastRecord {
  ToastRecord(this.id, this.state, this.duration);

  final ToastId id;

  /// What it shows now.
  ToastState state;

  /// The time it counts down from when it starts or restarts, or null when it
  /// has no timer.
  Duration? duration;

  /// The time left before the toast dismisses itself, or null when it has no
  /// timer.
  Duration? remaining;

  /// Whether the next tick passes this toast by, because it started counting
  /// between two ticks.
  bool skipTick = false;
}

/// What a [SonnerZone] draws.
enum ZoneState {
  /// No deck in its corner. The toasts stay alive and keep counting down, and
  /// a new one shows as a banner until it has gone.
  hidden,

  /// The collapsed deck, which the pointer fans out while it holds it. With no
  /// toast, nothing is drawn.
  shown,

  /// Every live toast fanned out, whatever the pointer does, until the app
  /// closes it. With no toast, the empty card is drawn.
  open,
}

/// The layer a controller's deck lives in: `toast.zone`. The app opens and
/// closes it, and it exists whether or not any toast is alive. It holds live
/// toasts only, never ones that have gone.
///
/// Listeners are the controller's: it notifies when [state] or [held]
/// changes.
class SonnerZone {
  SonnerZone._(this._controller);

  final SonnerController _controller;

  /// What the zone draws.
  ZoneState get state => _controller._zoneState;

  /// Whether the pointer holds the deck: it has moved, pressed or turned the
  /// wheel over the deck and not left since, or a press that started on the
  /// deck is still down, wherever it has been carried. The deck is fanned out
  /// and every timer stops while it holds. False while nothing is drawn.
  bool get held => _controller._held;

  /// Fans out every live toast, and draws the empty card when there is none,
  /// until [close], or [hide]. It does not pause the timers. Does nothing when
  /// already open.
  ///
  /// Once attached with no navigator to draw in, it is an error in debug and
  /// does nothing in release, as a new toast is.
  void open() {
    final controller = _controller;
    assert(ChangeNotifier.debugAssertNotDisposed(controller));
    if (controller._zoneState == ZoneState.open) return;
    final mount = controller._mount;
    final problem = mount?.problem();
    if (problem != null) {
      if (kDebugMode) throw StateError(problem);
      debugPrint('just_sonner: $problem The zone was not opened.');
      return;
    }
    controller._beforeOpen = controller._zoneState;
    controller._setZone(ZoneState.open);
    if (mount != null) {
      controller._watchLifecycle();
      mount.raise();
    }
  }

  /// Returns an open zone to the state [open] was called from: a zone opened
  /// from hidden folds up and hides again. The deck stays fanned out while the
  /// pointer still holds it. Does nothing when the zone is not open.
  void close() {
    final controller = _controller;
    assert(ChangeNotifier.debugAssertNotDisposed(controller));
    if (controller._zoneState != ZoneState.open) return;
    controller._setZone(controller._beforeOpen);
  }

  /// Takes the deck out of its corner, keeping its toasts, which count down as
  /// they would on screen. An open zone goes to hidden, and a banner a hidden
  /// zone has up is taken down.
  void hide() {
    final controller = _controller;
    assert(ChangeNotifier.debugAssertNotDisposed(controller));
    if (controller._zoneState == ZoneState.hidden && !controller._banner) {
      return;
    }
    controller._setZone(ZoneState.hidden);
  }

  /// Brings a hidden zone back to shown. On an open zone it changes nothing on
  /// screen, and [close] then returns to shown.
  void reveal() {
    final controller = _controller;
    assert(ChangeNotifier.debugAssertNotDisposed(controller));
    switch (controller._zoneState) {
      case ZoneState.hidden:
        controller._setZone(ZoneState.shown);
      case ZoneState.open:
        controller._beforeOpen = ZoneState.shown;
      case ZoneState.shown:
        break;
    }
  }
}
