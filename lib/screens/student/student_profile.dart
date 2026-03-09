import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/language_provider.dart';
import '../../app/profile_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Avatar & info ─────────────────────────────
          Column(
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
                          color: AppTheme.studentAmber.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ValueListenableBuilder<File?>(
                      valueListenable: ProfileService.instance.studentImage,
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
                              child: Text('🎓', style: TextStyle(fontSize: 42)),
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
                          child: Text('✏️', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Noorulain',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'STU-2024-042 · Grade 10',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
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
                  '🎒 Lincoln Elementary',
                  style: TextStyle(
                    color: AppTheme.studentAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Quick stats ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickStat(
                    icon: '🚌',
                    value: '42',
                    label: AppStrings.t('route_lbl'),
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

          // ── Transport details ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t('transport_details'),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(
                    icon: '🚌',
                    label: AppStrings.t('bus_lbl'),
                    value: '#42',
                  ),
                  _DetailRow(
                    icon: '📍',
                    label: AppStrings.t('route_lbl'),
                    value: 'Route A',
                  ),
                  _DetailRow(
                    icon: '🚏',
                    label: AppStrings.t('stop_lbl'),
                    value: 'Pine Road',
                  ),
                  _DetailRow(
                    icon: '👨‍✈️',
                    label: AppStrings.t('driver_lbl'),
                    value: 'Mike Johnson',
                  ),
                  _DetailRow(
                    icon: '📞',
                    label: AppStrings.t('driver_phone_lbl'),
                    value: '+91 98765 43210',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Parent / Guardian ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t('parent_guardian_lbl'),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                    value: 'Ahmed Khan',
                  ),
                  _DetailRow(
                    icon: '📞',
                    label: AppStrings.t('phone'),
                    value: '+91 99887 76655',
                  ),
                  _DetailRow(
                    icon: '✉️',
                    label: AppStrings.t('email'),
                    value: 'ahmed@email.com',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Settings ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t('settings_lbl'),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _SettingTile(
                    icon: '🔔',
                    label: AppStrings.t('notifications_lbl'),
                  ),
                  _SettingTile(
                    icon: '🌙',
                    label: AppStrings.t('appearance_lbl'),
                  ),
                  _SettingTile(icon: '🔒', label: AppStrings.t('privacy_lbl')),
                  _SettingTile(icon: '❓', label: AppStrings.t('help_support')),
                  _SettingTile(icon: '📋', label: AppStrings.t('terms_lbl')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Theme ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          // ── Logout ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: widget.onLogout,
              child: GlassCard(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.error.withOpacity(0.12),
                    AppTheme.error.withOpacity(0.04),
                  ],
                ),
                borderColor: AppTheme.error.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🚪', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.t('log_out_text'),
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────────────────

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
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String icon, label;
  const _SettingTile({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '→',
            style: TextStyle(color: context.textTertiary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
