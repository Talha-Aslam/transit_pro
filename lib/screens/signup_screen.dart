import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _selectedRole = 'parent';
  bool _loading = false;
  bool _showPass = false;
  bool _agreeTerms = false;
  int _step = 0; // 0 = role pick, 1 = form

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Parent-specific
  final _childNameCtrl = TextEditingController();
  final _childGradeCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();

  // Driver-specific
  final _licenseCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  // Student-specific
  final _studentIdCtrl = TextEditingController();
  final _studentGradeCtrl = TextEditingController();
  final _studentSchoolCtrl = TextEditingController();

  static final _roles = [
    _RoleCfg(
      'parent',
      '👨‍👩‍👧',
      'Parent',
      AppTheme.parentGradient,
      AppTheme.parentPurple,
      AppTheme.parentAccent,
    ),
    _RoleCfg(
      'driver',
      '🚌',
      'Driver',
      AppTheme.driverGradient,
      AppTheme.driverCyan,
      AppTheme.driverAccent,
    ),
    _RoleCfg(
      'student',
      '🎓',
      'Student',
      AppTheme.studentGradient,
      AppTheme.studentAmber,
      AppTheme.studentAccent,
    ),
  ];

  _RoleCfg get _cfg => _roles.firstWhere((r) => r.id == _selectedRole);

  void _signup() {
    if (!_agreeTerms) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _loading = false);
        context.go('/login/$_selectedRole');
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _childNameCtrl.dispose();
    _childGradeCtrl.dispose();
    _schoolCtrl.dispose();
    _licenseCtrl.dispose();
    _vehicleCtrl.dispose();
    _experienceCtrl.dispose();
    _studentIdCtrl.dispose();
    _studentGradeCtrl.dispose();
    _studentSchoolCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: Stack(
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
                      colors: [_cfg.glow.withOpacity(0.35), Colors.transparent],
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
                      onTap: () {
                        if (_step == 1) {
                          setState(() => _step = 0);
                        } else {
                          context.go('/role-select');
                        }
                      },
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
                          '← Back',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Header
                    Center(
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              key: ValueKey(_selectedRole),
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: _cfg.gradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: _cfg.glow.withOpacity(0.45),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _cfg.icon,
                                  style: const TextStyle(fontSize: 36),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _step == 0
                                ? 'Create Account'
                                : '${_cfg.label} Details',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _step == 0
                                ? 'Select your role to get started'
                                : 'Fill in your information below',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Step indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StepDot(active: true, color: _cfg.accent),
                              Container(
                                width: 30,
                                height: 2,
                                color: _step >= 1
                                    ? _cfg.accent
                                    : context.surfaceBorder,
                              ),
                              _StepDot(active: _step >= 1, color: _cfg.accent),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    if (_step == 0) _buildRolePicker(),
                    if (_step == 1) _buildFormStep(),

                    const SizedBox(height: 20),
                    // Login link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/role-select'),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: _cfg.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePicker() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('SELECT YOUR ROLE'),
          const SizedBox(height: 14),
          ...(_roles.map((role) {
            final isSelected = _selectedRole == role.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedRole = role.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? role.glow.withOpacity(0.12)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? role.accent.withOpacity(0.6)
                          : context.cardBgElevated,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: role.gradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            role.icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          role.label,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSelected ? role.gradient : null,
                          border: Border.all(
                            color: isSelected
                                ? role.accent
                                : Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Text(
                                  '✓',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          })),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Continue →',
            gradient: _cfg.gradient,
            glowColor: _cfg.glow,
            onTap: () => setState(() => _step = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Common fields
          const _FieldLabel('FULL NAME'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Enter your full name'),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('EMAIL ADDRESS'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Enter your email'),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('PHONE NUMBER'),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Enter your phone number',
            ),
          ),
          const SizedBox(height: 16),

          // Role-specific fields
          ..._roleSpecificFields(),

          const _FieldLabel('PASSWORD'),
          const SizedBox(height: 8),
          TextField(
            controller: _passCtrl,
            obscureText: !_showPass,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Create a password',
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _showPass = !_showPass),
                child: Icon(
                  _showPass ? Icons.visibility_off : Icons.visibility,
                  color: context.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('CONFIRM PASSWORD'),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPassCtrl,
            obscureText: true,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Re-enter your password',
            ),
          ),
          const SizedBox(height: 18),

          // Terms
          GestureDetector(
            onTap: () => setState(() => _agreeTerms = !_agreeTerms),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: _agreeTerms ? _cfg.gradient : null,
                    border: Border.all(
                      color: _agreeTerms
                          ? _cfg.accent
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: _agreeTerms
                      ? Center(
                          child: Text(
                            '✓',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'I agree to the Terms of Service & Privacy Policy',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          GradientButton(
            label: 'Create Account →',
            gradient: _cfg.gradient,
            glowColor: _cfg.glow,
            isLoading: _loading,
            onTap: _signup,
          ),
        ],
      ),
    );
  }

  List<Widget> _roleSpecificFields() {
    switch (_selectedRole) {
      case 'parent':
        return [
          const _FieldLabel("CHILD'S NAME"),
          const SizedBox(height: 8),
          TextField(
            controller: _childNameCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: "Enter your child's name",
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel("CHILD'S GRADE"),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _childGradeCtrl,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Grade 5',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('SCHOOL NAME'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _schoolCtrl,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'School name',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ];
      case 'driver':
        return [
          const _FieldLabel('LICENSE NUMBER'),
          const SizedBox(height: 8),
          TextField(
            controller: _licenseCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Enter your driving license number',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('VEHICLE NUMBER'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _vehicleCtrl,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. BUS-42',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('EXPERIENCE (YRS)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _experienceCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(hintText: 'e.g. 5'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ];
      case 'student':
        return [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('STUDENT ID'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _studentIdCtrl,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. STU-1234',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('GRADE / CLASS'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _studentGradeCtrl,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Grade 10',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('SCHOOL / COLLEGE NAME'),
          const SizedBox(height: 8),
          TextField(
            controller: _studentSchoolCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Enter your school or college name',
            ),
          ),
          const SizedBox(height: 16),
        ];
      default:
        return [];
    }
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
        color: Colors.white.withOpacity(0.6),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final Color color;
  const _StepDot({required this.active, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : context.surfaceBorder,
        border: Border.all(
          color: active ? color : Colors.white.withOpacity(0.2),
          width: 2,
        ),
      ),
    );
  }
}

class _RoleCfg {
  final String id, icon, label;
  final LinearGradient gradient;
  final Color glow, accent;
  const _RoleCfg(
    this.id,
    this.icon,
    this.label,
    this.gradient,
    this.glow,
    this.accent,
  );
}
