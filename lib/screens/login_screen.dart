import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';
import '../app/auth_service.dart';
import '../app/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String _error = '';

  static final _configs = {
    'parent': _LoginConfig(
      gradient: AppTheme.parentGradient,
      glowColor: AppTheme.parentPurple,
      accent: AppTheme.parentAccent,
      icon: 'assets/images/role_selection/welcome_parent_transparent.gif',
      title: 'Parent Login',
      subtitle: "Access your child's journey",
      path: '/parent',
    ),
    'driver': _LoginConfig(
      gradient: AppTheme.driverGradient,
      glowColor: AppTheme.driverCyan,
      accent: AppTheme.driverAccent,
      icon: 'assets/images/role_selection/welcome_driver_transparent.gif',
      title: 'Driver Login',
      subtitle: 'Start your route today',
      path: '/driver',
    ),
    'student': _LoginConfig(
      gradient: AppTheme.studentGradient,
      glowColor: AppTheme.studentAmber,
      accent: AppTheme.studentAccent,
      icon: 'assets/images/role_selection/welcome_student_transparent.gif',
      title: 'Student Login',
      subtitle: 'Track your bus & attendance',
      path: '/student',
    ),
  };

  _LoginConfig get _cfg => _configs[widget.role] ?? _configs['parent']!;

  /// The role this login screen is for.
  ///
  /// `/role-select` already asked once, before this screen was ever reached —
  /// `widget.role` comes straight from that choice via the `/login/:role`
  /// route. Reading it here (rather than trusting a stale field) is what makes
  /// "pick Parent, go back, pick Student instead" behave correctly: `go_router`
  /// builds a fresh [LoginScreen] per navigation, so this always reflects the
  /// role actually showing on screen.
  UserRole get _role => switch (widget.role) {
        'driver' => UserRole.driver,
        'student' => UserRole.student,
        _ => UserRole.parent,
      };

  void _onLangChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = AppStrings.t('fill_fields_login'));
      return;
    }
    setState(() {
      _error = '';
      _loading = true;
    });

    try {
      final user = await AuthService.instance.signIn(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);

      // Route by the role stored in Firestore, NOT by the role in the URL.
      // Someone who opens /login/driver but is registered as a parent lands in
      // the parent app — the URL is a hint, never an authorisation.
      context.go(AuthService.routeForUserRole(user.role));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      // `AuthService.signIn` now has its own catch-all, but this call is
      // fire-and-forget from the button (nothing awaits it), so a second
      // line of defence here costs nothing: without it, any exception type
      // this doesn't already know about would leave `_loading` stuck `true`
      // forever — the button silently swaps its label for a spinner and
      // never swaps back, which reads as "the button disappeared".
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _error = '';
      _loading = true;
    });

    try {
      // This login screen is already role-specific — /role-select asked once,
      // before the user ever got here. Passing that role through is what fixes
      // Google sign-in ever losing track of it: AuthService writes it straight
      // to Firestore, so it isn't riding along in memory waiting to be dropped.
      final outcome = await AuthService.instance.signInWithGoogle(role: _role);

      if (!mounted) return;
      setState(() => _loading = false);

      switch (outcome) {
        case GoogleCancelled():
          // Dismissing the account sheet is not a failure — say nothing.
          return;

        case GoogleNeedsProfile():
          // First-time Google account, or one that closed the app before
          // finishing onboarding last time. Either way the role is already
          // recorded on the profile now — onboarding reads it from there and
          // does not ask again.
          context.go('/complete-profile');

        case GoogleSignedIn(user: final user):
          context.go(AuthService.routeForUserRole(user.role));
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      // Same defence-in-depth as `_login` above.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Glow blob
            Positioned(
              top: -100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _cfg.glowColor.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Back button
                    GestureDetector(
                      onTap: () => context.go('/role-select'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.inputBorder),
                        ),
                        child: Text(
                          AppStrings.t('back'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Role icon
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: _cfg.gradient,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: _cfg.glowColor.withValues(alpha: 0.45),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                _cfg.icon,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            AppStrings.t('${widget.role}_login_title'),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.t('${widget.role}_login_sub'),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),

                    // Form card
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email
                          _FieldLabel(AppStrings.t('email_address')),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: AppStrings.t('email_hint'),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          _FieldLabel(AppStrings.t('password_lbl')),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passCtrl,
                            obscureText: !_showPass,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                            ),
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              hintText: AppStrings.t('password_hint'),
                              suffixIcon: GestureDetector(
                                onTap: () =>
                                    setState(() => _showPass = !_showPass),
                                child: Icon(
                                  _showPass
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: context.textTertiary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => context.push('/forgot-password'),
                              child: Text(
                                AppStrings.t('forgot_password'),
                                style: TextStyle(
                                  color: _cfg.accent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          // Error
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '⚠️  ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _error,
                                      style: const TextStyle(
                                        color: Color(0xFFFCA5A5),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Login button
                          GradientButton(
                            label: AppStrings.t('signin_as_${widget.role}'),
                            gradient: _cfg.gradient,
                            glowColor: _cfg.glowColor,
                            isLoading: _loading,
                            onTap: _login,
                          ),
                          const SizedBox(height: 20),

                          // Google is offered for every role. Drivers used to be
                          // excluded because there was nowhere to collect their
                          // licence and vehicle; the onboarding screen now does
                          // that, and a Google driver still lands in
                          // pendingVerification like any other.
                          ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: context.surfaceBorder,
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'Or continue with',
                                    style: TextStyle(
                                      color: context.textTertiary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: context.surfaceBorder,
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _googleLogin,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: context.cardBgElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: context.inputBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/utilities/google.png',
                                      height: 20,
                                      width: 20,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.g_mobiledata,
                                                size: 24,
                                              ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Google',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '🔒  256-bit encrypted · GDPR compliant',
                        style: TextStyle(color: context.textHint, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _LoginConfig {
  final LinearGradient gradient;
  final Color glowColor, accent;
  final String icon, title, subtitle, path;

  const _LoginConfig({
    required this.gradient,
    required this.glowColor,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });
}
