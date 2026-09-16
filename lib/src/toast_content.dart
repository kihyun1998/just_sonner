import 'package:flutter/widgets.dart';

/// The content of one `promise` state.
///
/// Everything `show` takes except `id` and `isLoading`, which `promise` sets
/// itself: the states share an id, and only the first of them is loading.
///
/// `dismissible`, `action`, `closeButton` and `builder` join it when `show`
/// grows them.
@immutable
class ToastContent {
  const ToastContent(
    this.title, {
    this.description,
    this.leading,
    this.duration,
  });

  final String title;
  final String? description;
  final Widget? leading;

  /// How long the toast stays once it shows this content. Ignored on a
  /// `promise`'s loading content, which has no timer, and asserted there.
  final Duration? duration;
}
