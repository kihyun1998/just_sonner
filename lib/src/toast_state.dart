import 'package:flutter/widgets.dart';

/// The content of a toast.
@immutable
class ToastState {
  const ToastState({
    required this.title,
    this.description,
    this.isLoading = false,
    this.leading,
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
}
