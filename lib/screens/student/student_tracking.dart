import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../app/language_provider.dart';

class StudentTracking extends StatefulWidget {
  final VoidCallback onBack;
  const StudentTracking({super.key, required this.onBack});
  @override
  State<StudentTracking> createState() => _StudentTrackingState();
}

class _StudentTrackingState extends State<StudentTracking> {
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          _Header(title: AppStrings.t('track_my_bus'), onBack: widget.onBack),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Map placeholder ─────────────────────────
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.studentAmber.withOpacity(0.08),
                          AppTheme.bgDark.withOpacity(0.4),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🗺️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 8),
                              Text(
                                AppStrings.t('live_map_view'),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                AppStrings.t('gps_tracking_here'),
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status indicators overlay
                        Positioned(
                          top: 12,
                          right: 12,
                          child: StatusBadge(
                            label: '● LIVE',
                            color: AppTheme.success,
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '📍 Pine Road → School',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bus status ──────────────────────────────
                GlassCard(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.success.withOpacity(0.12),
                      AppTheme.success.withOpacity(0.04),
                    ],
                  ),
                  borderColor: AppTheme.success.withOpacity(0.2),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.studentGradient,
                          borderRadius: BorderRadius.circular(16),
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
                            Text(
                              'Bus #42 · Route A',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Driver: Mike Johnson',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: 'On Time', color: AppTheme.success),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── ETA info ────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ETAInfo(
                            icon: '⏱️',
                            label: 'ETA',
                            value: '8 min',
                            color: AppTheme.studentAmber,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          _ETAInfo(
                            icon: '📏',
                            label: AppStrings.t('distance'),
                            value: '2.4 km',
                            color: AppTheme.info,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          _ETAInfo(
                            icon: '🚏',
                            label: AppStrings.t('stops_left'),
                            value: '3',
                            color: AppTheme.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Route progress ──────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('route_progress'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StopItem(
                        name: 'Oak Street',
                        time: '07:10 AM',
                        status: 'passed',
                        color: AppTheme.success,
                      ),
                      _StopItem(
                        name: 'Maple Avenue',
                        time: '07:15 AM',
                        status: 'passed',
                        color: AppTheme.success,
                      ),
                      _StopItem(
                        name: 'Pine Road (Your Stop)',
                        time: '07:22 AM',
                        status: 'current',
                        color: AppTheme.studentAmber,
                      ),
                      _StopItem(
                        name: 'Cedar Lane',
                        time: '07:28 AM',
                        status: 'upcoming',
                        color: Colors.white24,
                      ),
                      _StopItem(
                        name: 'Lincoln Elementary',
                        time: '07:35 AM',
                        status: 'upcoming',
                        color: Colors.white24,
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

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _Header({required this.title, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.cardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.inputBorder),
              ),
              child: Center(
                child: Text(
                  '←',
                  style: TextStyle(color: context.textPrimary, fontSize: 18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ETAInfo extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _ETAInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _StopItem extends StatelessWidget {
  final String name, time, status;
  final Color color;
  const _StopItem({
    required this.name,
    required this.time,
    required this.status,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final isPassed = status == 'passed';
    final isCurrent = status == 'current';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: isCurrent ? 14 : 10,
                height: isCurrent ? 14 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: isCurrent
                      ? Border.all(color: context.textPrimary, width: 2)
                      : null,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              if (status != 'upcoming' || name != 'Lincoln Elementary')
                Container(
                  width: 2,
                  height: 24,
                  color: isPassed
                      ? AppTheme.success.withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : Colors.white.withOpacity(isPassed ? 0.5 : 0.35),
                        fontSize: 13,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withOpacity(isPassed ? 0.35 : 0.25),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
