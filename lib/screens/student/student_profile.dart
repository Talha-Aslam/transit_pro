import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/glass_card.dart';

class StudentProfile extends StatelessWidget {
  final VoidCallback onLogout;
  const StudentProfile({super.key, required this.onLogout});

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
                child: const Center(
                  child: Text('🎓', style: TextStyle(fontSize: 42)),
                ),
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
                    label: 'Route A',
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
                    label: 'Rides',
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
                    label: 'On Time',
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
                'Transport Details',
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
                  _DetailRow(icon: '🚌', label: 'Bus', value: '#42'),
                  _DetailRow(icon: '📍', label: 'Route', value: 'Route A'),
                  _DetailRow(icon: '🚏', label: 'Stop', value: 'Pine Road'),
                  _DetailRow(
                    icon: '👨‍✈️',
                    label: 'Driver',
                    value: 'Mike Johnson',
                  ),
                  _DetailRow(
                    icon: '📞',
                    label: 'Driver Phone',
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
                'Parent / Guardian',
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
                  _DetailRow(icon: '👤', label: 'Name', value: 'Ahmed Khan'),
                  _DetailRow(
                    icon: '📞',
                    label: 'Phone',
                    value: '+91 99887 76655',
                  ),
                  _DetailRow(
                    icon: '✉️',
                    label: 'Email',
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
                'Settings',
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
                  _SettingTile(icon: '🔔', label: 'Notifications'),
                  _SettingTile(icon: '🌙', label: 'Appearance'),
                  _SettingTile(icon: '🔒', label: 'Privacy'),
                  _SettingTile(icon: '❓', label: 'Help & Support'),
                  _SettingTile(icon: '📋', label: 'Terms of Service'),
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
                      context.isDark ? 'Dark Mode' : 'Light Mode',
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
              onTap: onLogout,
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
                    Text('🚪', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Log Out',
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
