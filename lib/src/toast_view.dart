import 'package:flutter/widgets.dart';

import 'toast_id.dart';
import 'toast_state.dart';

/// A toast on screen, as the widget drawing it sees it.
///
/// It is handed to whatever the caller supplies — a [ToastSlot], and later a
/// builder — so the widget can act on the toast it belongs to without the
/// caller having to hold its id.
abstract interface class ToastView {
  ToastId get id;

  /// What it shows now, including the fields a look reads rather than draws:
  /// `isLoading`, `dismissible` and `closeButton`.
  ToastState get state;

  /// Runs 0 → 1 as the toast enters and 1 → 0 as it leaves.
  AnimationController get animation;

  /// Dismisses the toast, whatever `dismissible` says: that governs the ways a
  /// **user** dismisses one, not the app or the widget in a slot.
  ///
  /// The future completes once the toast has left the tree, so an exit is over
  /// by the time it does. A toast already gone completes at once.
  Future<void> dismiss();

  /// Pauses the timers until this toast is dismissed, updated or replaced, for
  /// a widget running a gesture of its own.
  void holdTimer();
}

/// A slot the caller fills. It returns the whole widget and receives the
/// toast, so the widget decides for itself whether acting on it also dismisses
/// — the package only places what comes back.
typedef ToastSlot = Widget Function(BuildContext context, ToastView toast);
