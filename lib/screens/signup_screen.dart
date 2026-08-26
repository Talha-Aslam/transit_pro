import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';
import '../app/auth_service.dart';
import '../app/language_provider.dart';
import '../app/profile_draft.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/profile_form_fields.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _selectedRole = 'parent';
  bool _loading = false;
  bool _agreeTerms = false;
  int _step = 0; // 0 = role pick, 1 = form

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Parent-specific — dynamic children list
  late List<ChildFormData> _children;

  // Driver-specific
  final _picker = ImagePicker();
  final _licenseCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _seatCapacityCtrl = TextEditingController();
  String? _vehicleType;

  // Real files, not just names. The prototype kept `picked.name` and never
  // uploaded anything, so a driver's licence existed only as a caption.
  File? _licensePhoto;
  File? _idCardPhoto;

  /// Where the driver runs, and the rounds families can book. Collected here as
  /// well as on the Google completion screen, and validated by the same
  /// `ProfileRequirements` — the two forms have to ask for the same things or one
  /// route produces accounts the other would reject.
  final List<ServiceAreaFormData> _serviceAreas = [ServiceAreaFormData()];
  final List<RoundFormData> _rounds = [RoundFormData.fresh(ordinal: 1)];
  double _serviceRadiusKm = 5;
  GeoCoord? _baseLocation;

  // Student-specific
  final _studentIdCtrl = TextEditingController();
  String? _studentGrade;
  final _studentSchoolCtrl = TextEditingController();
  bool _studentSchoolCustom = false;
  GeoCoord? _studentPickupLatLng;
  GeoCoord? _studentDropoffLatLng;

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
    _children = [ChildFormData()];
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() => setState(() {});

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
        _licensePhoto = File(picked.path);
      } else {
        _idCardPhoto = File(picked.path);
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

  UserRole _roleFromId(String id) => switch (id) {
        'driver' => UserRole.driver,
        'student' => UserRole.student,
        _ => UserRole.parent,
      };

  /// Everything the form has collected, in the shape `OnboardingService` wants.
  ///
  /// The same type the Google completion screen builds, which is what
  /// guarantees the two routes create identical accounts.
  ProfileDraft _buildDraft() => ProfileDraft(
        role: _roleFromId(_selectedRole),
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        children: _children
            .map(
              (c) => ChildDraft(
                name: c.nameCtrl.text,
                grade: c.grade ?? '',
                school: c.schoolCtrl.text,
                studentIdNumber: c.studentIdCtrl.text,
                pickupLocation: c.pickup,
              ),
            )
            .toList(),
        studentIdNumber: _studentIdCtrl.text,
        instituteType: _studentGrade ?? '',
        school: _studentSchoolCtrl.text,
        pickupLocation: _studentPickupLatLng,
        dropoffLocation: _studentDropoffLatLng,
        licenseNumber: _licenseCtrl.text,
        experienceYears: int.tryParse(_experienceCtrl.text.trim()) ?? 0,
        vehicleNumber: _vehicleCtrl.text,
        vehicleType: _vehicleType ?? '',
        seatCapacity: int.tryParse(_seatCapacityCtrl.text.trim()) ?? 0,
        serviceAreas: _serviceAreas
            .where((a) => !a.isBlank)
            .map((a) => a.toModel())
            .toList(),
        serviceRadiusKm: _serviceRadiusKm,
        baseLocation: _baseLocation,
        schedules: _rounds.map((r) => r.toModel()).toList(),
        licensePhoto: _licensePhoto,
        idCardPhoto: _idCardPhoto,
      );

  Future<void> _signup() async {
    if (!_agreeTerms) return;

    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _showError(AppStrings.t('fill_fields_login'));
      return;
    }

    if (_passCtrl.text != _confirmPassCtrl.text) {
      _showError(AppStrings.t('pwd_no_match'));
      return;
    }

    final draft = _buildDraft();

    // One validator for both sign-up routes. The old per-role checks disagreed
    // with the asterisks on screen — pickup and dropoff were marked required
    // but never actually verified.
    final gap = ProfileRequirements.firstGapMessage(draft);
    if (gap != null) {
      _showError(gap);
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await AuthService.instance.signUp(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        draft: draft,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      // Firebase signs the user in as part of account creation, and the profile
      // is already complete, so go straight to their home.
      context.go(AuthService.routeForUserRole(user.role));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.message);
    } catch (e) {
      // Defence-in-depth: `AuthService.signUp` has its own catch-all, but
      // this call is fire-and-forget from the button, so any exception type
      // that somehow still escaped it must not leave `_loading` stuck `true`
      // forever.
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    for (final a in _serviceAreas) {
      a.dispose();
    }
    for (final r in _rounds) {
      r.dispose();
    }
    _studentIdCtrl.dispose();
    _studentSchoolCtrl.dispose();
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
                              StepDot(active: true, color: _cfg.accent),
                              Container(
                                width: 30,
                                height: 2,
                                color: _step >= 1
                                    ? _cfg.accent
                                    : context.surfaceBorder,
                              ),
                              StepDot(active: _step >= 1, color: _cfg.accent),
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
          FieldLabel(AppStrings.t('select_your_role_lbl')),
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
      // This card is the page's scroll content and can run to a dozen+
      // fields/cards for a driver — it repaints on every scroll frame, so a
      // live BackdropFilter here would re-blur constantly. Skip it; the
      // translucent fill/border still reads as glass.
      enableBlur: false,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Common fields
          FieldLabel(AppStrings.t('full_name_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('enter_full_name'),
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(AppStrings.t('email_address_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(hintText: AppStrings.t('enter_email')),
          ),
          const SizedBox(height: 16),
          FieldLabel(AppStrings.t('phone_lbl'), important: true),
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

          _PasswordFields(
            passwordController: _passCtrl,
            confirmController: _confirmPassCtrl,
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
                    border: Border.all(color: _cfg.accent),
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
        ],
      ),
    );
  }

  List<Widget> _roleSpecificFields() {
    switch (_selectedRole) {
      // ── PARENT ──────────────────────────────────────────────────────────
      case 'parent':
        return [
          ..._children.asMap().entries.map(
                (entry) => ChildCard(
                  key: ValueKey(entry.value),
                  index: entry.key,
                  data: entry.value,
                  canRemove: _children.length > 1,
                  onRemove: () => setState(() {
                    _children[entry.key].dispose();
                    _children.removeAt(entry.key);
                  }),
                  onChanged: () => setState(() {}),
                ),
              ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _children.add(ChildFormData())),
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
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.parentAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.t('add_another_child'),
                    style: const TextStyle(
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
          FieldLabel(AppStrings.t('license_number_lbl'), important: true),
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
                child: DocumentUploadTile(
                  title: 'Upload License',
                  subtitle: _licensePhoto == null
                      ? 'Front photo of license'
                      : 'Ready to upload',
                  icon: Icons.badge_rounded,
                  accentColor: AppTheme.driverCyan,
                  isDone: _licensePhoto != null,
                  onTap: () => _pickDriverDocument(isLicense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DocumentUploadTile(
                  title: 'Upload ID Card',
                  subtitle: _idCardPhoto == null
                      ? 'CNIC / national ID photo'
                      : 'Ready to upload',
                  icon: Icons.credit_card_rounded,
                  accentColor: AppTheme.driverCyan,
                  isDone: _idCardPhoto != null,
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
                    FieldLabel(
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
                    FieldLabel(
                      AppStrings.t('vehicle_type_lbl'),
                      important: true,
                    ),
                    const SizedBox(height: 8),
                    ThemedDropdown(
                      hint: AppStrings.t('select_type_hint'),
                      value: _vehicleType,
                      items: kVehicleTypes,
                      onChanged: (v) => setState(() => _vehicleType = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('TRANSPORT SEAT CAPACITY', important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _seatCapacityCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Enter seat capacity',
              suffixIcon: Icon(
                Icons.event_seat_rounded,
                color: AppTheme.driverCyan,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(AppStrings.t('experience_yrs_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _experienceCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('experience_hint'),
            ),
          ),
          const SizedBox(height: 24),
          ..._driverServiceFields(),
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
                    FieldLabel(
                      AppStrings.t('student_id_lbl'),
                      important: true,
                    ),
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
                    FieldLabel(
                      AppStrings.t('grade_level_lbl'),
                      important: true,
                    ),
                    const SizedBox(height: 8),
                    ThemedDropdown(
                      hint: AppStrings.t('select_level_hint'),
                      value: _studentGrade,
                      items: kGradeOptions,
                      onChanged: (v) => setState(() => _studentGrade = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FieldLabel(AppStrings.t('school_institution_lbl'), important: true),
          const SizedBox(height: 8),
          SchoolSearchField(
            controller: _studentSchoolCtrl,
            isCustom: _studentSchoolCustom,
            onCustomChanged: (val) =>
                setState(() => _studentSchoolCustom = val),
            accentColor: AppTheme.studentAccent,
          ),
          const SizedBox(height: 16),
          const FieldLabel('PICKUP LOCATION', important: true),
          const SizedBox(height: 8),
          MapPointField(
            placeholder: 'Select pickup on map',
            value: _studentPickupLatLng,
            accentColor: AppTheme.studentAmber,
            onPicked: (p) => setState(() => _studentPickupLatLng = p),
          ),
          const SizedBox(height: 12),
          const FieldLabel('DROPOFF LOCATION', important: true),
          const SizedBox(height: 8),
          MapPointField(
            placeholder: 'Select dropoff on map',
            value: _studentDropoffLatLng,
            accentColor: AppTheme.studentAmber,
            onPicked: (p) => setState(() => _studentDropoffLatLng = p),
          ),
          const SizedBox(height: 16),
        ];

      default:
        return [];
    }
  }

  /// Service areas, travel radius and bookable rounds.
  ///
  /// Mirrors the same section on the Google profile-completion screen and shares
  /// its widgets, so a driver who signs up manually and one who signs in with
  /// Google are asked for identical information and end up with identical
  /// documents.
  List<Widget> _driverServiceFields() => [
    _serviceHeading(
      'Where do you drive?',
      'Parents find you by their child\'s school, so list every institution '
          'you already run to.',
    ),
    const SizedBox(height: 14),
    ..._serviceAreas.asMap().entries.map(
      (e) => ServiceAreaCard(
        key: ValueKey(e.value),
        index: e.key,
        data: e.value,
        canRemove: _serviceAreas.length > 1,
        onRemove: () => setState(() {
          _serviceAreas[e.key].dispose();
          _serviceAreas.removeAt(e.key);
        }),
        onChanged: () => setState(() {}),
        accentColor: AppTheme.driverCyan,
      ),
    ),
    _serviceAddButton(
      'Add another destination',
      () => setState(() => _serviceAreas.add(ServiceAreaFormData())),
    ),
    const SizedBox(height: 18),
    const FieldLabel('YOUR STARTING POINT (OPTIONAL)'),
    const SizedBox(height: 8),
    MapPointField(
      placeholder: 'Tap to pin where you start your day',
      value: _baseLocation,
      accentColor: AppTheme.driverCyan,
      onPicked: (p) => setState(() => _baseLocation = p),
    ),
    const SizedBox(height: 16),
    FieldLabel('HOW FAR WILL YOU TRAVEL? — ${_serviceRadiusKm.round()} KM'),
    Slider(
      value: _serviceRadiusKm,
      min: 1,
      max: 30,
      divisions: 29,
      activeColor: AppTheme.driverCyan,
      label: '${_serviceRadiusKm.round()} km',
      onChanged: (v) => setState(() => _serviceRadiusKm = v),
    ),
    Text(
      'Families further than this from your starting point will not see you.',
      style: TextStyle(color: context.textTertiary, fontSize: 11),
    ),
    const SizedBox(height: 24),
    _serviceHeading(
      'Your rounds',
      'Add one round per trip you run. A 6:30 group and a 7:30 group are two '
          'rounds, and each gets its own seats — so a 12-seater offers 12 seats '
          'on both.',
    ),
    const SizedBox(height: 14),
    ..._rounds.asMap().entries.map(
      (e) => RoundCard(
        key: ValueKey(e.value),
        index: e.key,
        data: e.value,
        canRemove: _rounds.length > 1,
        onRemove: () => setState(() {
          _rounds[e.key].dispose();
          _rounds.removeAt(e.key);
        }),
        onChanged: () => setState(() {}),
        accentColor: AppTheme.driverCyan,
      ),
    ),
    _serviceAddButton(
      'Add another round',
      () => setState(() {
        _rounds.add(
          RoundFormData.fresh(
            ordinal: _rounds.length + 1,
            seats: int.tryParse(_seatCapacityCtrl.text.trim()) ?? 0,
          ),
        );
      }),
    ),
  ];

  Widget _serviceHeading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(height: 1, color: context.surfaceBorder),
      const SizedBox(height: 16),
      Text(
        title,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: TextStyle(color: context.textSecondary, fontSize: 12),
      ),
    ],
  );

  Widget _serviceAddButton(String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.driverCyan.withValues(alpha: 0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: AppTheme.driverCyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.driverCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Owns the visibility toggles and live mismatch check locally, so typing in
/// either field only repaints these two fields instead of the entire
/// (blur-backed) signup form.
class _PasswordFields extends StatefulWidget {
  final TextEditingController passwordController;
  final TextEditingController confirmController;

  const _PasswordFields({
    required this.passwordController,
    required this.confirmController,
  });

  @override
  State<_PasswordFields> createState() => _PasswordFieldsState();
}

class _PasswordFieldsState extends State<_PasswordFields> {
  bool _showPass = false;
  bool _showConfirmPass = false;

  String? get _mismatchError {
    final confirm = widget.confirmController.text;
    if (confirm.isEmpty) return null;
    return widget.passwordController.text != confirm
        ? AppStrings.t('pwd_no_match')
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(AppStrings.t('password_lbl'), important: true),
        const SizedBox(height: 8),
        TextField(
          controller: widget.passwordController,
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
        FieldLabel(AppStrings.t('confirm_password_lbl'), important: true),
        const SizedBox(height: 8),
        TextField(
          controller: widget.confirmController,
          obscureText: !_showConfirmPass,
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: AppStrings.t('reenter_password_hint'),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _showConfirmPass = !_showConfirmPass),
              child: Icon(
                _showConfirmPass ? Icons.visibility_off : Icons.visibility,
                color: context.textTertiary,
                size: 20,
              ),
            ),
            errorText: _mismatchError,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
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
