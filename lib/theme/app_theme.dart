import 'package:flutter/material.dart';

class AppTheme {
  // ── Background ────────────────────────────────────────────────────────────
  static const Color bgDarkest = Color.fromARGB(255, 99, 74, 192);
  static const Color bgDark = Color.fromARGB(255, 45, 18, 95);
  static const Color bgDarkBlue = Color.fromARGB(255, 42, 41, 94);

  // ── Parent (purple) ───────────────────────────────────────────────────────
  static const Color parentPurple = Color(0xFF7C3AED);
  static const Color parentIndigo = Color(0xFF4F46E5);
  static const Color parentAccent = Color(0xFFA78BFA);
  static const Color parentLight = Color(0xFFC4B5FD);

  // ── Driver (cyan) ─────────────────────────────────────────────────────────
  static const Color driverCyan = Color(0xFF0EA5E9);
  static const Color driverTeal = Color(0xFF0891B2);
  static const Color driverAccent = Color(0xFF38BDF8);

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

  // ── Decorations ───────────────────────────────────────────────────────────
  static BoxDecoration get bgDecoration =>
      const BoxDecoration(gradient: backgroundGradient);

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
          ? (color ?? Colors.white.withOpacity(0.06))
          : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.10),
        width: borderWidth,
      ),
      boxShadow: shadows,
    );
  }

  // ── Theme ─────────────────────────────────────────────────────────────────
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
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: parentAccent, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
