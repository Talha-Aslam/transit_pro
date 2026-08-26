import 'package:flutter/material.dart';
import 'theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BuildContext helpers – use these in screens so every colour follows the
//  current light / dark mode automatically.
//
//  Every colour below is a `Color.lerp`/`BoxDecoration.lerp` driven by
//  `ThemeProvider.instance.blend` (0 = light, 1 = dark) rather than a hard
//  switch on a boolean — toggling used to snap every colour in the app
//  instantly, because none of this reads `ThemeData.colorScheme` (which is
//  the only thing Flutter's own built-in theme animation smooths). Blending
//  the actual constants here is what makes the transition feel like a fade
//  rather than a cut.
// ─────────────────────────────────────────────────────────────────────────────
extension AppColors on BuildContext {
  /// Still a plain boolean for the handful of things that genuinely can't
  /// blend — swapping an icon or an image asset, not a colour.
  bool get isDark => ThemeProvider.instance.isDark;

  double get _themeBlend => ThemeBlendScope.of(this);

  // Background decoration
  BoxDecoration get scaffoldBg => BoxDecoration.lerp(
        AppTheme.lightBgDecoration,
        AppTheme.bgDecoration,
        _themeBlend,
      )!;

  // Text
  Color get textPrimary =>
      Color.lerp(const Color(0xFF1E293B), Colors.white, _themeBlend)!;
  Color get textSecondary =>
      Color.lerp(const Color(0xFF64748B), Colors.white70, _themeBlend)!;
  Color get textTertiary =>
      Color.lerp(const Color(0xFF94A3B8), Colors.white38, _themeBlend)!;
  Color get textHint =>
      Color.lerp(const Color(0xFFCBD5E1), Colors.white24, _themeBlend)!;

  // Surfaces / cards
  Color get cardBg => Color.lerp(
        Colors.white,
        Colors.white.withValues(alpha: 0.06),
        _themeBlend,
      )!;
  Color get cardBgElevated => Color.lerp(
        const Color(0xFFF1F5F9),
        Colors.white.withValues(alpha: 0.10),
        _themeBlend,
      )!;
  Color get surfaceBorder => Color.lerp(
        const Color(0xFFE2E8F0),
        Colors.white.withValues(alpha: 0.10),
        _themeBlend,
      )!;

  // Inputs
  Color get inputFill => Color.lerp(
        const Color(0xFFF1F5F9),
        Colors.white.withValues(alpha: 0.05),
        _themeBlend,
      )!;
  Color get inputBorder => Color.lerp(
        const Color(0xFFE2E8F0),
        Colors.white.withValues(alpha: 0.12),
        _themeBlend,
      )!;
}

class AppTheme {
  // ── Background ────────────────────────────────────────────────────────────
  static const Color bgDarkest = Color.fromARGB(255, 16, 9, 44);
  static const Color bgDark = Color.fromARGB(255, 39, 14, 83);
  static const Color bgDarkBlue = Color.fromARGB(255, 42, 41, 94);

  // ── Light backgrounds ─────────────────────────────────────────────────────
  static const Color lightBg1 = Color(0xFFF8FAFC);
  static const Color lightBg2 = Color(0xFFEEF2FF);
  static const Color lightBg3 = Color(0xFFF0F9FF);

  // ── Parent (purple) ───────────────────────────────────────────────────────
  static const Color parentPurple = Color(0xFF7C3AED);
  static const Color parentIndigo = Color(0xFF4F46E5);
  static const Color parentAccent = Color(0xFFA78BFA);
  static const Color parentLight = Color(0xFFC4B5FD);

  // ── Driver (cyan) ─────────────────────────────────────────────────────────
  static const Color driverCyan = Color(0xFF0EA5E9);
  static const Color driverTeal = Color(0xFF0891B2);
  static const Color driverAccent = Color(0xFF38BDF8);

  // ── Admin (emerald) ───────────────────────────────────────────────────────
  static const Color adminEmerald = Color(0xFF059669);
  static const Color adminGreen = Color(0xFF047857);
  static const Color adminAccent = Color(0xFF34D399);
  static const Color adminLight = Color(0xFF6EE7B7);

  // ── Student (amber/orange) ────────────────────────────────────────────────
  static const Color studentAmber = Color(0xFFF59E0B);
  static const Color studentOrange = Color(0xFFEA580C);
  static const Color studentAccent = Color(0xFFFBBF24);
  static const Color studentLight = Color(0xFFFDE68A);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFCD34D);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient parentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [parentPurple, parentIndigo],
  );

  static const LinearGradient driverGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [driverCyan, driverTeal],
  );

  static const LinearGradient adminGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [adminEmerald, adminGreen],
  );

  static const LinearGradient studentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [studentAmber, studentOrange],
  );

  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, info],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment(-0.3, -1),
    end: Alignment(0.5, 1),
    colors: [bgDarkest, bgDark, bgDarkBlue],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment(-0.3, -1),
    end: Alignment(0.5, 1),
    colors: [lightBg1, lightBg2, lightBg3],
    stops: [0.0, 0.45, 1.0],
  );

  // ── Decorations ───────────────────────────────────────────────────────────
  static BoxDecoration get bgDecoration =>
      const BoxDecoration(gradient: backgroundGradient);

  static BoxDecoration get lightBgDecoration =>
      const BoxDecoration(gradient: lightBackgroundGradient);

  static BoxDecoration glassDecoration({
    double radius = 20,
    Color? color,
    Color? borderColor,
    double borderWidth = 1.0,
    List<BoxShadow>? shadows,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      color: gradient == null
          ? (color ?? Colors.white.withValues(alpha: 0.06))
          : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.10),
        width: borderWidth,
      ),
      boxShadow: shadows,
    );
  }

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDarkest,
      colorScheme: const ColorScheme.dark(
        primary: parentPurple,
        secondary: driverCyan,
        surface: bgDark,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: Colors.white70, fontSize: 15),
        bodyMedium: TextStyle(color: Colors.white54, fontSize: 13),
        bodySmall: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: parentAccent, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const textDark = Color(0xFF1E293B);
    const textMid = Color(0xFF64748B);
    const textLight = Color(0xFF94A3B8);
    const surface = Color(0xFFF8FAFC);
    const border = Color(0xFFE2E8F0);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: parentPurple,
        secondary: driverCyan,
        surface: surface,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textDark,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          color: textDark,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: TextStyle(
          color: textDark,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: textDark,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: textMid, fontSize: 15),
        bodyMedium: TextStyle(color: textMid, fontSize: 13),
        bodySmall: TextStyle(color: textLight, fontSize: 11),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: parentPurple, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textLight, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
