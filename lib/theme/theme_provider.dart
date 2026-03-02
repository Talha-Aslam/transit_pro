import 'package:flutter/material.dart';

/// Singleton ChangeNotifier that manages light/dark mode across the app.
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;
  bool get isDark => _mode != ThemeMode.light;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }
}
