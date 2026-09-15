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
  ToastId show(String title, {String? description, Duration? duration}) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(
      duration == null || duration >= Duration.zero,
      'A negative duration is not allowed; Duration.zero keeps the toast '
      'until it is dismissed.',
    );
    final id = ToastId(AutoToastIdValue(_serial++));
    final problem = _mount?.problem();
    if (problem != null) {
      if (kDebugMode) throw StateError(problem);
      debugPrint('just_sonner: $problem The toast "$title" was dropped.');
      return id;
    }
    final lifetime = duration ?? config.duration;
    final record = ToastRecord(
      id,
      ToastState(title: title, description: description),
    )..remaining = lifetime > Duration.zero ? lifetime : null;
    _toasts.insert(0, record);
    if (record.remaining != null) {
      if (!identical(_tickerZone, Zone.current)) _stopTicker();
      // Joining a tick already under way, the first tick comes early; skipping
      // it makes the toast run up to one tick long rather than short.
      record.skipTick = _ticker != null;
      if (_ticker == null) {
        _ticker = Timer.periodic(_tick, _onTick);
        _tickerZone = Zone.current;
      }
    }
    notifyListeners();
    _mount?.raise();
    return id;
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

/// One toast on screen, as the controller holds it. Each `show` makes a new
/// record, so a host can tell two toasts apart even where they share an id.
final class ToastRecord {
  ToastRecord(this.id, this.state);

  final ToastId id;
  final ToastState state;

  /// The time left before the toast dismisses itself, or null when it has no
  /// timer.
  Duration? remaining;

  /// Whether the next tick passes this toast by, because it was shown between
  /// two ticks.
  bool skipTick = false;
}
