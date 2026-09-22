import 'package:flutter/material.dart';
import 'package:just_sonner/just_sonner.dart';

/// What every page of the example shares: the one controller's config, the
/// theme, and whether the app draws its own title bar.
class ExampleSettings extends ChangeNotifier {
  ExampleSettings(this.controller);

  final SonnerController controller;

  ThemeMode _themeMode = ThemeMode.light;
  bool _titleBar = false;

  /// The controller's config, assigned in place so the toasts on screen stay.
  SonnerConfig get config => controller.config;
  set config(SonnerConfig value) {
    controller.config = value;
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    _themeMode = value;
    notifyListeners();
  }

  /// Whether the app draws a 60 px title bar over everything, as a desktop app
  /// that hides the system one does.
  bool get titleBar => _titleBar;
  set titleBar(bool value) {
    _titleBar = value;
    notifyListeners();
  }
}
