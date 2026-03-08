import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StudentDashboard extends StatelessWidget {
  final void Function(int) onNavigate;
  const StudentDashboard({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.studentAmber.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting 👋',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Noorulain',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.cardBgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.inputBorder),
                  ),
                  child: const Center(
                    child: Text('🔔', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.studentAmber.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: ValueListenableBuilder<File?>(
                    valueListenable: ProfileService.instance.studentImage,
                    builder: (_, file, __) => file != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              file,
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child: Text('🎓', style: TextStyle(fontSize: 22)),
                          ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Bus status card ───────────────────────────
                GlassCard(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.success.withOpacity(0.15),
                      AppTheme.success.withOpacity(0.05),
                    ],
                  ),
                  borderColor: AppTheme.success.withOpacity(0.25),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.studentGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.studentAmber.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🚌', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Bus #42 · Route A',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                StatusBadge(
                                  label: '● On Route',
                                  color: AppTheme.success,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Arriving in 8 min · Pine Road Stop',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── ETA Card ──────────────────────────────────
                GestureDetector(
                  onTap: () => onNavigate(1),
                  child: GlassCard(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.studentAmber.withOpacity(0.15),
                        AppTheme.studentOrange.withOpacity(0.08),
                      ],
                    ),
                    borderColor: AppTheme.studentAmber.withOpacity(0.25),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEXT STOP',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (b) => const LinearGradient(
                                      colors: [
                                        Color(0xFFFBBF24),
                                        Color(0xFFF59E0B),
                                      ],
                                    ).createShader(b),
                                    child: Text(
                                      '8 min',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'to school',
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '📍 Currently at Pine Road Stop',
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.studentAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '→',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── QR Pass quick action ──────────────────────
                GestureDetector(
                  onTap: () => onNavigate(3),
                  child: GlassCard(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.purple.withOpacity(0.15),
                        AppTheme.info.withOpacity(0.08),
                      ],
                    ),
                    borderColor: AppTheme.purple.withOpacity(0.25),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppTheme.mainGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text('📱', style: TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My QR Pass',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Show QR for check-in/check-out',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '→',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Today's schedule ──────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's Schedule",
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => onNavigate(2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.studentAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.studentAccent.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                'View All',
                                style: TextStyle(
                                  color: AppTheme.studentAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ScheduleItem(
                        icon: '🌅',
                        label: 'Pickup',
                        time: '07:15 AM',
                        status: 'Done',
                        color: AppTheme.success,
                      ),
                      _ScheduleItem(
                        icon: '🏫',
                        label: 'At School',
                        time: '07:45 AM',
                        status: 'Done',
                        color: AppTheme.success,
                      ),
                      _ScheduleItem(
                        icon: '🌇',
                        label: 'Drop Off',
                        time: '03:30 PM',
                        status: 'Upcoming',
                        color: AppTheme.warning,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Stats grid ────────────────────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _StatCard(
                      icon: '🚌',
                      label: 'Total Rides',
                      value: '142',
                      color: AppTheme.studentAmber,
                    ),
                    _StatCard(
                      icon: '⏱️',
                      label: 'On-Time',
                      value: '96%',
                      color: AppTheme.success,
                    ),
                    _StatCard(
                      icon: '📱',
                      label: 'Check-ins',
                      value: '140',
                      color: AppTheme.info,
                    ),
                    _StatCard(
                      icon: '💰',
                      label: 'Fees Paid',
                      value: '₹3.5K',
                      color: AppTheme.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Recent activity ───────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ActivityRow(
                        icon: '✅',
                        msg: 'Checked in at Oak Street stop',
                        time: '07:18 AM',
                      ),
                      _ActivityRow(
                        icon: '🏫',
                        msg: 'Arrived at school',
                        time: '07:42 AM',
                      ),
                      _ActivityRow(
                        icon: '💰',
                        msg: 'Feb fee paid successfully',
                        time: 'Yesterday',
                      ),
                    ],
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

// ── Widgets ───────────────────────────────────────────────────────────────

class _ScheduleItem extends StatelessWidget {
  final String icon, label, time, status;
  final Color color;
  const _ScheduleItem({
    required this.icon,
    required this.label,
    required this.time,
    required this.status,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(color: context.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            StatusBadge(label: status, color: color),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      gradient: LinearGradient(
        colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
      ),
      borderColor: color.withOpacity(0.2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String icon, msg, time;
  const _ActivityRow({
    required this.icon,
    required this.msg,
    required this.time,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
