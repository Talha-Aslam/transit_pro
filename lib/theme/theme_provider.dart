import 'package:flutter/material.dart';
import '../app/auth_service.dart';

/// Singleton ChangeNotifier that manages light/dark mode across the app.
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode != ThemeMode.light;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    AuthService.instance.saveTheme(isDark: isDark);
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }
}
