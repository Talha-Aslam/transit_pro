import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/driver_data_service.dart';
import '../../app/profile_service.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/image_source_sheet.dart';

class DriverProfile extends StatefulWidget {
  final void Function(int) onNavigate;
  final VoidCallback onLogout;

  const DriverProfile({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final _svc = DriverDataService.instance;
  final double _rating = 4.8;

  bool _locationSharing = true;
  bool _parentAlerts = true;
  bool _routeReminders = true;
  bool _breakAlerts = false;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(
      context,
      accentColor: AppTheme.driverCyan,
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      ProfileService.instance.driverImage.value = File(picked.path);
    }
  }

  void _editDriverInfo() {
    final info = _svc.driverInfo.value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        title: AppStrings.t('edit_info'),
        fields: [
          _FieldDef(AppStrings.t('full_name'), info.name),
          _FieldDef(AppStrings.t('email'), info.email),
          _FieldDef(AppStrings.t('mobile_lbl'), info.phone),
          _FieldDef(AppStrings.t('license_no_lbl'), info.license),
          _FieldDef(AppStrings.t('experience_lbl'), info.experience),
          _FieldDef(AppStrings.t('bus_number_lbl'), info.busNumber),
          _FieldDef(AppStrings.t('route_lbl'), info.route),
          _FieldDef(AppStrings.t('total_students_lbl'), info.totalStudents),
        ],
        accentColor: AppTheme.driverCyan,
        onSave: (v) => _svc.updateDriverInfo(
          info.copyWith(
            name: v[0],
            email: v[1],
            phone: v[2],
            license: v[3],
            experience: v[4],
            busNumber: v[5],
            route: v[6],
            totalStudents: v[7],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DriverInfo>(
      valueListenable: _svc.driverInfo,
      builder: (context, info, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              // ── Profile header ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade200.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: AppTheme.driverCyan.withOpacity(0.5),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.driverCyan.withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ValueListenableBuilder<File?>(
                            valueListenable:
                                ProfileService.instance.driverImage,
                            builder: (_, file, __) => file != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(23),
                                    child: Image.file(
                                      file,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      '👨',
                                      style: TextStyle(fontSize: 44),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                gradient: AppTheme.driverGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      info.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      info.email,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Text(
                              '⭐',
                              style: TextStyle(
                                fontSize: 16,
                                color: i < _rating.floor()
                                    ? Colors.white
                                    : context.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_rating',
                          style: const TextStyle(
                            color: AppTheme.warningLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(128 ratings)',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.success.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.t('active_on_route'),
                                style: const TextStyle(
                                  color: AppTheme.successLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _editDriverInfo,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.surfaceBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 12,
                                  color: context.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  AppStrings.t('edit_info'),
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // ── Driver info ─────────────────────────────────
                    GlassCard(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.driverCyan.withOpacity(0.1),
                          AppTheme.driverTeal.withOpacity(0.05),
                        ],
                      ),
                      borderColor: AppTheme.driverCyan.withOpacity(0.2),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('driver_info_section'),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoCard(
                                      icon: '🪪',
                                      label: AppStrings.t('license_no_lbl'),
                                      value: info.license,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _InfoCard(
                                      icon: '📅',
                                      label: AppStrings.t('experience_lbl'),
                                      value: info.experience,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoCard(
                                      icon: '🚌',
                                      label: AppStrings.t('bus_number_lbl'),
                                      value: info.busNumber,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _InfoCard(
                                      icon: '🗺️',
                                      label: AppStrings.t('route_lbl'),
                                      value: info.route,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoCard(
                                      icon: '📞',
                                      label: AppStrings.t('mobile_lbl'),
                                      value: info.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _InfoCard(
                                      icon: '👥',
                                      label: AppStrings.t('total_students_lbl'),
                                      value: info.totalStudents,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Bus info ────────────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('bus_info_section'),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.driverGradient,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🚌',
                                    style: TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'School ${info.busNumber}',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '2022 Ford Transit · Yellow',
                                    style: TextStyle(
                                      color: context.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _BusChip(
                                label: AppStrings.t('capacity_lbl'),
                                value: '28 seats',
                              ),
                              const SizedBox(width: 8),
                              _BusChip(
                                label: AppStrings.t('fuel_lbl'),
                                value: 'CNG',
                              ),
                              const SizedBox(width: 8),
                              _BusChip(
                                label: AppStrings.t('last_service_lbl'),
                                value: 'Feb 10',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Settings toggles ────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('app_settings'),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _PrefRow(
                            label: AppStrings.t('share_location'),
                            desc: AppStrings.t('share_loc_desc'),
                            value: _locationSharing,
                            onChanged: (v) =>
                                setState(() => _locationSharing = v),
                          ),
                          _divider(context),
                          _PrefRow(
                            label: AppStrings.t('parent_alerts_lbl'),
                            desc: AppStrings.t('parent_alerts_desc'),
                            value: _parentAlerts,
                            onChanged: (v) => setState(() => _parentAlerts = v),
                          ),
                          _divider(context),
                          _PrefRow(
                            label: AppStrings.t('route_reminders_lbl'),
                            desc: AppStrings.t('route_reminders_desc'),
                            value: _routeReminders,
                            onChanged: (v) =>
                                setState(() => _routeReminders = v),
                          ),
                          _divider(context),
                          _PrefRow(
                            label: AppStrings.t('break_alerts_lbl'),
                            desc: AppStrings.t('break_alerts_desc'),
                            value: _breakAlerts,
                            onChanged: (v) => setState(() => _breakAlerts = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Menu items ──────────────────────────────────
                    GlassCard(
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: '📋',
                            label: AppStrings.t('trip_history'),
                            desc: '248 trips completed',
                            onTap: () => context.push('/driver/trips'),
                          ),
                          _MenuItem(
                            icon: '🏆',
                            label: AppStrings.t('performance_report'),
                            desc: AppStrings.t('performance_report_desc'),
                            onTap: () => context.push('/driver/performance'),
                          ),
                          _MenuItem(
                            icon: '📜',
                            label: AppStrings.t('documents_license'),
                            desc: AppStrings.t('documents_license_desc'),
                            onTap: () => context.push('/driver/documents'),
                          ),
                          _MenuItem(
                            icon: '🌐',
                            label: AppStrings.t('language'),
                            desc: LanguageProvider.instance.lang,
                            onTap: () => context.push('/driver/language'),
                          ),
                          _MenuItem(
                            icon: '🔐',
                            label: AppStrings.t('change_password'),
                            onTap: () =>
                                context.push('/driver/change-password'),
                          ),
                          _MenuItem(
                            icon: '📞',
                            label: AppStrings.t('emergency_contacts'),
                            onTap: () =>
                                context.push('/driver/emergency-contacts'),
                          ),
                          _MenuItem(
                            icon: '❓',
                            label: AppStrings.t('help_support'),
                            isLast: true,
                            onTap: () => context.push('/driver/help-support'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Theme ────────────────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            context.isDark ? '🌙' : '☀️',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              context.isDark
                                  ? AppStrings.t('dark_mode')
                                  : AppStrings.t('light_mode'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          AppSwitch(
                            value: context.isDark,
                            activeColor: AppTheme.driverCyan,
                            onChanged: (_) => ThemeProvider.instance.toggle(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Logout ──────────────────────────────────────
                    GestureDetector(
                      onTap: widget.onLogout,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.error.withOpacity(0.25),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.t('log_out'),
                            style: const TextStyle(
                              color: AppTheme.errorLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TransportKid v2.4.1 · © 2026',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

Widget _divider(BuildContext context) =>
    Container(height: 1, color: context.cardBg);

class _PrefRow extends StatelessWidget {
  final String label, desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefRow({
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.driverCyan,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon, label, value;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BusChip extends StatelessWidget {
  final String label, value;
  const _BusChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 9),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon, label;
  final String? desc;
  final bool isLast;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.desc,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: context.surfaceBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                  ),
                  if (desc != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc!,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit bottom sheet ────────────────────────────────────────────────────────

class _FieldDef {
  final String label;
  final String initialValue;
  _FieldDef(this.label, this.initialValue);
}

class _EditSheet extends StatefulWidget {
  final String title;
  final List<_FieldDef> fields;
  final Color accentColor;
  final void Function(List<String> values) onSave;

  const _EditSheet({
    required this.title,
    required this.fields,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.fields
        .map((f) => TextEditingController(text: f.initialValue))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_controllers.map((c) => c.text.trim()).toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg = context.isDark ? AppTheme.bgDark : Colors.white;
    final inputFill = context.isDark
        ? AppTheme.bgDarkBlue
        : const Color(0xFFF1F5F9);
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: context.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(widget.fields.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fields[i].label,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _controllers[i],
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: context.inputBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: context.inputBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: widget.accentColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor,
                        widget.accentColor.withOpacity(0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
