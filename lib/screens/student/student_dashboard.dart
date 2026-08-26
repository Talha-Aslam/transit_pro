import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';
import '../../app/driver_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/notification_service.dart';
import '../../app/session_service.dart';
import '../../app/student_data_service.dart';
import '../../app/tracking_service.dart';
import '../../data/trip_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/find_driver_banner.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/payment_presentation.dart';

class StudentDashboard extends StatefulWidget {
  final void Function(int) onNavigate;
  const StudentDashboard({super.key, required this.onNavigate});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  /// Real check-in/absent history, replacing the two hardcoded "Oak Street
  /// stop" / "Arrived at school" rows this screen used to show
  /// unconditionally. Empty until the fetch below completes — a brand-new
  /// account then correctly shows no attendance activity rather than an
  /// invented one.
  List<AttendanceRecord> _attendanceRecords = const [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final studentId = SessionService.instance.student.value?.id;
    if (studentId == null || studentId.isEmpty) return;
    try {
      final records = await TripRepository.instance.fetchAttendanceForStudent(
        studentId,
      );
      if (!mounted) return;
      setState(() => _attendanceRecords = records);
    } catch (e) {
      debugPrint('dashboard attendance load failed: $e');
    }
  }

  bool _isPast(TimeOfDay t) {
    final now = TimeOfDay.now();
    return (now.hour * 60 + now.minute) >= (t.hour * 60 + t.minute);
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  /// The most recent boarded/absent verdicts, newest first — mirrors
  /// `student_attendance.dart`'s honest simplification: the backend records
  /// one verdict per trip, not separate pickup/school-arrival scans.
  List<Widget> _attendanceActivityRows() {
    final marked = _attendanceRecords.where((r) => r.markedAt != null).toList()
      ..sort((a, b) => b.markedAt!.compareTo(a.markedAt!));
    return marked
        .take(2)
        .map(
          (r) => _ActivityRow(
            icon: r.status == AttendanceStatus.absent ? '❌' : '✅',
            msg: r.status == AttendanceStatus.absent
                ? 'Marked absent'
                : 'Checked in for pickup',
            time: _formatTime(r.markedAt),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? AppStrings.t('good_morning')
        : hour < 17
        ? AppStrings.t('good_afternoon')
        : AppStrings.t('good_evening');

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) => SingleChildScrollView(
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
                    AppTheme.studentAmber.withValues(alpha: 0.2),
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
                        Row(
                          children: [
                            const Text('👋', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppTheme.studentGradient.createShader(
                                    Rect.fromLTWH(
                                      0,
                                      0,
                                      bounds.width,
                                      bounds.height,
                                    ),
                                  ),
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                greeting,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<StudentInfo>(
                          valueListenable:
                              StudentDataService.instance.studentInfo,
                          builder: (_, info, _) => Text(
                            info.name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<List<AppNotification>>(
                    valueListenable: NotificationService.instance.history,
                    builder: (context, history, _) {
                      final unread = history.where((n) => !n.read).length;
                      return GestureDetector(
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
                                child: Text(
                                  '🔔',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            if (unread > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: context.cardBgElevated,
                                      width: 1.4,
                                    ),
                                  ),
                                  child: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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
                        AppTheme.success.withValues(alpha: 0.15),
                        AppTheme.success.withValues(alpha: 0.05),
                      ],
                    ),
                    borderColor: AppTheme.success.withValues(alpha: 0.25),
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
                                color: AppTheme.studentAmber.withValues(
                                  alpha: 0.3,
                                ),
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
                                  Expanded(
                                    child: ValueListenableBuilder<StudentInfo>(
                                      valueListenable: StudentDataService
                                          .instance
                                          .studentInfo,
                                      builder: (_, info, _) {
                                        final assignment =
                                            [info.busNumber, info.route]
                                                .where((s) => s.isNotEmpty)
                                                .join(' · ');
                                        return Text(
                                          assignment.isEmpty
                                              ? 'No bus assigned yet'
                                              : assignment,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // `route` is null until a driver actually
                                  // starts a trip — this used to show
                                  // "On Route" unconditionally, even for a
                                  // brand-new account with no driver at all.
                                  TrackingService.instance.route == null
                                      ? StatusBadge(
                                          label: 'Not on route',
                                          color: AppTheme.warning,
                                        )
                                      : StatusBadge(
                                          label: '● On Route',
                                          color: AppTheme.success,
                                        ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ValueListenableBuilder<int>(
                                valueListenable:
                                    TrackingService.instance.etaMinutes,
                                builder: (_, eta, _) {
                                  final route = TrackingService.instance.route;
                                  // `etaMinutes` keeps whatever value the last
                                  // live trip left it at — without this
                                  // guard, "Arriving in X min" kept showing
                                  // for an account with no bus assigned at
                                  // all, since eta is never reset to a
                                  // not-applicable state on its own.
                                  if (route == null) {
                                    return Text(
                                      'Route not started yet',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 12,
                                      ),
                                    );
                                  }
                                  final stopName = route.currentStop?.name;
                                  final stopLabel =
                                      (stopName != null && stopName.isNotEmpty)
                                      ? stopName
                                      : StudentDataService
                                            .instance
                                            .studentInfo
                                            .value
                                            .stop;
                                  return Text(
                                    'Arriving in $eta min'
                                    '${stopLabel.isEmpty ? '' : ' · $stopLabel'}',
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                    ),
                                  );
                                },
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
                    onTap: () => widget.onNavigate(1),
                    child: GlassCard(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.studentAmber.withValues(alpha: 0.15),
                          AppTheme.studentOrange.withValues(alpha: 0.08),
                        ],
                      ),
                      borderColor: AppTheme.studentAmber.withValues(
                        alpha: 0.25,
                      ),
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
                                ValueListenableBuilder<int>(
                                  valueListenable:
                                      TrackingService.instance.etaMinutes,
                                  // `etaMinutes` holds whatever the last live
                                  // trip left it at — it is never reset just
                                  // because there is no active route, so this
                                  // must be gated the same way as the header
                                  // "Arriving in X min" line above.
                                  builder: (_, eta, _) {
                                    final route =
                                        TrackingService.instance.route;
                                    if (route == null) {
                                      return Text(
                                        'Not started yet',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (b) =>
                                              const LinearGradient(
                                                colors: [
                                                  Color(0xFFFBBF24),
                                                  Color(0xFFF59E0B),
                                                ],
                                              ).createShader(b),
                                          child: Text(
                                            '$eta min',
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppStrings.t('to_school'),
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                Builder(
                                  builder: (_) {
                                    final route =
                                        TrackingService.instance.route;
                                    if (route == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final stopName = route.currentStop?.name;
                                    final stopLabel =
                                        (stopName != null &&
                                            stopName.isNotEmpty)
                                        ? stopName
                                        : StudentDataService
                                              .instance
                                              .studentInfo
                                              .value
                                              .stop;
                                    return Text(
                                      stopLabel.isEmpty
                                          ? ''
                                          : '📍 Currently at $stopLabel',
                                      style: TextStyle(
                                        color: context.textTertiary,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.studentAccent.withValues(
                                alpha: 0.2,
                              ),
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

                  // ── Driver matching ───────────────────────────
                  const FindDriverBanner(
                    accent: AppTheme.studentAmber,
                    searchRoute: '/student/find-drivers',
                  ),

                  // ── Missed Bus quick action ────────────────────
                  GestureDetector(
                    onTap: () => context.push('/student/missed-bus'),
                    child: GlassCard(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.error.withValues(alpha: 0.15),
                          AppTheme.warning.withValues(alpha: 0.08),
                        ],
                      ),
                      borderColor: AppTheme.error.withValues(alpha: 0.25),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.error, Color(0xFFFF6B35)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('🚌', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.t('missed_quick_title'),
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppStrings.t('missed_quick_subtitle'),
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
                              onTap: () => widget.onNavigate(2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.studentAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.studentAccent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  AppStrings.t('view_all'),
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
                        ValueListenableBuilder<StudentInfo>(
                          valueListenable:
                              StudentDataService.instance.studentInfo,
                          builder: (_, info, _) {
                            // `DriverDataService.timingSlots` defaults to a
                            // fixed 7:15/etc. schedule whenever no driver
                            // document has loaded — which is exactly the
                            // case for a brand-new student with no bus
                            // assigned yet. Gate on the same "assigned"
                            // signal the header badge above already uses,
                            // rather than trust that notifier's default.
                            final hasBus =
                                info.busNumber.isNotEmpty ||
                                info.route.isNotEmpty;
                            if (!hasBus) {
                              return Text(
                                "Your driver hasn't set a schedule yet.",
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 13,
                                ),
                              );
                            }
                            return ValueListenableBuilder<DriverTimingSlots>(
                              valueListenable:
                                  DriverDataService.instance.timingSlots,
                              builder: (_, slots, _) => Column(
                                children: [
                                  _ScheduleItem(
                                    icon: '🌅',
                                    label: 'Pickup',
                                    time: formatTimeOfDay(
                                      slots.morningPickupFromHome,
                                    ),
                                    status: _isPast(slots.morningPickupFromHome)
                                        ? 'Done'
                                        : 'Upcoming',
                                    color: _isPast(slots.morningPickupFromHome)
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                  ),
                                  _ScheduleItem(
                                    icon: '🏫',
                                    label: 'At School',
                                    time: formatTimeOfDay(
                                      slots.morningDropoffAtSchool,
                                    ),
                                    status:
                                        _isPast(slots.morningDropoffAtSchool)
                                        ? 'Done'
                                        : 'Upcoming',
                                    color: _isPast(slots.morningDropoffAtSchool)
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                  ),
                                  _ScheduleItem(
                                    icon: '🌇',
                                    label: 'Drop Off',
                                    time: formatTimeOfDay(
                                      slots.afternoonDropoffAtHome,
                                    ),
                                    status:
                                        _isPast(slots.afternoonDropoffAtHome)
                                        ? 'Done'
                                        : 'Upcoming',
                                    color: _isPast(slots.afternoonDropoffAtHome)
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Stats grid ────────────────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: StudentDataService.instance.totalRides,
                        builder: (_, rides, _) => _StatCard(
                          icon: '🚌',
                          label: AppStrings.t('total_rides'),
                          value: '$rides',
                          color: AppTheme.studentAmber,
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: StudentDataService.instance.onTimeRate,
                        builder: (_, rate, _) => _StatCard(
                          icon: '⏱️',
                          label: 'On-Time',
                          value: '$rate%',
                          color: AppTheme.success,
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: StudentDataService.instance.safeRides,
                        builder: (_, safe, _) => _StatCard(
                          icon: '🛡️',
                          label: AppStrings.t('safe_rides'),
                          value: '$safe',
                          color: AppTheme.info,
                        ),
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: StudentDataService.instance.feesPaid,
                        builder: (_, fees, _) => _StatCard(
                          icon: '💰',
                          label: 'Fees Paid',
                          value: fees,
                          color: AppTheme.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Recent activity ───────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Recent Activity',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => widget.onNavigate(3),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.studentAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.studentAccent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  AppStrings.t('view_all'),
                                  style: TextStyle(
                                    color: AppTheme.studentAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // The fee row is real: SessionService.payments is
                        // already a live, populated notifier for this
                        // student — no new fetch needed.
                        ValueListenableBuilder<List<Payment>>(
                          valueListenable: SessionService.instance.payments,
                          builder: (_, payments, _) {
                            final paid =
                                payments
                                    .where(
                                      (p) => p.status == PaymentStatus.paid,
                                    )
                                    .toList()
                                  ..sort(
                                    (a, b) =>
                                        (b.confirmedAt ??
                                                b.paidAt ??
                                                DateTime(0))
                                            .compareTo(
                                              a.confirmedAt ??
                                                  a.paidAt ??
                                                  DateTime(0),
                                            ),
                                  );
                            final rows = _attendanceActivityRows();
                            if (paid.isNotEmpty) {
                              final latest = paid.first;
                              final when = latest.confirmedAt ?? latest.paidAt;
                              rows.add(
                                _ActivityRow(
                                  icon: '💰',
                                  msg:
                                      '${monthLabel(latest.monthKey)} fee paid successfully',
                                  time: when == null ? '' : dayLabel(when),
                                ),
                              );
                            }
                            if (rows.isEmpty) {
                              return Text(
                                'No recent activity yet',
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 13,
                                ),
                              );
                            }
                            return Column(children: rows);
                          },
                        ),
                      ],
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
          color: context.cardBgElevated,
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
      enableBlur: false,
      padding: const EdgeInsets.all(12),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
      ),
      borderColor: color.withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
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
          color: context.cardBgElevated,
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
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
