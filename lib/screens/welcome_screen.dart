import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

    // Progress bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..forward();

    // Auto navigate after 4 seconds
    _navTimer = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) context.go('/role-select');
    });

    // Generate floating dots
    _dots = List.generate(12, (i) => _FloatingDot(
      color: [
        AppTheme.purple, AppTheme.info, AppTheme.driverCyan, AppTheme.pink
      ][i % 4],
      size: 3 + _random.nextDouble() * 4,
      left: 0.05 + _random.nextDouble() * 0.90,
      top: 0.10 + _random.nextDouble() * 0.80,
    ));
  }

  @override
  void dispose() {
    _navTimer?.cancel();
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
        decoration: AppTheme.bgDecoration,
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
                            color: Colors.white.withOpacity(max(0.0, 0.15 - i * 0.02)),
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
            ..._dots.map((dot) => Positioned(
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
            )),

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
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: AppTheme.mainGradient,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.purple.withOpacity(0.5),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('🚌', style: TextStyle(fontSize: 60)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // App name
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFC4B5FD), Color(0xFF93C5FD)],
                        ).createShader(bounds),
                        child: const Text(
                          'TransportKid',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Safe Journeys · Happy Kids · Peace of Mind',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
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
                        children: ['📍 Live Tracking', '🔔 Alerts', '🛡️ Safe & Secure']
                            .map((f) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                                  ),
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 36),

                      // Get Started button
                      GestureDetector(
                        onTap: () => context.go('/role-select'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 18),
                          decoration: BoxDecoration(
                            gradient: AppTheme.mainGradient,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.purple.withOpacity(0.5),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Get Started →',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Progress bar + hint
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              width: 40,
                              height: 3,
                              child: AnimatedBuilder(
                                animation: _progressController,
                                builder: (_, __) => LinearProgressIndicator(
                                  value: _progressController.value,
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  valueColor: const AlwaysStoppedAnimation(AppTheme.purple),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Auto-continuing…',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                          ),
                        ],
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
