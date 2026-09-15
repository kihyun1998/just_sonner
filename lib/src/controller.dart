import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;

import 'config.dart';
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
/// some toast is counting. Nothing here reads a clock.
///
/// The tick belongs to the controller, not to the widget tree, so unmounting a
/// host does not stop it. A widget test that shows a toast with a timer must
/// dismiss it, or pump past its duration, before the test body ends:
/// `testWidgets` fails on a pending timer before `tearDown` runs.
class SonnerController extends ChangeNotifier {
  SonnerController({this.config = const SonnerConfig()})
    : assert(
        config.duration >= Duration.zero,
        'SonnerConfig.duration must not be negative; Duration.zero keeps '
        'toasts until they are dismissed.',
      ),
      assert(
        config.visibleToasts >= 1 && config.visibleToasts <= 20,
        'SonnerConfig.visibleToasts must be between 1 and 20; at 21 the toast '
        'at the back would be scaled to nothing.',
      );

  static const _tick = Duration(milliseconds: 100);

  /// How this controller's toasts are laid out and how long they stay.
  final SonnerConfig config;

  final List<ToastRecord> _toasts = [];
  int _serial = 0;
  Timer? _ticker;

  /// The zone [_ticker] runs in. A timer is bound to its zone, and one left in
  /// a zone that has finished, such as an earlier test's, never fires again.
  Zone? _tickerZone;

  RootOverlayMount? _mount;

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
  /// It dismisses itself after [duration], or after `config.duration` when
  /// [duration] is null. [Duration.zero] keeps it until it is dismissed; a
  /// negative [duration] is an error.
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
    Duration? duration,
    ToastId? id,
  }) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(
      duration == null || duration >= Duration.zero,
      'A negative duration is not allowed; Duration.zero keeps the toast '
      'until it is dismissed.',
    );
    id ??= ToastId(AutoToastIdValue(_serial++));
    final existing = _recordOf(id);
    final problem = _mount?.problem();
    if (problem != null && existing == null) {
      if (kDebugMode) throw StateError(problem);
      debugPrint('just_sonner: $problem The toast "$title" was dropped.');
      return id;
    }
    final state = ToastState(title: title, description: description);
    final lifetime = duration ?? config.duration;
    if (existing != null) {
      existing
        ..state = state
        ..duration = lifetime;
      _startCountdown(existing);
    } else {
      final record = ToastRecord(id, state, lifetime);
      _toasts.insert(0, record);
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
    _mount?.raise();
    return id;
  }

  /// **Updates** the toast with [id]: only the fields passed change, and it
  /// keeps its place. Returns false when no toast with [id] is on screen.
  ///
  /// It counts down again whatever changed, from [duration] when it is passed
  /// and from the toast's own duration otherwise.
  bool update(
    ToastId id, {
    String? title,
    String? description,
    Duration? duration,
  }) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(
      duration == null || duration >= Duration.zero,
      'A negative duration is not allowed; Duration.zero keeps the toast '
      'until it is dismissed.',
    );
    final record = _recordOf(id);
    if (record == null) return false;
    final state = record.state;
    record.state = ToastState(
      title: title ?? state.title,
      description: description ?? state.description,
    );
    if (duration != null) record.duration = duration;
    _startCountdown(record);
    notifyListeners();
    return true;
  }

  /// Dismisses the toast with [id]. An id not on screen is ignored.
  void dismiss(ToastId id) {
    final index = _toasts.indexWhere((record) => record.id == id);
    if (index < 0) return;
    _toasts.removeAt(index);
    _stopTickerIfIdle();
    notifyListeners();
  }

  /// Dismisses every toast on screen.
  void dismissAll() {
    if (_toasts.isEmpty) return;
    _toasts.clear();
    _stopTickerIfIdle();
    notifyListeners();
  }

  @override
  void dispose() {
    _mount?.detach();
    _ticker?.cancel();
    super.dispose();
  }

  void _onTick(Timer _) {
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
    _stopTickerIfIdle();
    notifyListeners();
  }

  ToastRecord? _recordOf(ToastId id) {
    for (final record in _toasts) {
      if (record.id == id) return record;
    }
    return null;
  }

  /// Counts [record] down from its duration, from the start.
  void _startCountdown(ToastRecord record) {
    final duration = record.duration;
    record
      ..remaining = duration > Duration.zero ? duration : null
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

/// The toasts on screen, newest first. For the host; not exported.
List<ToastRecord> toastsOf(SonnerController controller) =>
    List.unmodifiable(controller._toasts);

/// One toast on screen, as the controller holds it. Each new toast gets a new
/// record, so a host can tell two toasts apart even where they share an id; an
/// update or a replace changes the record it already has.
final class ToastRecord {
  ToastRecord(this.id, this.state, this.duration);

  final ToastId id;

  /// What it shows now.
  ToastState state;

  /// The time it counts down from when it starts or restarts. [Duration.zero]
  /// means it has no timer.
  Duration duration;

  /// The time left before the toast dismisses itself, or null when it has no
  /// timer.
  Duration? remaining;

  /// Whether the next tick passes this toast by, because it started counting
  /// between two ticks.
  bool skipTick = false;
}
