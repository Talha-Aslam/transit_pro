import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transit_core/transit_core.dart';

import '../app/auth_service.dart';
import '../app/language_provider.dart';
import '../app/onboarding_service.dart';
import '../app/profile_draft.dart';
import '../app/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/profile_form_fields.dart';

/// One-time onboarding for accounts that arrive without a full profile.
///
/// Google hands us a name, an email and a photo — nothing else. A parent still
/// needs children, a student needs an ID and pickup points, a driver needs a
/// licence and a vehicle. This screen collects exactly what is missing for the
/// role the user already chose, then writes it through [OnboardingService] so
/// the result is indistinguishable from an email/password sign-up.
///
/// **The role is never asked here.** `/role-select` asks for it exactly once,
/// before either the login or sign-up screen is even reached, so re-asking on
/// this screen would just be a second copy of the same question. See
/// [_resolveRole] for where the role actually comes from and the one edge case
/// where it can genuinely be unknown.
///
/// **It cannot be skipped.** There is no back button, the Android back gesture
/// is trapped, and `router.dart` redirects every protected route here until
/// `profileComplete` is true. The only ways out are finishing or signing out.
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  UserRole? _role;

  /// True while [_resolveRole] is still waiting on [SessionService.user] to
  /// catch up — see that method for why this window can exist at all, and why
  /// it is always brief. Rendered as a plain spinner, never the "lost track of
  /// your role" card: at this point we simply haven't heard back yet, we don't
  /// actually not know.
  bool _resolvingRole = false;

  /// True only once [_resolveRole]'s wait genuinely timed out with nothing —
  /// a real backend problem (e.g. Firestore rejecting the read), not the brief
  /// ordering gap [_resolvingRole] covers.
  bool _roleMissing = false;

  bool _saving = false;
  String _error = '';

  final _picker = ImagePicker();

  // Shared
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _email = '';
  String? _photoUrl;

  // Parent
  final List<ChildFormData> _children = [ChildFormData()];

  // Student
  final _studentIdCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  bool _schoolIsCustom = false;
  String? _instituteType;
  GeoCoord? _pickup;
  GeoCoord? _dropoff;

  // Driver
  final _licenseCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _seatCapacityCtrl = TextEditingController();
  String? _vehicleType;
  File? _licensePhoto;
  File? _idCardPhoto;

  /// Where this driver runs, and the rounds families can book.
  ///
  /// Both are required for a driver (see `ProfileRequirements`) because without
  /// them the account is complete but invisible: no parent search can ever
  /// return a driver who has named no institution, and no seat can be requested
  /// on a driver who has defined no round. Collecting them at sign-up rather
  /// than "later, from your profile" is the difference between a driver who gets
  /// requests and one who waits indefinitely wondering why nobody calls.
  final List<ServiceAreaFormData> _serviceAreas = [ServiceAreaFormData()];
  final List<RoundFormData> _rounds = [
    RoundFormData.fresh(ordinal: 1),
  ];
  double _serviceRadiusKm = 5;
  GeoCoord? _baseLocation;

  @override
  void initState() {
    super.initState();
    _prefillFromAccount();
    _resolveRole();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() => setState(() {});

  /// The profile behind this account, from whichever source already has it.
  ///
  /// [SessionService.user] is fed by a Firestore *listener* — authoritative,
  /// but it updates on whatever schedule the snapshot arrives on.
  /// [AuthService.currentUser] is a plain field that `signInWithGoogle` sets
  /// synchronously, in the same call that just created or fetched this exact
  /// record. Checking it first covers the specific gap this screen exists to
  /// close: this screen can be reached *because* [SessionService] reacted to
  /// that very same record landing in Firestore and told the router to
  /// navigate here, and Flutter schedules that navigation for the next frame
  /// rather than inline — so by the time this widget actually builds, both
  /// sources are normally already in agreement. [_resolveRole] still allows
  /// for the case where they briefly aren't.
  AppUser? get _knownProfile =>
      AuthService.instance.currentUser ?? SessionService.instance.user.value;

  /// Works out the role without ever asking.
  ///
  /// There is exactly one legitimate source: [_knownProfile]. By the time this
  /// screen can be reached, a `users/{uid}` document already exists with a
  /// role on it — either because the account predates `profileComplete` and
  /// was already assigned one, or because `AuthService.signInWithGoogle`
  /// writes the role straight into that document the moment a first-time
  /// Google account is detected, using the role the login screen was already
  /// specific to. There is nothing left to guess.
  ///
  /// The one thing this method does allow for is *timing*: [_knownProfile]
  /// being momentarily unpopulated is not the same as it never arriving.
  /// Rather than declare the role lost on the very first check, this waits —
  /// briefly, listening for the next [SessionService.user] update — before
  /// giving up. That distinction is what separates a real failure (Firestore
  /// genuinely rejecting the read) from an ordinary ordering gap that would
  /// have resolved on its own a moment later, which previously showed the same
  /// "lost track of your role" screen for both.
  void _resolveRole() {
    final role = _knownProfile?.role;
    if (role != null) {
      _role = role;
      return;
    }

    _resolvingRole = true;
    SessionService.instance.user.addListener(_onSessionUserArrived);
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || !_resolvingRole) return;
      SessionService.instance.user.removeListener(_onSessionUserArrived);
      setState(() {
        _resolvingRole = false;
        _roleMissing = true;
      });
    });
  }

  void _onSessionUserArrived() {
    final role = SessionService.instance.user.value?.role;
    if (role == null) return;

    SessionService.instance.user.removeListener(_onSessionUserArrived);
    if (!mounted) return;
    setState(() {
      _role = role;
      _resolvingRole = false;
      // The initial prefill may have run before this arrived — redo it now
      // that a full profile is actually available.
      _prefillFromAccount();
    });
  }

  /// Seeds the form from whatever the account already knows, so a Google user
  /// is not retyping their own name into an empty box.
  void _prefillFromAccount() {
    final profile = _knownProfile;
    final firebaseUser = AuthService.instance.firebaseUser;

    _nameCtrl.text = profile?.name.isNotEmpty == true
        ? profile!.name
        : (firebaseUser?.displayName ?? '');
    _phoneCtrl.text = profile?.phone ?? '';
    _email = profile?.email.isNotEmpty == true
        ? profile!.email
        : (firebaseUser?.email ?? '');
    _photoUrl = profile?.photoUrl ?? firebaseUser?.photoURL;
  }

  @override
  void dispose() {
    SessionService.instance.user.removeListener(_onSessionUserArrived);
    LanguageProvider.instance.removeListener(_onLangChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _studentIdCtrl.dispose();
    _schoolCtrl.dispose();
    _licenseCtrl.dispose();
    _experienceCtrl.dispose();
    _vehicleCtrl.dispose();
    _seatCapacityCtrl.dispose();
    for (final area in _serviceAreas) {
      area.dispose();
    }
    for (final round in _rounds) {
      round.dispose();
    }
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  // ── Draft ─────────────────────────────────────────────────────────────────

  ProfileDraft get _draft => ProfileDraft(
    role: _role ?? UserRole.parent,
    name: _nameCtrl.text,
    email: _email,
    phone: _phoneCtrl.text,
    photoUrl: _photoUrl,
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
    instituteType: _instituteType ?? '',
    school: _schoolCtrl.text,
    pickupLocation: _pickup,
    dropoffLocation: _dropoff,
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

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDocument({required bool isLicense}) async {
    final source = await showImageSourceSheet(context, accentColor: _accent);
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

  Future<void> _submit() async {
    final draft = _draft;
    final gap = ProfileRequirements.firstGapMessage(draft);
    if (gap != null) {
      setState(() => _error = gap);
      return;
    }

    final uid = AuthService.instance.uid;
    if (uid == null) {
      setState(() => _error = 'Your session expired. Please sign in again.');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    // Hold the router still while the batch commits, so the guard does not
    // redirect out from under us the instant profileComplete flips.
    SessionService.instance.provisioning = true;

    try {
      final profile = await OnboardingService.instance.provision(
        uid: uid,
        draft: draft,
      );

      if (!mounted) return;
      SessionService.instance.provisioning = false;
      context.go(AuthService.routeForUserRole(profile.role));
    } on OnboardingException catch (e) {
      SessionService.instance.provisioning = false;
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      SessionService.instance.provisioning = false;
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save your profile. Please try again.';
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.cardBgElevated,
        title: Text(
          'Sign out?',
          style: TextStyle(color: dialogContext.textPrimary),
        ),
        content: Text(
          'Your profile is not finished. You will need to complete it next '
          'time you sign in.',
          style: TextStyle(color: dialogContext.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.instance.signOut();
    if (!mounted) return;
    context.go('/role-select');
  }

  /// Used only from the [_roleMissing] fallback card.
  ///
  /// Signing out first is not optional: the router guard sends a signed-in
  /// user with `needsProfile` straight back to `/complete-profile` no matter
  /// what URL they ask for, so navigating to `/role-select` while still signed
  /// in would just bounce back here immediately. Ending the session is what
  /// lets `/role-select` actually render.
  Future<void> _restartFromRoleSelect() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    context.go('/role-select');
  }

  // ── Theming ───────────────────────────────────────────────────────────────

  Color get _accent => switch (_role) {
    UserRole.driver => AppTheme.driverCyan,
    UserRole.student => AppTheme.studentAmber,
    _ => AppTheme.parentPurple,
  };

  LinearGradient get _gradient => switch (_role) {
    UserRole.driver => AppTheme.driverGradient,
    UserRole.student => AppTheme.studentGradient,
    _ => AppTheme.parentGradient,
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Traps the Android back gesture. Leaving the profile half-written and
    // landing on a dashboard with no data is exactly what this screen exists to
    // prevent, so back offers sign-out instead of dismissal.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && !_resolvingRole) _signOut();
      },
      child: Scaffold(
        body: Container(
          decoration: context.scaffoldBg,
          child: _resolvingRole
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
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
                                _accent.withValues(alpha: 0.35),
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
                        // Otherwise every scroll gesture that starts while a
                        // field is focused has to fight the keyboard's own
                        // resize animation on top of the scroll physics.
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            // Each wrapped in its own `RepaintBoundary`: this
                            // page is one big non-virtualized `Column`, so
                            // without boundaries a blinking cursor in any
                            // field — or the header's own avatar rebuild —
                            // forces Flutter to repaint the *entire* page's
                            // picture every ~500ms it's focused, which is
                            // what made scrolling feel slow. The repeated
                            // form cards (`ChildCard`,
                            // `ServiceAreaCard`, `RoundCard`) each carry the
                            // same boundary internally.
                            RepaintBoundary(child: _buildHeader()),
                            const SizedBox(height: 24),
                            RepaintBoundary(
                              child: _roleMissing
                                  ? _buildRoleMissingCard()
                                  : _buildForm(),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: TextButton(
                                onPressed: _saving ? null : _signOut,
                                child: Text(
                                  'Sign out',
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 13,
                                  ),
                                ),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 18),
          Text(
            _roleMissing
                ? "We lost track of your role"
                : 'Complete your profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _roleMissing
                ? "That shouldn't happen — please choose your role again to "
                      'continue.'
                : 'We just need a few more details before you can continue',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final photo = _photoUrl;
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _gradient,
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.45),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: photo != null && photo.isNotEmpty
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                cacheWidth: 156,
                cacheHeight: 156,
                errorBuilder: (_, _, _) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  // Listens to _nameCtrl directly so the fallback initial stays live as the
  // user types without requiring a setState() — and therefore a rebuild — of
  // the entire screen on every keystroke.
  Widget _avatarFallback() {
    return AnimatedBuilder(
      animation: _nameCtrl,
      builder: (context, _) {
        final name = _nameCtrl.text.trim();
        final initial = name.isEmpty ? '?' : name[0].toUpperCase();
        return Container(
          color: context.cardBgElevated,
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  // ── Fallback: role genuinely unknown ─────────────────────────────────────
  //
  // See the [_roleMissing] field doc for when this renders. It offers a way
  // out rather than a dead end, but it is not a role picker embedded in this
  // screen — it hands the user back to the one real role-selection screen the
  // app has.

  Widget _buildRoleMissingCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 40),
          const SizedBox(height: 12),
          Text(
            "We couldn't tell which account type you signed up for.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Choose role again',
            gradient: _gradient,
            glowColor: _accent,
            onTap: _restartFromRoleSelect,
          ),
        ],
      ),
    );
  }

  // ── The missing fields ────────────────────────────────────────────────────

  Widget _buildForm() {
    return GlassCard(
      // This card *is* the page's scroll content (it can run to a dozen+
      // fields, cards and sections for a driver), so it repaints — and would
      // re-blur — on every scroll frame. The translucent fill/border already
      // reads as "glass" without paying for a live BackdropFilter here.
      enableBlur: false,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Email comes from the identity provider and is the account key, so
          // it is shown for confirmation but never editable here.
          if (_email.isNotEmpty) ...[
            FieldLabel(AppStrings.t('email_address_lbl')),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: context.cardBgElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.inputBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _email,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.lock_outline, size: 16, color: context.textHint),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          FieldLabel(AppStrings.t('phone_lbl'), important: true),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(hintText: AppStrings.t('enter_phone')),
          ),
          const SizedBox(height: 16),

          ..._roleFields(),

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Text('⚠️  ', style: TextStyle(fontSize: 13)),
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
            const SizedBox(height: 16),
          ],

          GradientButton(
            label: 'Finish setup',
            gradient: _gradient,
            glowColor: _accent,
            isLoading: _saving,
            onTap: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  List<Widget> _roleFields() => switch (_role) {
    UserRole.parent => _parentFields(),
    UserRole.student => _studentFields(),
    UserRole.driver => _driverFields(),
    _ => const [],
  };

  List<Widget> _parentFields() => [
    ..._children.asMap().entries.map(
      (e) => ChildCard(
        key: ValueKey(e.value),
        index: e.key,
        data: e.value,
        canRemove: _children.length > 1,
        onRemove: () => setState(() {
          _children[e.key].dispose();
          _children.removeAt(e.key);
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
    const SizedBox(height: 20),
  ];

  List<Widget> _studentFields() => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(AppStrings.t('student_id_lbl'), important: true),
              const SizedBox(height: 8),
              TextField(
                controller: _studentIdCtrl,
                style: TextStyle(color: context.textPrimary, fontSize: 15),
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
              FieldLabel(AppStrings.t('grade_level_lbl'), important: true),
              const SizedBox(height: 8),
              ThemedDropdown(
                hint: AppStrings.t('select_level_hint'),
                value: _instituteType,
                items: kGradeOptions,
                onChanged: (v) => setState(() => _instituteType = v),
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
      controller: _schoolCtrl,
      isCustom: _schoolIsCustom,
      onCustomChanged: (v) => setState(() => _schoolIsCustom = v),
      accentColor: AppTheme.studentAccent,
    ),
    const SizedBox(height: 16),
    const FieldLabel('PICKUP LOCATION', important: true),
    const SizedBox(height: 8),
    MapPointField(
      placeholder: 'Select pickup on map',
      value: _pickup,
      accentColor: AppTheme.studentAmber,
      onPicked: (p) => setState(() => _pickup = p),
    ),
    const SizedBox(height: 12),
    const FieldLabel('DROPOFF LOCATION', important: true),
    const SizedBox(height: 8),
    MapPointField(
      placeholder: 'Select dropoff on map',
      value: _dropoff,
      accentColor: AppTheme.studentAmber,
      onPicked: (p) => setState(() => _dropoff = p),
    ),
    const SizedBox(height: 20),
  ];

  List<Widget> _driverFields() => [
    FieldLabel(AppStrings.t('license_number_lbl'), important: true),
    const SizedBox(height: 8),
    TextField(
      controller: _licenseCtrl,
      style: TextStyle(color: context.textPrimary, fontSize: 15),
      decoration: InputDecoration(hintText: AppStrings.t('enter_license_hint')),
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
            onTap: () => _pickDocument(isLicense: true),
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
            onTap: () => _pickDocument(isLicense: false),
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
              FieldLabel(AppStrings.t('vehicle_number_lbl'), important: true),
              const SizedBox(height: 8),
              TextField(
                controller: _vehicleCtrl,
                style: TextStyle(color: context.textPrimary, fontSize: 15),
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
              FieldLabel(AppStrings.t('vehicle_type_lbl'), important: true),
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
      decoration: InputDecoration(hintText: AppStrings.t('experience_hint')),
    ),
    const SizedBox(height: 24),
    ..._serviceSection(),
    const SizedBox(height: 24),
    ..._roundsSection(),
    const SizedBox(height: 20),
  ];

  /// "Where do you drive?" — the institutions this driver serves, plus how far
  /// they will travel to collect a student.
  List<Widget> _serviceSection() => [
    _sectionHeading(
      'Where do you drive?',
      'Parents find you by their child\'s school, so list every institution you '
          'already run to.',
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
    _addRowButton(
      label: 'Add another destination',
      onTap: () => setState(() => _serviceAreas.add(ServiceAreaFormData())),
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
    // A local widget so dragging the slider only repaints this small subtree
    // instead of rebuilding (and re-blurring) the entire form on every frame.
    _RadiusSlider(
      initialValue: _serviceRadiusKm,
      accentColor: AppTheme.driverCyan,
      // Just keeps the field in sync for `_draft` at submit time — no
      // setState here, so the drag never touches the rest of the form.
      onChanged: (v) => _serviceRadiusKm = v,
    ),
  ];

  /// "Your rounds" — the bookable trips, each with its own seat count.
  List<Widget> _roundsSection() => [
    _sectionHeading(
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
    _addRowButton(
      label: 'Add another round',
      onTap: () => setState(() {
        _rounds.add(
          RoundFormData.fresh(
            ordinal: _rounds.length + 1,
            // Pre-fill from the vehicle capacity: the overwhelmingly common case
            // is every round offering the whole vehicle, and typing the same
            // number repeatedly is how a driver ends up with one round set to 1.
            seats: int.tryParse(_seatCapacityCtrl.text.trim()) ?? 0,
          ),
        );
      }),
    ),
  ];

  Widget _sectionHeading(String title, String subtitle) => Column(
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

  Widget _addRowButton({required String label, required VoidCallback onTap}) =>
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

/// Owns its own drag value so continuous slider updates never rebuild
/// [ProfileCompletionScreen]'s much larger, blur-backed form.
class _RadiusSlider extends StatefulWidget {
  final double initialValue;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _RadiusSlider({
    required this.initialValue,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_RadiusSlider> createState() => _RadiusSliderState();
}

class _RadiusSliderState extends State<_RadiusSlider> {
  late double _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel('HOW FAR WILL YOU TRAVEL? — ${_value.round()} KM'),
        Slider(
          value: _value,
          min: 1,
          max: 30,
          divisions: 29,
          activeColor: widget.accentColor,
          label: '${_value.round()} km',
          onChanged: (v) {
            setState(() => _value = v);
            widget.onChanged(v);
          },
        ),
        Text(
          'Families further than this from your starting point will not see '
          'you. Leave it wide if you are flexible.',
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}
