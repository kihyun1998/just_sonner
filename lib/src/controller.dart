import 'package:flutter/foundation.dart';

import 'config.dart';
import 'toast_id.dart';
import 'toast_state.dart';

/// The default controller, usable from anywhere.
final toast = SonnerController();

/// Owns the toasts on screen and their ids. Holds no widgets; a host draws it.
class SonnerController extends ChangeNotifier {
  SonnerController({this.config = const SonnerConfig()});

  /// How this controller's toasts are laid out.
  final SonnerConfig config;

  final List<ToastRecord> _toasts = [];
  int _serial = 0;

  /// Shows a toast and returns its id.
  ToastId show(String title, {String? description}) {
    final id = ToastId(AutoToastIdValue(_serial++));
    _toasts.insert(
      0,
      ToastRecord(id, ToastState(title: title, description: description)),
    );
    notifyListeners();
    return id;
  }

  /// Dismisses the toast with [id]. An id not on screen is ignored.
  void dismiss(ToastId id) {
    final index = _toasts.indexWhere((record) => record.id == id);
    if (index < 0) return;
    _toasts.removeAt(index);
    notifyListeners();
  }

  /// Dismisses every toast on screen.
  void dismissAll() {
    if (_toasts.isEmpty) return;
    _toasts.clear();
    notifyListeners();
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
}
