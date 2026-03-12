import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_provider.dart';

/// Persists the logged-in role and theme preference across app restarts.
///
/// Call [saveRole] right after a successful login.
/// Call [saveTheme] whenever the user toggles dark/light mode.
/// Call [clearRole] when the user taps "Log Out".
/// Call [getSavedRole] at app start to decide where to navigate.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _roleKey = 'logged_in_role';
  static const _themeKey = 'theme_is_dark';

  /// In-memory cache populated by [preload] before runApp().
  String? _cachedRole;
  String? get cachedRole => _cachedRole;

  /// Must be called in main() before runApp(). Loads role + theme into memory.
  Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedRole = prefs.getString(_roleKey);
    final isDark = prefs.getBool(_themeKey);
    if (isDark != null) {
      ThemeProvider.instance.setMode(isDark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  /// Saves [role] ('parent' | 'driver' | 'student') to persistent storage.
  Future<void> saveRole(String role) async {
    _cachedRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  /// Saves the current dark-mode state.
  Future<void> saveTheme({required bool isDark}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  /// Loads and applies the persisted theme. Call after determining the role.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey);
    if (isDark != null) {
      ThemeProvider.instance.setMode(isDark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  /// Clears the saved role (call on logout). Theme is intentionally kept.
  Future<void> clearRole() async {
    _cachedRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
  }

  /// Returns the saved role, or `null` if no one is logged in.
  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  /// Converts a role string to its root route path.
  static String routeForRole(String role) {
    switch (role) {
      case 'driver':
        return '/driver';
      case 'student':
        return '/student';
      default:
        return '/parent';
    }
  }
}
