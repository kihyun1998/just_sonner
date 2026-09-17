import 'package:flutter/widgets.dart';

import 'toast_id.dart';
import 'toast_state.dart';

/// A toast on screen, as the widget drawing it sees it.
///
/// It is handed to whatever the caller supplies — a [ToastSlot] or a
/// [ToastBuilder] — so the widget can act on the toast it belongs to without
/// the caller having to hold its id.
abstract interface class ToastView {
  ToastId get id;

  /// What it shows now, including the fields a look reads rather than draws:
  /// `isLoading`, `dismissible`, `closeButton` and `builder`.
  ToastState get state;

  /// Runs 0 → 1 as the toast enters and 1 → 0 as it leaves. A builder that
  /// drives it to 0 itself dismisses the toast.
  AnimationController get animation;

  /// How much the deck covers the toast: 0 at the front or with the deck
  /// expanded, and 1 behind a toast fully present. The default look draws no
  /// content while covered and keeps its card; a builder decides for itself.
  Animation<double> get covered;

  /// How much of its duration the toast has left: 1 when its countdown starts
  /// and 0 when it runs out, moving on every frame. It stands still while the
  /// timers are paused, goes back up when an update or a replace starts the
  /// countdown again, and keeps where it stood once the toast is dismissed.
  /// Null while the toast has no timer — while it is loading, or when its
  /// duration is [Duration.zero].
  ///
  /// It is here whatever `SonnerConfig.timeLeft` says, which governs only what
  /// the default look draws. While a toast counts down, frames run for it, so a
  /// widget test pumps by hand rather than with `pumpAndSettle`, which would
  /// run the toast's timer out.
  Animation<double>? get timeLeft;

  /// Dismisses the toast, whatever `dismissible` says: that governs the ways a
  /// **user** dismisses one, not the app or the widget in a slot.
  ///
  /// The future completes once the toast has left the tree, so an exit is over
  /// by the time it does. A toast already gone completes at once.
  ///
  /// It dismisses this toast and no other: on a toast already dismissed it
  /// leaves a new toast shown at the same id standing.
  Future<void> dismiss();

  /// Pauses the timers until this toast is dismissed, updated or replaced, for
  /// a widget running a gesture of its own.
  void holdTimer();
}

/// Replaces a toast's whole look: it returns everything the toast draws, and
/// receives the toast to animate, dismiss and read with.
typedef ToastBuilder = Widget Function(BuildContext context, ToastView toast);

/// A slot the caller fills. It returns the whole widget and receives the
/// toast, so the widget decides for itself whether acting on it also dismisses
/// — the package only places what comes back.
typedef ToastSlot = Widget Function(BuildContext context, ToastView toast);
