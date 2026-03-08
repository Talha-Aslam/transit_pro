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

  // Parent-specific — dynamic children list
  late List<_ChildData> _children;

  // Driver-specific
  final _licenseCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  String? _vehicleType;

  // Student-specific
  final _studentIdCtrl = TextEditingController();
  String? _studentGrade;
  final _studentSchoolCtrl = TextEditingController();
  bool _studentSchoolCustom = false;

  // Shared data
  static const _gradeOptions = ['School', 'College', 'University', 'Academy'];
  static const _vehicleTypes = [
    'Bus',
    'Van',
    'Carry Daba',
    'Auto Rickshaw',
    'Bike',
    'Car',
  ];
  static const _schoolList = [
    'Beaconhouse School System',
    'The City School',
    'Lahore Grammar School',
    'Roots School System',
    'Allied School',
    'Foundation Public School',
    'Froebels International School',
    'Army Public School',
    'Divisional Public School',
    'Government High School',
    'DHA Suffa University',
    'University of Punjab',
    'COMSATS University',
    'NUST',
    'FAST National University',
    'Aga Khan University',
    'Forman Christian College',
    'Government College University',
    'University of Lahore',
    'UET Lahore',
    'Air University',
    'Quaid-i-Azam University',
    'LUMS',
    'Bahria University',
    'Riphah International University',
  ];

  static final _roles = [
    _RoleCfg(
      'parent',
      'assets/images/welcome_parent_transparent.gif',
      'Parent',
      AppTheme.parentGradient,
      AppTheme.parentPurple,
      AppTheme.parentAccent,
    ),
    _RoleCfg(
      'driver',
      'assets/images/welcome_driver_transparent.gif',
      'Driver',
      AppTheme.driverGradient,
      AppTheme.driverCyan,
      AppTheme.driverAccent,
    ),
    _RoleCfg(
      'student',
      'assets/images/welcome_student_transparent.gif',
      'Student',
      AppTheme.studentGradient,
      AppTheme.studentAmber,
      AppTheme.studentAccent,
    ),
  ];

  _RoleCfg get _cfg => _roles.firstWhere((r) => r.id == _selectedRole);

  @override
  void initState() {
    super.initState();
    _children = [_ChildData()];
  }

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
    for (final c in _children) {
      c.dispose();
    }
    _licenseCtrl.dispose();
    _vehicleCtrl.dispose();
    _experienceCtrl.dispose();
    _studentIdCtrl.dispose();
    _studentSchoolCtrl.dispose();
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
                          'Back',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                                child: Image.asset(
                                  _cfg.icon,
                                  width: 62,
                                  height: 62,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            role.icon,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
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
            label: 'Continue',
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
                      color: _agreeTerms ? _cfg.accent : _cfg.accent,
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
            label: 'Create Account',
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
      // ── PARENT ──────────────────────────────────────────────────────────
      case 'parent':
        return [
          ..._children.asMap().entries.map((entry) {
            return _buildChildCard(entry.key, entry.value);
          }),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _children.add(_ChildData())),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.parentAccent.withOpacity(0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.parentAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Another Child',
                    style: TextStyle(
                      color: AppTheme.parentAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ];

      // ── DRIVER ──────────────────────────────────────────────────────────
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const _FieldLabel('VEHICLE TYPE'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      hint: 'Select type',
                      value: _vehicleType,
                      items: _vehicleTypes,
                      onChanged: (v) => setState(() => _vehicleType = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('EXPERIENCE (YRS)'),
          const SizedBox(height: 8),
          TextField(
            controller: _experienceCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'e.g. 5'),
          ),
          const SizedBox(height: 16),
        ];

      // ── STUDENT ──────────────────────────────────────────────────────────
      case 'student':
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const _FieldLabel('GRADE / LEVEL'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      hint: 'Select level',
                      value: _studentGrade,
                      items: _gradeOptions,
                      onChanged: (v) => setState(() => _studentGrade = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('SCHOOL / INSTITUTION'),
          const SizedBox(height: 8),
          _buildSchoolSearch(
            ctrl: _studentSchoolCtrl,
            isCustom: _studentSchoolCustom,
            onCustomChanged: (val) =>
                setState(() => _studentSchoolCustom = val),
          ),
          const SizedBox(height: 16),
        ];

      default:
        return [];
    }
  }

  // ── Child card ──────────────────────────────────────────────────────────
  Widget _buildChildCard(int index, _ChildData child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.parentPurple.withOpacity(context.isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.parentPurple.withOpacity(
            context.isDark ? 0.28 : 0.20,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Child ${index + 1}',
                style: TextStyle(
                  color: AppTheme.parentAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (_children.length > 1)
                GestureDetector(
                  onTap: () => setState(() {
                    child.dispose();
                    _children.removeAt(index);
                  }),
                  child: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Name
          const _FieldLabel("CHILD'S NAME"),
          const SizedBox(height: 6),
          TextField(
            controller: child.nameCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(hintText: "Child's full name"),
          ),
          const SizedBox(height: 12),
          // Grade dropdown
          const _FieldLabel('GRADE / LEVEL'),
          const SizedBox(height: 6),
          _buildDropdown(
            hint: 'Select level',
            value: child.grade,
            items: _gradeOptions,
            onChanged: (v) => setState(() => child.grade = v),
          ),
          const SizedBox(height: 12),
          // School search
          const _FieldLabel('SCHOOL / INSTITUTION'),
          const SizedBox(height: 6),
          _buildSchoolSearch(
            ctrl: child.schoolCtrl,
            isCustom: child.isCustomSchool,
            onCustomChanged: (val) =>
                setState(() => child.isCustomSchool = val),
          ),
        ],
      ),
    );
  }

  // ── Themed dropdown ─────────────────────────────────────────────────────
  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: context.textTertiary, fontSize: 14),
          ),
          isExpanded: true,
          dropdownColor: context.cardBgElevated,
          iconEnabledColor: context.textTertiary,
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Searchable school field with autocomplete ────────────────────────────
  Widget _buildSchoolSearch({
    required TextEditingController ctrl,
    required bool isCustom,
    required void Function(bool) onCustomChanged,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: ctrl.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        final matches = _schoolList
            .where((s) => s.toLowerCase().contains(query))
            .toList();
        // Add sentinel at the end to allow manual entry
        return [...matches, '__manual__:${textEditingValue.text.trim()}'];
      },
      displayStringForOption: (option) =>
          option.startsWith('__manual__:') ? '' : option,
      onSelected: (option) {
        if (option.startsWith('__manual__:')) {
          ctrl.text = option.substring('__manual__:'.length);
          onCustomChanged(true);
        } else {
          ctrl.text = option;
          onCustomChanged(false);
        }
      },
      fieldViewBuilder: (bCtx, fieldCtrl, focusNode, onFieldSubmitted) {
        return TextField(
          controller: fieldCtrl,
          focusNode: focusNode,
          onChanged: (value) => ctrl.text = value,
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search school / institution…',
            suffixIcon: isCustom
                ? Icon(Icons.edit_note, color: AppTheme.parentAccent, size: 20)
                : Icon(Icons.search, color: context.textTertiary, size: 18),
          ),
        );
      },
      optionsViewBuilder: (bCtx, onAutoCompleteSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: context.cardBgElevated,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: options.map((option) {
                  final isManual = option.startsWith('__manual__:');
                  final label = isManual
                      ? '+ Add "${option.substring('__manual__:'.length)}" manually'
                      : option;
                  return InkWell(
                    onTap: () => onAutoCompleteSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isManual
                              ? AppTheme.parentAccent
                              : context.textPrimary,
                          fontSize: 14,
                          fontWeight: isManual
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
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

/// Holds per-child form state for the parent signup flow.
class _ChildData {
  final nameCtrl = TextEditingController();
  final schoolCtrl = TextEditingController();
  String? grade;
  bool isCustomSchool = false;

  void dispose() {
    nameCtrl.dispose();
    schoolCtrl.dispose();
  }
}
