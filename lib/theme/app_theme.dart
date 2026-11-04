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
  Color get textPrimary => Color.lerp(
    AppTheme.lightTextPrimary,
    AppTheme.darkTextPrimary,
    _themeBlend,
  )!;
  Color get textSecondary => Color.lerp(
    AppTheme.lightTextSecondary,
    AppTheme.darkTextSecondary,
    _themeBlend,
  )!;
  Color get textTertiary => Color.lerp(
    AppTheme.lightTextTertiary,
    AppTheme.darkTextTertiary,
    _themeBlend,
  )!;
  Color get textHint =>
      Color.lerp(AppTheme.lightTextHint, AppTheme.darkTextHint, _themeBlend)!;

  // Surfaces / cards
  //
  // Opaque on both sides now. These used to be white at 6-10% alpha in dark
  // mode, which only ever looked like a surface because a `BackdropFilter`
  // blurred the purple gradient behind it; over anything else — a photo, a
  // map, another card — the "card" was simply a pale wash. A real fill plus
  // a real border reads as an object on any background and costs no blur.
  Color get cardBg => Color.lerp(
    AppTheme.lightSurfaceCard,
    AppTheme.darkSurfaceCard,
    _themeBlend,
  )!;
  Color get cardBgElevated => Color.lerp(
    AppTheme.lightSurfaceRaised,
    AppTheme.darkSurfaceRaised,
    _themeBlend,
  )!;
  Color get surfaceBorder => Color.lerp(
    AppTheme.lightSurfaceBorder,
    AppTheme.darkSurfaceBorder,
    _themeBlend,
  )!;

  /// Lift for a card, and only in light mode: against #F5F6F8 a white card
  /// needs the shadow to separate, while on the dark ground the step from
  /// #121417 to #1C1F24 does that job on its own and a shadow would just
  /// muddy it. Fades out as the theme blends toward dark.
  List<BoxShadow> get cardShadow => AppTheme.cardShadowFor(_themeBlend);

  // Inputs
  Color get inputFill => Color.lerp(
    AppTheme.lightSurfaceRaised,
    AppTheme.darkInputFill,
    _themeBlend,
  )!;
  Color get inputBorder => Color.lerp(
    AppTheme.lightInputBorder,
    AppTheme.darkInputBorder,
    _themeBlend,
  )!;
}

class AppTheme {
  // ── Surfaces ──────────────────────────────────────────────────────────────
  //
  // Neutral charcoal and neutral grey, replacing the deep-purple gradient
  // (#10092C → #270E53 → #2A295E) and the blue-indigo light gradient the app
  // shipped with. The old backgrounds were part of the glassmorphism recipe:
  // translucent cards needed something colourful behind them to look like
  // anything at all. With opaque cards that tint only fought the role accents
  // (cyan, purple, amber, emerald) sitting on top of it.
  //
  // The three dark names are kept — nine screens reference `bgDark` and
  // `bgDarkBlue` for sheet and dropdown fills — so re-pointing them here
  // moves every one of those to the new palette at once.
  static const Color bgDarkest = darkSurfaceBg;
  static const Color bgDark = darkSurfaceCard;
  static const Color bgDarkBlue = darkSurfaceRaised;

  // Dark ramp
  static const Color darkSurfaceBg = Color(0xFF121417);
  static const Color darkSurfaceCard = Color(0xFF1C1F24);
  static const Color darkSurfaceRaised = Color(0xFF23272E);
  static const Color darkSurfaceBorder = Color(0xFF2A2E35);
  static const Color darkInputFill = Color(0xFF1F2329);
  static const Color darkInputBorder = Color(0xFF30353D);
  static const Color darkTextPrimary = Color(0xFFE8EAED);
  static const Color darkTextSecondary = Color(0xFF9AA0A6);
  static const Color darkTextTertiary = Color(0xFF6E757E);
  static const Color darkTextHint = Color(0xFF565C64);

  // Light ramp
  static const Color lightSurfaceBg = Color(0xFFF5F6F8);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFF1F3F6);
  static const Color lightSurfaceBorder = Color(0xFFE6E8EC);
  static const Color lightInputBorder = Color(0xFFDFE2E7);
  static const Color lightTextPrimary = Color(0xFF1A1D21);
  static const Color lightTextSecondary = Color(0xFF646B75);
  static const Color lightTextTertiary = Color(0xFF8A919B);
  static const Color lightTextHint = Color(0xFFB4BAC2);

  // ── Greeting ──────────────────────────────────────────────────────────────
  //
  // One colour for "Good Morning" on every dashboard, rather than each role's
  // own accent: the greeting is the app talking, not the role. The light
  // value is the same hue pulled down until it clears 4.5:1 against the pale
  // end of the header scrim — #4FC3F7 itself is a 64%-lightness sky blue and
  // all but vanishes over a morning sky.
  static const Color greetingDark = Color(0xFF4FC3F7);
  static const Color greetingLight = Color(0xFF0B73A8);

  /// The standard two-stop accent wash painted over a card surface.
  ///
  /// Every dashboard used to pick its own alphas — the driver 0.15/0.05, the
  /// parent 0.20/0.08, the student 0.12/0.04 — so the same design read as
  /// three different weights of tint depending on who was logged in. The
  /// parent's cards in particular came out as saturated purple blocks rather
  /// than cards with a hint of purple in them.
  static LinearGradient accentWash(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent.withValues(alpha: 0.10), accent.withValues(alpha: 0.03)],
  );

  /// Card lift, light mode only — see `AppColors.cardShadow`.
  /// [blend] is 0 in light, 1 in dark.
  static List<BoxShadow> cardShadowFor(double blend) {
    final strength = 1 - blend;
    if (strength <= 0) return const [];
    return [
      BoxShadow(
        color: const Color(0xFF101418).withValues(alpha: 0.06 * strength),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: const Color(0xFF101418).withValues(alpha: 0.05 * strength),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  // ── Light backgrounds ─────────────────────────────────────────────────────
  static const Color lightBg1 = lightSurfaceBg;
  static const Color lightBg2 = lightSurfaceBg;
  static const Color lightBg3 = lightSurfaceBg;

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

  // Flat, not a gradient: the screen is a plain ground that the cards and the
  // dashboard header sit on. Still expressed as a one-colour LinearGradient
  // so `BoxDecoration.lerp` keeps animating the light/dark transition exactly
  // as it did before.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment(-0.3, -1),
    end: Alignment(0.5, 1),
    colors: [darkSurfaceBg, darkSurfaceBg],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment(-0.3, -1),
    end: Alignment(0.5, 1),
    colors: [lightSurfaceBg, lightSurfaceBg],
  );

  // ── Decorations ───────────────────────────────────────────────────────────
  static BoxDecoration get bgDecoration =>
      const BoxDecoration(gradient: backgroundGradient);

  static BoxDecoration get lightBgDecoration =>
      const BoxDecoration(gradient: lightBackgroundGradient);

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSurfaceBg,
      colorScheme: const ColorScheme.dark(
        primary: parentPurple,
        secondary: driverCyan,
        surface: darkSurfaceCard,
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
