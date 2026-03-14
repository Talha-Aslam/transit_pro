import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/notification_service.dart';
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

  // ── Quick action handlers ──────────────────────────────────────────────

  void _onEmergency() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EmergencySheet(),
    );
  }

  void _onAlertAll() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AlertAllSheet(),
    );
  }

  void _onShareLocation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareLocationSheet(),
    );
  }

  void _onUpdateRoute() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpdateRouteSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) => SingleChildScrollView(
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
                          '$greeting',
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
                          child: Center(
                            child: Image.asset(
                              'assets/images/notification_bell.gif',
                              width: 22,
                              height: 22,
                              cacheWidth: 44,
                              cacheHeight: 44,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
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
                            Flexible(
                              child: Column(
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                backgroundColor: context.cardBgElevated,
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
                              icon: 'assets/images/utilities/check.png',
                              label: AppStrings.t('stops_done'),
                              value: '3/5',
                            ),
                            const SizedBox(width: 8),
                            _RouteStatChip(
                              icon: 'assets/images/navbar/student.png',
                              label: AppStrings.t('students'),
                              value: '18/22',
                            ),
                            const SizedBox(width: 8),
                            _RouteStatChip(
                              icon: 'assets/images/stats/on_time.png',
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
                          child: Center(
                            child: Image.asset(
                              'assets/images/utilities/next_stop.png',
                              width: 28,
                              height: 28,
                              cacheWidth: 56,
                              cacheHeight: 56,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
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
                                '~3 minutes away · 07:37 AM scheduled',
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
                              icon: 'assets/images/utilities/emergency.png',
                              label: AppStrings.t('emergency'),
                              color: AppTheme.error,
                              onTap: _onEmergency,
                            ),
                            _QuickActionBtn(
                              icon: 'assets/images/alert.png',
                              label: AppStrings.t('alert_all'),
                              color: AppTheme.warning,
                              onTap: _onAlertAll,
                            ),
                            _QuickActionBtn(
                              icon:
                                  'assets/images/navbar/track_transparent.png',
                              label: AppStrings.t('share_location'),
                              color: AppTheme.success,
                              onTap: _onShareLocation,
                            ),
                            _QuickActionBtn(
                              icon: 'assets/images/utilities/edit_pencil.png',
                              label: AppStrings.t('update_route'),
                              color: AppTheme.info,
                              onTap: _onUpdateRoute,
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
                              ? [
                                  const Color(0xFFEF4444),
                                  const Color(0xFFB91C1C),
                                ]
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/route_in_progress.png',
                              width: 22,
                              height: 22,
                              cacheWidth: 44,
                              cacheHeight: 44,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _routeStarted
                                  ? AppStrings.t('end_route')
                                  : AppStrings.t('start_route'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
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
            ),
          ],
        ),
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
            Image.asset(
              icon,
              width: 20,
              height: 20,
              cacheWidth: 40,
              cacheHeight: 40,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
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
  final VoidCallback? onTap;
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Image.asset(
              icon,
              width: 26,
              height: 26,
              cacheWidth: 52,
              cacheHeight: 52,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
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
              style: TextStyle(color: context.textSecondary, fontSize: 13),
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

// ─── Bottom-sheet helper ──────────────────────────────────────────────────────

class _SheetBase extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetBase({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─── Emergency sheet ─────────────────────────────────────────────────────────

class _EmergencySheet extends StatefulWidget {
  @override
  State<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<_EmergencySheet> {
  bool _sent = false;

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '1122');
    if (await canLaunchUrl(uri)) launchUrl(uri);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendSOS() async {
    await NotificationService.instance.show(
      title: '🚨 SOS – Bus #42',
      body:
          'Driver has triggered an emergency alert on Route A. Authorities notified.',
      type: 'alert',
      icon: '🚨',
      color: AppTheme.error,
    );
    if (!mounted) return;
    setState(() => _sent = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '🚨 Emergency',
      child: Column(
        children: [
          if (_sent)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'SOS sent to all parents & dispatchers.',
                style: TextStyle(color: AppTheme.successLight, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          _ActionRow(
            icon: '📞',
            label: 'Call Emergency Services (1122)',
            color: AppTheme.error,
            onTap: _callEmergency,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '📢',
            label: 'Send SOS to All Parents',
            color: AppTheme.warning,
            onTap: _sent ? null : _sendSOS,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '✖',
            label: 'Cancel',
            color: Colors.white24,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ─── Alert All sheet ─────────────────────────────────────────────────────────

class _AlertAllSheet extends StatefulWidget {
  @override
  State<_AlertAllSheet> createState() => _AlertAllSheetState();
}

class _AlertAllSheetState extends State<_AlertAllSheet> {
  int? _selected;

  static const _messages = [
    (
      icon: '⏱️',
      label: 'Running 10 min late',
      body:
          'Bus #42 is running approximately 10 minutes behind schedule today.',
    ),
    (
      icon: '⚠️',
      label: 'Minor breakdown – wait 15 min',
      body:
          'Bus #42 has a minor issue. Expect a 15-minute delay. Stay at your stop.',
    ),
    (
      icon: '✅',
      label: 'Running ahead of schedule',
      body:
          'Bus #42 is running 5 minutes ahead of schedule. Please be at your stop now.',
    ),
    (
      icon: '🌧️',
      label: 'Delayed due to weather',
      body:
          'Bus #42 is delayed due to weather conditions. We will update you shortly.',
    ),
  ];

  Future<void> _send() async {
    if (_selected == null) return;
    final m = _messages[_selected!];
    await NotificationService.instance.show(
      title: '${m.icon} Alert – Bus #42',
      body: m.body,
      type: 'alert',
      icon: m.icon,
      color: AppTheme.warning,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '📢 Alert All Parents',
      child: Column(
        children: [
          ..._messages.asMap().entries.map((e) {
            final selected = _selected == e.key;
            return GestureDetector(
              onTap: () => setState(() => _selected = e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.warning.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppTheme.warning.withOpacity(0.5)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Text(e.value.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value.label,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.warningLight
                              : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.warning,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected != null ? _send : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Send to All Parents',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Share Location sheet ────────────────────────────────────────────────────

class _ShareLocationSheet extends StatefulWidget {
  @override
  State<_ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<_ShareLocationSheet> {
  // Mock current position
  static const _lat = 33.6844;
  static const _lng = 73.0479;
  bool _copied = false;

  Future<void> _openInMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_lat,$_lng',
    );
    if (await canLaunchUrl(uri))
      launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copyCoords() {
    Clipboard.setData(const ClipboardData(text: '$_lat, $_lng'));
    setState(() => _copied = true);
  }

  Future<void> _notifyParents() async {
    await NotificationService.instance.show(
      title: '📍 Bus Location Shared',
      body:
          'Driver is sharing live location. Bus #42 is currently near Cedar Blvd.',
      type: 'info',
      icon: '📍',
      color: AppTheme.success,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '📍 Share Location',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$_lat, $_lng  •  Cedar Blvd',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: _copyCoords,
                  child: Text(
                    _copied ? '✔ Copied' : 'Copy',
                    style: TextStyle(
                      color: _copied
                          ? AppTheme.successLight
                          : AppTheme.driverCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ActionRow(
            icon: '🗺️',
            label: 'Open in Google Maps',
            color: AppTheme.info,
            onTap: _openInMaps,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '📬',
            label: 'Notify All Parents of Current Position',
            color: AppTheme.success,
            onTap: _notifyParents,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '✖',
            label: 'Cancel',
            color: Colors.white24,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ─── Update Route sheet ──────────────────────────────────────────────────────

class _UpdateRouteSheet extends StatefulWidget {
  @override
  State<_UpdateRouteSheet> createState() => _UpdateRouteSheetState();
}

class _UpdateRouteSheetState extends State<_UpdateRouteSheet> {
  int? _selected;

  static const _options = [
    (icon: '✅', label: 'On Time', body: 'Bus #42 is back on schedule.'),
    (
      icon: '⏱️',
      label: 'Delayed – 5 min',
      body: 'Bus #42 is running 5 minutes behind schedule.',
    ),
    (
      icon: '⏱️',
      label: 'Delayed – 10 min',
      body: 'Bus #42 is running 10 minutes behind schedule.',
    ),
    (
      icon: '🔀',
      label: 'Route Deviation',
      body:
          'Bus #42 has taken an alternate route due to road conditions. ETA updated.',
    ),
    (
      icon: '🛑',
      label: 'Route Suspended',
      body:
          'Bus #42 route is temporarily suspended. Please arrange alternative transport.',
    ),
  ];

  Future<void> _apply() async {
    if (_selected == null) return;
    final o = _options[_selected!];
    await NotificationService.instance.show(
      title: '${o.icon} Route Update – Bus #42',
      body: o.body,
      type: _selected == 0 ? 'success' : 'alert',
      icon: o.icon,
      color: _selected == 0 ? AppTheme.success : AppTheme.warning,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '🔄 Update Route Status',
      child: Column(
        children: [
          ..._options.asMap().entries.map((e) {
            final sel = _selected == e.key;
            return GestureDetector(
              onTap: () => setState(() => _selected = e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.info.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? AppTheme.info.withOpacity(0.5)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Text(e.value.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value.label,
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (sel)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.info,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected != null ? _apply : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Notify Parents',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable action row ─────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final String icon, label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: onTap != null ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
