import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/auth_service.dart';
import '../app/language_provider.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnim;
  late Animation<double> _bounceAnim;

  final _random = Random();
  late List<_FloatingDot> _dots;

  @override
  void initState() {
    super.initState();

    // Fade-in for content
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    // Bus bounce
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Progress bar — navigate when the bar finishes so they are perfectly synced
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 40000),
    );
    _progressController.addStatusListener((status) async {
      if (status == AnimationStatus.completed && mounted) {
        final savedRole = await AuthService.instance.getSavedRole();
        if (!mounted) return;
        if (savedRole != null) {
          if (!mounted) return;
          context.go(AuthService.routeForRole(savedRole));
        } else {
          context.go('/role-select');
        }
      }
    });
    _progressController.forward();

    LanguageProvider.instance.addListener(_onLangChanged);

    // Generate floating dots
    _dots = List.generate(
      12,
      (i) => _FloatingDot(
        color: [
          AppTheme.purple,
          AppTheme.info,
          AppTheme.driverCyan,
          AppTheme.pink,
        ][i % 4],
        size: 3 + _random.nextDouble() * 4,
        left: 0.05 + _random.nextDouble() * 0.90,
        top: 0.10 + _random.nextDouble() * 0.80,
      ),
    );
  }

  void _onLangChanged() => setState(() {});

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _fadeController.dispose();
    _bounceController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: Stack(
          children: [
            // Pulsing rings
            ...List.generate(6, (i) {
              final ringSize = 80.0 + i * 60;
              return Center(
                child: AnimatedBuilder(
                  animation: _bounceController,
                  builder: (_, __) {
                    final scale = 0.95 + (_bounceController.value * 0.10);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: ringSize,
                        height: ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.isDark
                                ? Colors.white.withOpacity(
                                    max(0.0, 0.15 - i * 0.02),
                                  )
                                : Colors.black.withOpacity(
                                    max(0.0, 0.08 - i * 0.01),
                                  ),
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            // Floating dots
            ..._dots.map(
              (dot) => Positioned(
                left: dot.left * size.width,
                top: dot.top * size.height,
                child: AnimatedBuilder(
                  animation: _bounceController,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -_bounceController.value * 20),
                    child: Container(
                      width: dot.size,
                      height: dot.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dot.color.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bus icon with bounce
                      AnimatedBuilder(
                        animation: _bounceAnim,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _bounceAnim.value),
                          child: Center(
                            child: Image.asset(
                              'assets/images/splash_screen/bus_splash_icon.png',
                              width: 285,
                              height: 300,
                            ),
                          ),
                        ),
                      ),

                      // const SizedBox(height: 2),
                      Text(
                        AppStrings.t('safe_journeys'),
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Feature pills
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children:
                            [
                                  AppStrings.t('pill_tracking'),
                                  AppStrings.t('pill_alerts'),
                                  AppStrings.t('pill_safe'),
                                ]
                                .map(
                                  (f) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: context.inputBorder,
                                      ),
                                    ),
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 26),

                      // Loading bar
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (_, __) =>
                            _LoadingBar(progress: _progressController.value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingDot {
  final Color color;
  final double size;
  final double left;
  final double top;
  _FloatingDot({
    required this.color,
    required this.size,
    required this.left,
    required this.top,
  });
}

class _LoadingBar extends StatelessWidget {
  final double progress;
  const _LoadingBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final filled = constraints.maxWidth * progress.clamp(0.0, 1.0);
        return Container(
          height: 5,
          decoration: BoxDecoration(
            color: context.isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.black.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              Container(
                width: filled,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.purple, AppTheme.driverCyan],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
