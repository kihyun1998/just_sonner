import 'package:flutter/foundation.dart';

/// The content of a toast.
@immutable
class ToastState {
  const ToastState({required this.title, this.description});

  final String title;
  final String? description;
}
