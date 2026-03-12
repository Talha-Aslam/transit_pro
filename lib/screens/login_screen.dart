import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      icon: 'assets/images/welcome_parent_transparent.gif',
      title: 'Parent Login',
      subtitle: "Access your child's journey",
      demoEmail: 'sarah@example.com',
      demoPass: 'parent123',
      path: '/parent',
    ),
    'driver': _LoginConfig(
      gradient: AppTheme.driverGradient,
      glowColor: AppTheme.driverCyan,
      accent: AppTheme.driverAccent,
      icon: 'assets/images/welcome_driver_transparent.gif',
      title: 'Driver Login',
      subtitle: 'Start your route today',
      demoEmail: 'mike@transport.com',
      demoPass: 'driver123',
      path: '/driver',
    ),
    'student': _LoginConfig(
      gradient: AppTheme.studentGradient,
      glowColor: AppTheme.studentAmber,
      accent: AppTheme.studentAccent,
      icon: 'assets/images/welcome_student_transparent.gif',
      title: 'Student Login',
      subtitle: 'Track your bus & attendance',
      demoEmail: 'noorulain@school.com',
      demoPass: 'student123',
      path: '/student',
    ),
  };

  _LoginConfig get _cfg => _configs[widget.role] ?? _configs['parent']!;

  void _fillDemo() {
    _emailCtrl.text = _cfg.demoEmail;
    _passCtrl.text = _cfg.demoPass;
    setState(() => _error = '');
  }

  void _onLangChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  void _login() {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = AppStrings.t('fill_fields_login'));
      return;
    }
    setState(() {
      _error = '';
      _loading = true;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        AuthService.instance.saveRole(widget.role);
        setState(() => _loading = false);
        context.go(_cfg.path);
      }
    });
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
                        _cfg.glowColor.withOpacity(0.4),
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
                                  color: _cfg.glowColor.withOpacity(0.45),
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
                          // Demo hint
                          GestureDetector(
                            onTap: _fillDemo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _cfg.glowColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _cfg.glowColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.t('use_demo'),
                                    style: TextStyle(
                                      color: _cfg.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_cfg.demoEmail}  ·  ${_cfg.demoPass}',
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

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
                                color: AppTheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.error.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text('⚠️  ', style: TextStyle(fontSize: 13)),
                                  Text(
                                    _error,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 13,
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
  final String icon, title, subtitle, demoEmail, demoPass, path;

  const _LoginConfig({
    required this.gradient,
    required this.glowColor,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.demoEmail,
    required this.demoPass,
    required this.path,
  });
}
