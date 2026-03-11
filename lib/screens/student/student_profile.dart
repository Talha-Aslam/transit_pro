import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/language_provider.dart';
import '../../app/profile_service.dart';
import '../../app/student_data_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/image_source_sheet.dart';

class StudentProfile extends StatefulWidget {
  final VoidCallback onLogout;
  const StudentProfile({super.key, required this.onLogout});

  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  final _svc = StudentDataService.instance;

  bool _busAlerts = true;
  bool _arrivalAlerts = true;
  bool _delayAlerts = false;

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
      accentColor: AppTheme.studentAmber,
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      ProfileService.instance.studentImage.value = File(picked.path);
    }
  }

  void _editStudentInfo() {
    final info = _svc.studentInfo.value;
    _showEditSheet(
      title: AppStrings.t('edit_info'),
      fields: [
        _FieldDef(AppStrings.t('full_name'), info.name),
        _FieldDef('Student ID', info.studentId),
        _FieldDef(AppStrings.t('grade'), info.grade),
        _FieldDef(AppStrings.t('school'), info.school),
        _FieldDef(AppStrings.t('bus_number_lbl'), info.busNumber),
        _FieldDef(AppStrings.t('route_lbl'), info.route),
        _FieldDef(AppStrings.t('bus_stop'), info.stop),
      ],
      onSave: (v) => _svc.updateStudentInfo(
        info.copyWith(
          name: v[0],
          studentId: v[1],
          grade: v[2],
          school: v[3],
          busNumber: v[4],
          route: v[5],
          stop: v[6],
        ),
      ),
    );
  }

  void _editGuardianInfo() {
    final g = _svc.guardianInfo.value;
    _showEditSheet(
      title: AppStrings.t('parent_guardian_lbl'),
      fields: [
        _FieldDef(AppStrings.t('full_name'), g.name),
        _FieldDef(AppStrings.t('phone'), g.phone),
        _FieldDef(AppStrings.t('email'), g.email),
      ],
      onSave: (v) => _svc.updateGuardianInfo(
        g.copyWith(name: v[0], phone: v[1], email: v[2]),
      ),
    );
  }

  void _showEditSheet({
    required String title,
    required List<_FieldDef> fields,
    required void Function(List<String>) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        title: title,
        fields: fields,
        accentColor: AppTheme.studentAmber,
        onSave: onSave,
      ),
    );
  }

  void _showNotifSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifSheet(
        busAlerts: _busAlerts,
        arrivalAlerts: _arrivalAlerts,
        delayAlerts: _delayAlerts,
        onChanged: (bus, arr, del) => setState(() {
          _busAlerts = bus;
          _arrivalAlerts = arr;
          _delayAlerts = del;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StudentInfo>(
      valueListenable: _svc.studentInfo,
      builder: (context, student, _) {
        return ValueListenableBuilder<GuardianInfo>(
          valueListenable: _svc.guardianInfo,
          builder: (context, guardian, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // ── Avatar & info header ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.studentAmber.withOpacity(0.18),
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
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: AppTheme.studentGradient,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.studentAmber.withOpacity(
                                      0.3,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ValueListenableBuilder<File?>(
                                valueListenable:
                                    ProfileService.instance.studentImage,
                                builder: (_, file, __) => file != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: Image.file(
                                          file,
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Center(
                                        child: Text(
                                          '🎓',
                                          style: TextStyle(fontSize: 42),
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
                                    gradient: AppTheme.studentGradient,
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
                          student.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${student.studentId} · ${student.grade}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.studentAmber.withOpacity(0.2),
                                    AppTheme.studentOrange.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.studentAmber.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '🎒 ${student.school}',
                                style: const TextStyle(
                                  color: AppTheme.studentAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _editStudentInfo,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: context.surfaceBorder,
                                  ),
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

                  // ── Quick stats ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _QuickStat(
                            icon: '🚌',
                            value: student.busNumber,
                            label: AppStrings.t('bus_lbl'),
                            color: AppTheme.studentAmber,
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: context.cardBgElevated,
                          ),
                          _QuickStat(
                            icon: '📅',
                            value: '180',
                            label: AppStrings.t('rides_lbl'),
                            color: AppTheme.info,
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: context.cardBgElevated,
                          ),
                          _QuickStat(
                            icon: '⏱️',
                            value: '98%',
                            label: AppStrings.t('on_time'),
                            color: AppTheme.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Transport details ──────────────────────────────────
                  _SectionHeader(AppStrings.t('transport_details')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: '🚌',
                            label: AppStrings.t('bus_lbl'),
                            value: student.busNumber,
                          ),
                          _DetailRow(
                            icon: '📍',
                            label: AppStrings.t('route_lbl'),
                            value: student.route,
                          ),
                          _DetailRow(
                            icon: '🚏',
                            label: AppStrings.t('stop_lbl'),
                            value: student.stop,
                          ),
                          _DetailRow(
                            icon: '👨‍✈️',
                            label: AppStrings.t('driver_lbl'),
                            value: student.driverName,
                          ),
                          _DetailRow(
                            icon: '📞',
                            label: AppStrings.t('driver_phone_lbl'),
                            value: student.driverPhone,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Parent / Guardian ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.t('parent_guardian_lbl'),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _editGuardianInfo,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(12),
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
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.t('edit_info'),
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: '👤',
                            label: AppStrings.t('name_lbl'),
                            value: guardian.name,
                          ),
                          _DetailRow(
                            icon: '📞',
                            label: AppStrings.t('phone'),
                            value: guardian.phone,
                          ),
                          _DetailRow(
                            icon: '✉️',
                            label: AppStrings.t('email'),
                            value: guardian.email,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Settings ───────────────────────────────────────────
                  _SectionHeader(AppStrings.t('settings_lbl')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          _SettingTile(
                            icon: '🔔',
                            label: AppStrings.t('notifications_lbl'),
                            onTap: _showNotifSettings,
                          ),
                          _SettingTile(
                            icon: '🌐',
                            label: AppStrings.t('language'),
                            desc: LanguageProvider.instance.lang,
                            onTap: () => context.push('/student/language'),
                          ),
                          _SettingTile(
                            icon: '🔐',
                            label: AppStrings.t('change_password'),
                            onTap: () =>
                                context.push('/student/change-password'),
                          ),
                          _SettingTile(
                            icon: '📞',
                            label: AppStrings.t('emergency_contacts'),
                            onTap: () =>
                                context.push('/student/emergency-contacts'),
                          ),
                          _SettingTile(
                            icon: '❓',
                            label: AppStrings.t('help_support'),
                            onTap: () => context.push('/student/help-support'),
                          ),
                          _SettingTile(
                            icon: '📋',
                            label: AppStrings.t('terms_lbl'),
                            isLast: true,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Terms & Conditions · TransportKid v2.4.1',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppTheme.studentAmber,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Theme ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
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
                            activeColor: AppTheme.studentAmber,
                            onChanged: (_) => ThemeProvider.instance.toggle(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Logout ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
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
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TransportKid v2.4.1 · © 2026',
                    style: TextStyle(color: context.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String icon, value, label;
  final Color color;
  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 10),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String icon, label, value;
  final bool isLast;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Container(height: 1, color: context.cardBgElevated),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String icon, label;
  final String? desc;
  final bool isLast;
  final VoidCallback? onTap;
  const _SettingTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: context.surfaceBorder, width: 0.5),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(10),
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
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (desc != null)
                    Text(
                      desc!,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
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

// ─── Notification settings bottom sheet ──────────────────────────────────────

class _NotifSheet extends StatefulWidget {
  final bool busAlerts, arrivalAlerts, delayAlerts;
  final void Function(bool bus, bool arr, bool del) onChanged;

  const _NotifSheet({
    required this.busAlerts,
    required this.arrivalAlerts,
    required this.delayAlerts,
    required this.onChanged,
  });

  @override
  State<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends State<_NotifSheet> {
  late bool _bus, _arr, _del;

  @override
  void initState() {
    super.initState();
    _bus = widget.busAlerts;
    _arr = widget.arrivalAlerts;
    _del = widget.delayAlerts;
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? AppTheme.bgDark : Colors.white;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.t('notifications_lbl'),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _toggle(context, '🚌 Bus Departure Alerts', _bus, (v) {
            setState(() => _bus = v);
            widget.onChanged(_bus, _arr, _del);
          }),
          _toggle(context, '🏫 School Arrival Alerts', _arr, (v) {
            setState(() => _arr = v);
            widget.onChanged(_bus, _arr, _del);
          }),
          _toggle(context, '⚠️ Delay Notifications', _del, (v) {
            setState(() => _del = v);
            widget.onChanged(_bus, _arr, _del);
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _toggle(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
            ),
          ),
          AppSwitch(
            value: value,
            activeColor: AppTheme.studentAmber,
            onChanged: onChanged,
          ),
        ],
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
    for (final c in _controllers) {
      c.dispose();
    }
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
