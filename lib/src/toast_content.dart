import 'package:flutter/widgets.dart';

import 'toast_view.dart';

/// The content of one `promise` state.
///
/// Everything `show` takes except `id` and `isLoading`, which `promise` sets
/// itself: the states share an id, and only the first of them is loading.
///
/// `builder` joins it when `show` grows it.
@immutable
class ToastContent {
  const ToastContent(
    this.title, {
    this.description,
    this.leading,
    this.duration,
    this.dismissible,
    this.action,
    this.closeButton,
  });

  final String title;
  final String? description;
  final Widget? leading;

  /// How long the toast stays once it shows this content. Ignored on a
  /// `promise`'s loading content, which has no timer, and asserted there.
  final Duration? duration;

  final bool? dismissible;
  final ToastSlot? action;
  final bool? closeButton;
}
