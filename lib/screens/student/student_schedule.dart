import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StudentSchedule extends StatefulWidget {
  const StudentSchedule({super.key});
  @override
  State<StudentSchedule> createState() => _StudentScheduleState();
}

class _StudentScheduleState extends State<StudentSchedule> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon

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

  List<String> get _days => [
    AppStrings.t('day_mon'),
    AppStrings.t('day_tue'),
    AppStrings.t('day_wed'),
    AppStrings.t('day_thu'),
    AppStrings.t('day_fri'),
    AppStrings.t('day_sat'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t('my_schedule'),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.t('pickup_dropoff_timings'),
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Day selector ──────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _days.length,
              itemBuilder: (ctx, i) {
                final sel = i == _selectedDay;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    width: 52,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: sel ? AppTheme.studentGradient : null,
                      color: sel ? null : context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: sel
                          ? null
                          : Border.all(color: context.cardBgElevated),
                    ),
                    child: Center(
                      child: Text(
                        _days[i],
                        style: TextStyle(
                          color: sel ? Colors.white : context.textSecondary,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Route info card ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              gradient: LinearGradient(
                colors: [
                  AppTheme.studentAmber.withOpacity(0.10),
                  AppTheme.studentOrange.withOpacity(0.04),
                ],
              ),
              borderColor: AppTheme.studentAmber.withOpacity(0.2),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.studentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('🚌', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route A · Bus #42',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppStrings.t('your_stop')}: Pine Road',
                          style: TextStyle(
                            color: AppTheme.studentAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: AppStrings.t('active_status'),
                    color: AppTheme.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Morning schedule ──────────────────────────
          _SectionLabel(label: AppStrings.t('morning_pickup_s')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _TimelineItem(
                    icon: '🏠',
                    title: AppStrings.t('be_at_stop'),
                    subtitle: 'Pine Road bus stop',
                    time: '07:15 AM',
                    color: AppTheme.studentAmber,
                    isFirst: true,
                  ),
                  _TimelineItem(
                    icon: '🚌',
                    title: AppStrings.t('bus_arrives'),
                    subtitle: 'Estimated pickup',
                    time: '07:22 AM',
                    color: AppTheme.info,
                  ),
                  _TimelineItem(
                    icon: '✅',
                    title: AppStrings.t('qr_checkin'),
                    subtitle: 'Scan your QR pass',
                    time: '07:22 AM',
                    color: AppTheme.success,
                  ),
                  _TimelineItem(
                    icon: '🏫',
                    title: AppStrings.t('reach_school'),
                    subtitle: 'Lincoln Elementary',
                    time: '07:35 AM',
                    color: AppTheme.purple,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Afternoon schedule ────────────────────────
          _SectionLabel(label: AppStrings.t('afternoon_dropoff_s')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _TimelineItem(
                    icon: '🏫',
                    title: AppStrings.t('school_dismissal'),
                    subtitle: 'Board at Gate B',
                    time: '02:30 PM',
                    color: AppTheme.purple,
                    isFirst: true,
                  ),
                  _TimelineItem(
                    icon: '✅',
                    title: AppStrings.t('qr_checkout'),
                    subtitle: 'Scan when boarding',
                    time: '02:35 PM',
                    color: AppTheme.success,
                  ),
                  _TimelineItem(
                    icon: '🚌',
                    title: AppStrings.t('bus_departs'),
                    subtitle: 'Route A return journey',
                    time: '02:40 PM',
                    color: AppTheme.info,
                  ),
                  _TimelineItem(
                    icon: '🏠',
                    title: AppStrings.t('reach_stop'),
                    subtitle: 'Pine Road bus stop',
                    time: '03:05 PM',
                    color: AppTheme.studentAmber,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Weekly summary ────────────────────────────
          _SectionLabel(label: AppStrings.t('this_week_summary')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WeekStat(
                    icon: '🚌',
                    value: '8',
                    label: AppStrings.t('rides_lbl'),
                    color: AppTheme.studentAmber,
                  ),
                  _WeekStat(
                    icon: '⏱️',
                    value: '100%',
                    label: AppStrings.t('on_time'),
                    color: AppTheme.success,
                  ),
                  _WeekStat(
                    icon: '📲',
                    value: '8',
                    label: AppStrings.t('checkins_lbl'),
                    color: AppTheme.info,
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

// ── Helpers ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        label,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String icon, title, subtitle, time;
  final Color color;
  final bool isFirst, isLast;
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 14)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: color.withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
                if (!isLast) const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekStat extends StatelessWidget {
  final String icon, value, label;
  final Color color;
  const _WeekStat({
    required this.icon,
    required this.value,
    required this.label,
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
