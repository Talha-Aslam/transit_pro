import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Profile header ────────────────────────────────────────────
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
                        valueListenable: ProfileService.instance.driverImage,
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
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: AppTheme.driverGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('✏️', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Mike Thompson',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'mike@transport.com',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                // Star rating
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
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Driver info ───────────────────────────────────────────
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
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.7,
                        children: [
                          _InfoCard(
                            icon: '🪪',
                            label: AppStrings.t('license_no_lbl'),
                            value: 'DL-2024-8847',
                          ),
                          _InfoCard(
                            icon: '📅',
                            label: AppStrings.t('experience_lbl'),
                            value: '8 Years',
                          ),
                          _InfoCard(
                            icon: '🚌',
                            label: AppStrings.t('bus_number_lbl'),
                            value: 'Bus #42',
                          ),
                          _InfoCard(
                            icon: '🗺️',
                            label: AppStrings.t('route_lbl'),
                            value: 'Route A – East',
                          ),
                          _InfoCard(
                            icon: '📞',
                            label: AppStrings.t('mobile_lbl'),
                            value: '+1 555-0200',
                          ),
                          _InfoCard(
                            icon: '👥',
                            label: AppStrings.t('total_students_lbl'),
                            value: '22',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bus info ──────────────────────────────────────────────
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
                              child: Text('🚌', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'School Bus #42',
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

                // ── Settings toggles ──────────────────────────────────────
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
                        onChanged: (v) => setState(() => _locationSharing = v),
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
                        onChanged: (v) => setState(() => _routeReminders = v),
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

                // ── Menu items ────────────────────────────────────────────
                GlassCard(
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: '📋',
                        label: AppStrings.t('trip_history'),
                        desc: '248 trips completed',
                      ),
                      _MenuItem(
                        icon: '🏆',
                        label: AppStrings.t('performance_report'),
                        desc: AppStrings.t('performance_report_desc'),
                      ),
                      _MenuItem(
                        icon: '📜',
                        label: AppStrings.t('documents_license'),
                        desc: AppStrings.t('documents_license_desc'),
                      ),
                      _MenuItem(
                        icon: '🔐',
                        label: AppStrings.t('change_password'),
                      ),
                      _MenuItem(
                        icon: '📞',
                        label: AppStrings.t('emergency_contacts'),
                      ),
                      _MenuItem(
                        icon: '❓',
                        label: AppStrings.t('help_support'),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Theme ────────────────────────────────────
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

                // ── Logout ────────────────────────────────────────────────
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
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
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
  const _MenuItem({
    required this.icon,
    required this.label,
    this.desc,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc!,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '›',
            style: TextStyle(color: context.textTertiary, fontSize: 20),
          ),
        ],
      ),
    );
  }
}
