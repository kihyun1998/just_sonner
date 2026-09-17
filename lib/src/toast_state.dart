import 'package:flutter/widgets.dart';

import 'toast_view.dart';

/// The content of a toast.
@immutable
class ToastState {
  const ToastState({
    required this.title,
    this.description,
    this.isLoading = false,
    this.leading,
    this.action,
    this.closeButton,
    this.dismissible,
    this.builder,
  });

  final String title;
  final String? description;

  /// Whether the toast has no timer and shows the loading indicator in its
  /// leading slot. A flag the toast carries, not a kind of toast: it can start
  /// loading, stop, and start again at the same id.
  final bool isLoading;

  /// The widget the leading slot holds while the toast is not [isLoading]. A
  /// toast with neither has no slot at all.
  final Widget? leading;

  /// What fills the slot at the trailing edge, handed the toast.
  final ToastSlot? action;

  /// Whether the close button is drawn, or null to follow
  /// `SonnerConfig.closeButton`.
  final bool? closeButton;

  /// Whether the **user** may dismiss the toast, by the close button or a
  /// swipe, or null to follow [isLoading].
  ///
  /// Kept as given, unset included, and read through [dismissibleNow] rather
  /// than settled when the toast was shown — which is what lets a toast hand
  /// itself back the moment it stops loading, with no second call.
  final bool? dismissible;

  /// What draws the toast in place of the default look, or null to follow
  /// `SonnerConfig.builder`.
  final ToastBuilder? builder;

  /// Whether the user may dismiss it now: [dismissible], or `!isLoading` while
  /// that is unset.
  bool get dismissibleNow => dismissible ?? !isLoading;

  /// Whether the close button is drawn, given a config that says
  /// [configCloseButton]. A toast the user may not dismiss has none.
  bool closeButtonNow(bool configCloseButton) =>
      dismissibleNow && (closeButton ?? configCloseButton);
}
