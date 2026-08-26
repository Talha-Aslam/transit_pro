import 'package:flutter/material.dart';
import '../app/auth_service.dart';

/// Singleton ChangeNotifier that manages light/dark mode across the app.
///
/// [blend] (0 = fully light, 1 = fully dark) is the actual driver of every
/// theme-aware colour in `AppColors` — toggling used to flip `ThemeMode`
/// outright, which meant every custom colour (this app reads colours from
/// hardcoded constants via `context.isDark`, not `ThemeData.colorScheme`, so
/// Flutter's own built-in theme animation never touched them) snapped
/// instantly rather than blending. `attachTicker` supplies the vsync a bare
/// singleton can't provide itself; it's called once from the app root.
///
/// Deliberately does **not** forward the animation's per-frame ticks through
/// this class's own `notifyListeners()` — plenty of screens already listen
/// to this singleton just to redraw a few discrete `context.isDark ? a : b`
/// accents on a real toggle, and forwarding ~23 ticks over 380ms through
/// that shared stream made an earlier version of this transition rebuild the
/// entire app (including the router and every current screen) on every
/// frame, which is what actually caused the jank — the colours were already
/// blending correctly by that point. `ThemeBlendScope` below subscribes
/// directly to the animation instead, so only the specific widgets that read
/// a theme colour during their own build are woken on each tick.
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  bool _isDark = false;
  AnimationController? _controller;

  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;
  bool get isDark => _isDark;

  /// 0 = fully light, 1 = fully dark. Falls back to a discrete 0/1 before
  /// `attachTicker` has run (e.g. the very first frame).
  double get blend => _controller?.value ?? (_isDark ? 1 : 0);

  /// True only while the blend is actually animating. `GlassCard` uses this
  /// to drop its `BackdropFilter` blur for the transition's duration —
  /// backdrop blur is one of the most expensive things Flutter can paint,
  /// and re-running it on every glass card on every animation frame was the
  /// other big contributor to the lag. Cards render unblurred (but already
  /// correctly tinted) for ~380ms; imperceptible at this duration, far
  /// cheaper than blurring every frame.
  bool get isAnimating => _controller?.isAnimating ?? false;

  /// The raw ticking animation, for `ThemeBlendScope` to subscribe to
  /// directly. Only valid after `attachTicker` — guaranteed by the app
  /// root calling it from `initState`, before its first `build()`.
  Animation<double> get blendAnimation => _controller!;

  void attachTicker(TickerProvider vsync) {
    if (_controller != null) return;
    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 380),
      value: _isDark ? 1 : 0,
    );
  }

  void toggle() {
    _isDark = !_isDark;
    AuthService.instance.saveTheme(isDark: _isDark);
    _controller?.animateTo(_isDark ? 1.0 : 0.0, curve: Curves.easeInOut);
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    _isDark = mode == ThemeMode.dark;
    _controller?.animateTo(_isDark ? 1.0 : 0.0, curve: Curves.easeInOut);
    notifyListeners();
  }
}

/// Publishes [ThemeProvider.blendAnimation] via Flutter's own
/// `InheritedNotifier` dependency system. `AppColors.of` (and anything else
/// that wants to blend with the transition) calls [ThemeBlendScope.of],
/// which registers that widget as a dependent — Flutter then rebuilds only
/// the widgets that actually did so on each animation tick, not the whole
/// tree, the same mechanism `MediaQuery`/`Theme` use internally.
class ThemeBlendScope extends InheritedNotifier<Animation<double>> {
  const ThemeBlendScope({
    super.key,
    required Animation<double> super.notifier,
    required super.child,
  });

  static double of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemeBlendScope>();
    return scope?.notifier?.value ?? ThemeProvider.instance.blend;
  }
}
