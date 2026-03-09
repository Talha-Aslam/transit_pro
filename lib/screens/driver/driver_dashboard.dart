import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/profile_service.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverDashboard extends StatefulWidget {
  final void Function(int) onNavigate;
  const DriverDashboard({super.key, required this.onNavigate});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _routeStarted = true;

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
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.driverCyan.withOpacity(0.2),
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
                        '$greeting 🚌',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mike Thompson',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Bus #42 · Route A – East District',
                        style: TextStyle(
                          color: AppTheme.driverAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onNavigate(3),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.inputBorder),
                        ),
                        child: const Center(
                          child: Text('💬', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '2',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.driverCyan.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: ValueListenableBuilder<File?>(
                    valueListenable: ProfileService.instance.driverImage,
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
                            child: Text('👨', style: TextStyle(fontSize: 24)),
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
                // ── Route status ─────────────────────────────────────────
                GlassCard(
                  gradient: LinearGradient(
                    colors: _routeStarted
                        ? [
                            AppTheme.success.withOpacity(0.15),
                            AppTheme.success.withOpacity(0.05),
                          ]
                        : [
                            AppTheme.driverCyan.withOpacity(0.15),
                            AppTheme.driverCyan.withOpacity(0.05),
                          ],
                  ),
                  borderColor:
                      (_routeStarted ? AppTheme.success : AppTheme.driverCyan)
                          .withOpacity(0.25),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('todays_route'),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Route A – Morning Run',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (_routeStarted
                                          ? AppTheme.success
                                          : AppTheme.warning)
                                      .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    (_routeStarted
                                            ? AppTheme.success
                                            : AppTheme.warning)
                                        .withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _routeStarted
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _routeStarted
                                      ? AppStrings.t('in_progress_badge')
                                      : AppStrings.t('not_started_badge'),
                                  style: TextStyle(
                                    color: _routeStarted
                                        ? AppTheme.successLight
                                        : AppTheme.warningLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress bar
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppStrings.t('route_progress'),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                '55%',
                                style: TextStyle(
                                  color: AppTheme.successLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 0.55,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation(
                                AppTheme.success,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _RouteStatChip(
                            icon: '📍',
                            label: AppStrings.t('stops_done'),
                            value: '3/5',
                          ),
                          const SizedBox(width: 8),
                          _RouteStatChip(
                            icon: '👦',
                            label: AppStrings.t('students'),
                            value: '18/22',
                          ),
                          const SizedBox(width: 8),
                          _RouteStatChip(
                            icon: '⏱️',
                            label: AppStrings.t('time_left'),
                            value: '15 min',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Next stop card ────────────────────────────────────────
                GlassCard(
                  onTap: () => widget.onNavigate(2),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.driverCyan.withOpacity(0.15),
                      AppTheme.driverTeal.withOpacity(0.08),
                    ],
                  ),
                  borderColor: AppTheme.driverCyan.withOpacity(0.25),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.driverGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.driverCyan.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('📍', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('next_stop'),
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cedar Blvd',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '⏱️ ~3 minutes away · 07:37 AM scheduled',
                              style: TextStyle(
                                color: AppTheme.driverAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.driverCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '→',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Quick actions ─────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('quick_actions'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.0,
                        children: [
                          _QuickActionBtn(
                            icon: '🚨',
                            label: AppStrings.t('emergency'),
                            color: AppTheme.error,
                          ),
                          _QuickActionBtn(
                            icon: '📢',
                            label: AppStrings.t('alert_all'),
                            color: AppTheme.warning,
                          ),
                          _QuickActionBtn(
                            icon: '📍',
                            label: AppStrings.t('share_location'),
                            color: AppTheme.success,
                          ),
                          _QuickActionBtn(
                            icon: '🔄',
                            label: AppStrings.t('update_route'),
                            color: AppTheme.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Today's stats ─────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('todays_stats'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StatBar(
                        label: AppStrings.t('students_picked'),
                        value: 18,
                        total: 22,
                        color: AppTheme.success,
                        suffix: null,
                      ),
                      const SizedBox(height: 12),
                      _StatBar(
                        label: AppStrings.t('route_completion'),
                        value: 55,
                        total: 100,
                        color: AppTheme.driverAccent,
                        suffix: '%',
                      ),
                      const SizedBox(height: 12),
                      _StatBar(
                        label: AppStrings.t('on_time_perf'),
                        value: 96,
                        total: 100,
                        color: AppTheme.parentAccent,
                        suffix: '%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Start/End route button ─────────────────────────────────
                GestureDetector(
                  onTap: () => setState(() => _routeStarted = !_routeStarted),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _routeStarted
                            ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                            : [
                                const Color(0xFF10B981),
                                const Color(0xFF059669),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_routeStarted
                                      ? AppTheme.error
                                      : AppTheme.success)
                                  .withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _routeStarted
                            ? "🛑  ${AppStrings.t('end_route')}"
                            : "▶️  ${AppStrings.t('start_route')}",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

class _RouteStatChip extends StatelessWidget {
  final String icon, label, value;
  const _RouteStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String icon, label;
  final Color color;
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color;
  final String? suffix;
  const _StatBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value / total;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
              ),
            ),
            Text(
              suffix != null ? '$value$suffix' : '$value/$total',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: context.cardBgElevated,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
