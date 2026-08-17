import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/auth_service.dart';
import '../app/session_service.dart';
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
      duration: const Duration(milliseconds: 4000),
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _routeOnward();
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

  /// Decides where the splash hands off to.
  ///
  /// It used to read the saved role out of SharedPreferences and go straight
  /// there. That key outlives the Firebase session, so a signed-out user with a
  /// stale pref was pushed to `/parent` and then immediately bounced back to
  /// `/role-select` by the router guard — a visible flash of the wrong screen.
  /// The live session is the only thing worth trusting here.
  Future<void> _routeOnward() async {
    final auth = AuthService.instance;
    final session = SessionService.instance;

    if (!auth.isSignedIn) {
      if (mounted) context.go('/role-select');
      return;
    }

    // The profile normally lands during the 4-second splash animation. If the
    // network is slow it may not have, so wait briefly rather than guessing.
    if (session.isLoading) {
      await _waitForSession();
    }
    if (!mounted) return;

    if (session.hasError) {
      // The profile couldn't even be read — a genuine backend/permissions
      // failure (see SessionState.error), not "hasn't finished onboarding".
      // Routing by role.cachedRole here would send the user into a dashboard
      // that will just hit the same wall trying to load its own data. Ending
      // the session cleanly and sending them back to pick a role again is
      // honest about not knowing their status, and next time buys a fresh
      // attempt against whatever is actually wrong.
      await auth.signOut();
      if (mounted) context.go('/role-select');
      return;
    }

    if (session.needsProfile) {
      context.go('/complete-profile');
      return;
    }

    final role = session.role;
    context.go(
      role != null
          ? AuthService.routeForUserRole(role)
          : AuthService.routeForRole(auth.cachedRole ?? 'parent'),
    );
  }

  /// Waits for the first profile snapshot, giving up after a few seconds so a
  /// dead connection cannot strand the user on the splash screen forever.
  Future<void> _waitForSession() async {
    final session = SessionService.instance;
    final done = Completer<void>();

    void listener() {
      if (!session.isLoading && !done.isCompleted) done.complete();
    }

    session.state.addListener(listener);
    try {
      await done.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      );
    } finally {
      session.state.removeListener(listener);
    }
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
                  builder: (_, _) {
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
                                ? Colors.white.withValues(alpha: 
                                    max(0.0, 0.15 - i * 0.02),
                                  )
                                : Colors.black.withValues(alpha: 
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
                  builder: (_, _) => Transform.translate(
                    offset: Offset(0, -_bounceController.value * 20),
                    child: Container(
                      width: dot.size,
                      height: dot.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dot.color.withValues(alpha: 0.6),
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
                        builder: (_, _) => Transform.translate(
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
                        builder: (_, _) =>
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
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.07),
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
