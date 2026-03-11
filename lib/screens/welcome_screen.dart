import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  Timer? _navTimer;
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
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/role-select');
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

                      // // Get Started button
                      // GestureDetector(
                      //   onTap: () => context.go('/role-select'),
                      //   child: Container(
                      //     padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 18),
                      //     decoration: BoxDecoration(
                      //       gradient: AppTheme.mainGradient,
                      //       borderRadius: BorderRadius.circular(50),
                      //       boxShadow: [
                      //         BoxShadow(
                      //           color: AppTheme.purple.withOpacity(0.5),
                      //           blurRadius: 28,
                      //           offset: const Offset(0, 10),
                      //         ),
                      //       ],
                      //     ),
                      //     child: const Text(
                      //       'Get Started →',
                      //       style: TextStyle(
                      //         color: context.textPrimary,
                      //         fontSize: 16,
                      //         fontWeight: FontWeight.w700,
                      //         letterSpacing: 0.5,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(height: 14),

                      // Segmented capsule progress bar
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (_, __) => _SegmentedProgressBar(
                          progress: _progressController.value,
                          segments: 6,
                          width: 200,
                          height: 18,
                        ),
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

// ── Segmented capsule loading bar ─────────────────────────────────────────────

class _SegmentedProgressBar extends StatelessWidget {
  final double progress; // 0.0 – 1.0
  final int segments;
  final double width;
  final double height;

  const _SegmentedProgressBar({
    required this.progress,
    required this.segments,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final filledCount = (progress * segments).floor();
    final partialFill = (progress * segments) - filledCount;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppTheme.purple.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.purple.withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppTheme.info.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: List.generate(segments, (i) {
              // Determine fill level for this segment
              double fill;
              if (i < filledCount) {
                fill = 1.0;
              } else if (i == filledCount) {
                fill = partialFill;
              } else {
                fill = 0.0;
              }

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < segments - 1 ? 3 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        // Track
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.purple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Fill
                        if (fill > 0)
                          FractionallySizedBox(
                            widthFactor: fill,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.purple, AppTheme.info],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.purple.withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
