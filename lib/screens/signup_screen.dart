import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_picker_screen.dart';
import 'package:go_router/go_router.dart';
import '../app/auth_service.dart';
import '../app/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/image_source_sheet.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _selectedRole = 'parent';
  bool _loading = false;
  bool _showPass = false;
  bool _showConfirmPass = false;
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
  final _picker = ImagePicker();
  final _licenseCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _seatCapacityCtrl = TextEditingController();
  String? _vehicleType;
  String? _licenseFileName;
  String? _idCardFileName;

  // Student-specific
  final _studentIdCtrl = TextEditingController();
  String? _studentGrade;
  final _studentSchoolCtrl = TextEditingController();
  bool _studentSchoolCustom = false;
  final _studentPickupCtrl = TextEditingController();
  final _studentDropoffCtrl = TextEditingController();
  LatLng? _studentPickupLatLng;
  LatLng? _studentDropoffLatLng;

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
      'assets/images/role_selection/welcome_parent_transparent.gif',
      'Parent',
      AppTheme.parentGradient,
      AppTheme.parentPurple,
      AppTheme.parentAccent,
    ),
    _RoleCfg(
      'driver',
      'assets/images/role_selection/welcome_driver_transparent.gif',
      'Driver',
      AppTheme.driverGradient,
      AppTheme.driverCyan,
      AppTheme.driverAccent,
    ),
    _RoleCfg(
      'student',
      'assets/images/role_selection/welcome_student_transparent.gif',
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
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() => setState(() {});

  String? get _passwordMismatchError {
    final confirm = _confirmPassCtrl.text;
    if (confirm.isEmpty) return null;
    return _passCtrl.text != confirm ? AppStrings.t('pwd_no_match') : null;
  }

  Future<void> _pickDriverDocument({required bool isLicense}) async {
    final source = await showImageSourceSheet(
      context,
      accentColor: AppTheme.driverCyan,
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      if (isLicense) {
        _licenseFileName = picked.name;
      } else {
        _idCardFileName = picked.name;
      }
    });
  }

  String _localizedRoleName(String id) {
    switch (id) {
      case 'parent':
        return AppStrings.t('parent_role_name');
      case 'driver':
        return AppStrings.t('driver_role_name');
      default:
        return AppStrings.t('student_role_name');
    }
  }

  void _signup() {
    if (!_agreeTerms) return;
    if (_selectedRole == 'driver') {
      final missing = _missingDriverField();
      if (missing != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(missing)));
        return;
      }
    }
    if (_selectedRole == 'student') {
      final missing = _missingStudentField();
      if (missing != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(missing)));
        return;
      }
    }
    // block signup if passwords don't match
    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.t('pwd_no_match'))));
      return;
    }

    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _loading = false);
        context.go('/login/$_selectedRole');
      }
    });
  }

  Future<void> _googleContinue() async {
    setState(() => _loading = true);

    final userCredential = await AuthService.instance.signInWithGoogle();

    if (!mounted) return;

    setState(() => _loading = false);

    if (userCredential == null) {
      return;
    }

    await AuthService.instance.saveRole(_selectedRole);
    if (mounted) {
      context.go(AuthService.routeForRole(_selectedRole));
    }
  }

  String? _missingDriverField() {
    if (_nameCtrl.text.trim().isEmpty) return 'Please enter driver name';
    if (_emailCtrl.text.trim().isEmpty) return 'Please enter email address';
    if (_phoneCtrl.text.trim().isEmpty) return 'Please enter phone number';
    if (_passCtrl.text.isEmpty) return 'Please enter password';
    if (_confirmPassCtrl.text.isEmpty) return 'Please confirm password';
    if (_licenseCtrl.text.trim().isEmpty) {
      return 'Please enter license number';
    }
    if (_vehicleCtrl.text.trim().isEmpty) {
      return 'Please enter vehicle number';
    }
    if (_vehicleType == null || _vehicleType!.trim().isEmpty) {
      return 'Please select vehicle type';
    }
    if (_seatCapacityCtrl.text.trim().isEmpty) {
      return 'Please enter seat capacity';
    }
    if (_experienceCtrl.text.trim().isEmpty) {
      return 'Please enter experience';
    }
    return null;
  }

  String? _missingStudentField() {
    if (_nameCtrl.text.trim().isEmpty) return AppStrings.t('enter_full_name');
    if (_studentSchoolCtrl.text.trim().isEmpty) {
      return AppStrings.t('please_select_school');
    }
    return null;
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
    _seatCapacityCtrl.dispose();
    _studentIdCtrl.dispose();
    _studentSchoolCtrl.dispose();
    _studentPickupCtrl.dispose();
    _studentDropoffCtrl.dispose();
    LanguageProvider.instance.removeListener(_onLangChanged);
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
                        _cfg.glow.withValues(alpha: 0.35),
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
                                    color: _cfg.glow.withValues(alpha: 0.45),
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
                                ? AppStrings.t('create_account')
                                : '${_localizedRoleName(_selectedRole)} ${AppStrings.t('details_lbl')}',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _step == 0
                                ? AppStrings.t('select_role_to_start')
                                : AppStrings.t('fill_info'),
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
                            AppStrings.t('already_account'),
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
          _FieldLabel(AppStrings.t('select_your_role_lbl')),
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
                        ? role.glow.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? role.accent.withValues(alpha: 0.6)
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
                          _localizedRoleName(role.id),
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
                                : Colors.white.withValues(alpha: 0.2),
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
            label: AppStrings.t('continue_btn'),
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
          _FieldLabel(
            AppStrings.t('full_name_lbl'),
            important: _selectedRole == 'student',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('enter_full_name'),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.t('email_address_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(hintText: AppStrings.t('enter_email')),
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.t('phone_lbl')),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(hintText: AppStrings.t('enter_phone')),
          ),
          const SizedBox(height: 16),

          // Role-specific fields
          ..._roleSpecificFields(),

          _FieldLabel(AppStrings.t('password_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _passCtrl,
            obscureText: !_showPass,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('create_password_hint'),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _showPass = !_showPass),
                child: Icon(
                  _showPass ? Icons.visibility_off : Icons.visibility,
                  color: context.textTertiary,
                  size: 20,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.t('confirm_password_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPassCtrl,
            obscureText: !_showConfirmPass,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('reenter_password_hint'),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _showConfirmPass = !_showConfirmPass),
                child: Icon(
                  _showConfirmPass ? Icons.visibility_off : Icons.visibility,
                  color: context.textTertiary,
                  size: 20,
                ),
              ),
              errorText: _passwordMismatchError,
            ),
            onChanged: (_) => setState(() {}),
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
            label: AppStrings.t('create_account_btn'),
            gradient: _cfg.gradient,
            glowColor: _cfg.glow,
            isLoading: _loading,
            isEnabled: _agreeTerms,
            onTap: _agreeTerms ? _signup : null,
          ),
          const SizedBox(height: 20),

          if (_selectedRole != 'driver') ...[
            // Google Login Option
            Row(
              children: [
                Expanded(
                  child: Divider(color: context.surfaceBorder, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Or continue with',
                    style: TextStyle(color: context.textTertiary, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Divider(color: context.surfaceBorder, thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _googleContinue,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: context.cardBgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.inputBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/utilities/google.png',
                      height: 20,
                      width: 20,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.g_mobiledata, size: 24),
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
                  color: AppTheme.parentAccent.withValues(alpha: 0.5),
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
                    AppStrings.t('add_another_child'),
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
          _FieldLabel(AppStrings.t('license_number_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _licenseCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('enter_license_hint'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _documentUploadTile(
                  title: 'Upload License',
                  subtitle: _licenseFileName ?? 'Front photo of license',
                  icon: Icons.badge_rounded,
                  accentColor: AppTheme.driverCyan,
                  onTap: () => _pickDriverDocument(isLicense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _documentUploadTile(
                  title: 'Upload ID Card',
                  subtitle: _idCardFileName ?? 'CNIC / national ID photo',
                  icon: Icons.credit_card_rounded,
                  accentColor: AppTheme.driverCyan,
                  onTap: () => _pickDriverDocument(isLicense: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(
                      AppStrings.t('vehicle_number_lbl'),
                      important: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _vehicleCtrl,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: AppStrings.t('vehicle_number_hint'),
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
                    _FieldLabel(
                      AppStrings.t('vehicle_type_lbl'),
                      important: true,
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      hint: AppStrings.t('select_type_hint'),
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
          _FieldLabel('Transport seat capacity', important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _seatCapacityCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Enter seat capacity',
              suffixIcon: Icon(
                Icons.event_seat_rounded,
                color: AppTheme.driverCyan,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppStrings.t('experience_yrs_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _experienceCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('experience_hint'),
            ),
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
                    _FieldLabel(AppStrings.t('student_id_lbl')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _studentIdCtrl,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: AppStrings.t('student_id_hint'),
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
                    _FieldLabel(AppStrings.t('grade_level_lbl')),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      hint: AppStrings.t('select_level_hint'),
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
          _FieldLabel(AppStrings.t('school_institution_lbl'), important: true),
          const SizedBox(height: 8),
          _buildSchoolSearch(
            ctrl: _studentSchoolCtrl,
            isCustom: _studentSchoolCustom,
            onCustomChanged: (val) =>
                setState(() => _studentSchoolCustom = val),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Pickup location', important: true),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final res = await Navigator.of(context).push<LatLng?>(
                MaterialPageRoute(
                  builder: (_) =>
                      MapPickerScreen(initial: _studentPickupLatLng),
                ),
              );
              if (res != null) {
                setState(() {
                  _studentPickupLatLng = res;
                  _studentPickupCtrl.text =
                      '${res.latitude.toStringAsFixed(6)}, ${res.longitude.toStringAsFixed(6)}';
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: context.cardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.inputBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _studentPickupCtrl.text.isEmpty
                          ? 'Select pickup on map'
                          : _studentPickupCtrl.text,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.map, color: context.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FieldLabel('Dropoff location', important: true),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final res = await Navigator.of(context).push<LatLng?>(
                MaterialPageRoute(
                  builder: (_) =>
                      MapPickerScreen(initial: _studentDropoffLatLng),
                ),
              );
              if (res != null) {
                setState(() {
                  _studentDropoffLatLng = res;
                  _studentDropoffCtrl.text =
                      '${res.latitude.toStringAsFixed(6)}, ${res.longitude.toStringAsFixed(6)}';
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: context.cardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.inputBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _studentDropoffCtrl.text.isEmpty
                          ? 'Select dropoff on map'
                          : _studentDropoffCtrl.text,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.map, color: context.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ];

      default:
        return [];
    }
  }

  Widget _documentUploadTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const Spacer(),
                Icon(Icons.upload_file_rounded, color: accentColor, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Child card ──────────────────────────────────────────────────────────
  Widget _buildChildCard(int index, _ChildData child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.parentPurple.withValues(
          alpha: context.isDark ? 0.10 : 0.06,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.parentPurple.withValues(
            alpha: context.isDark ? 0.28 : 0.20,
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
                '${AppStrings.t('child_lbl')} ${index + 1}',
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
          _FieldLabel(AppStrings.t('childs_name_lbl')),
          const SizedBox(height: 6),
          TextField(
            controller: child.nameCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('childs_name_hint'),
            ),
          ),
          const SizedBox(height: 12),
          // Grade dropdown
          _FieldLabel(AppStrings.t('grade_level_lbl')),
          const SizedBox(height: 6),
          _buildDropdown(
            hint: AppStrings.t('select_level_hint'),
            value: child.grade,
            items: _gradeOptions,
            onChanged: (v) => setState(() => child.grade = v),
          ),
          const SizedBox(height: 12),
          // School search
          _FieldLabel(AppStrings.t('school_institution_lbl')),
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
            hintText: AppStrings.t('search_school_hint'),
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
  final bool important;
  const _FieldLabel(this.text, {this.important = false});
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: context.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        children: [
          TextSpan(text: text),
          if (important)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
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
          color: active ? color : Colors.white.withValues(alpha: 0.2),
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
