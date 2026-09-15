import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'host.dart';

/// Mount mode 1: a [ToastLayer] for [controller] in the overlay of the
/// navigator [navigatorKey] names.
///
/// The overlay is read from [navigatorKey] each time it is needed. The entry
/// is inserted on the first [raise], and each later [raise] moves it to the
/// top of the overlay with one `rearrange`, which keeps its State.
class RootOverlayMount {
  RootOverlayMount(this.controller, this.navigatorKey);

  final SonnerController controller;
  final GlobalKey<NavigatorState> navigatorKey;

  OverlayEntry? _entry;

  /// The overlay [_entry] was inserted into.
  OverlayState? _insertedInto;

  bool _raiseScheduled = false;
  bool _detached = false;

  /// Asserts that the navigator, where it is built, is the root one.
  void debugAssertRoot() {
    final navigator = navigatorKey.currentState;
    assert(
      navigator == null ||
          Overlay.maybeOf(navigator.context, rootOverlay: true) == null,
      'attach() needs the root navigator key, or dialogs will cover toasts. '
      'Use mount mode 2 (SonnerHost) instead.',
    );
  }

  /// Why a toast cannot be drawn right now, or null when it can. Asserts in
  /// debug when the navigator is not the root one.
  String? problem() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return 'The navigator key given to attach() has no mounted Navigator.';
    }
    debugAssertRoot();
    if (navigator.overlay == null) {
      return 'The navigator given to attach() has no Overlay.';
    }
    return null;
  }

  /// Puts the toasts on top of the overlay, inserting them the first time.
  ///
  /// During a build the overlay cannot change, so the move waits for the end
  /// of the frame.
  void raise() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_raiseScheduled) return;
      _raiseScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _raiseScheduled = false;
        _raiseNow();
      }, debugLabel: 'RootOverlayMount.raise');
      return;
    }
    _raiseNow();
  }

  void _raiseNow() {
    if (_detached) return;
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    final entry = _entry;
    if (entry != null && identical(_insertedInto, overlay)) {
      overlay.rearrange([entry], below: entry);
      return;
    }
    _removeEntry();
    // Kept built under an opaque entry, so uncovering it does not make every
    // toast enter again; its animations wait while it is covered.
    final inserted = OverlayEntry(
      maintainState: true,
      builder: (context) => ToastLayer(controller: controller),
    );
    overlay.insert(inserted);
    _entry = inserted;
    _insertedInto = overlay;
  }

  /// Takes the toasts out of the overlay, for good: a move scheduled before
  /// does nothing.
  void detach() {
    _detached = true;
    _removeEntry();
  }

  void _removeEntry() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    _insertedInto = null;
    entry
      ..remove()
      ..dispose();
  }
}
