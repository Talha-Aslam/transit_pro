import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';
import '../../app/child_status_service.dart';
import '../../app/round_display.dart';
import '../../app/live_bus_service.dart';
import '../../app/language_provider.dart';
import '../../app/notification_service.dart';
import '../../app/session_service.dart';
import '../../app/weekly_times.dart';
import '../../app/student_data_service.dart';
import '../../data/trip_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/find_driver_banner.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/payment_presentation.dart';
import '../../widgets/app_glyph.dart';

class StudentDashboard extends StatefulWidget {
  final void Function(int) onNavigate;
  const StudentDashboard({super.key, required this.onNavigate});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  /// The assigned driver's running trip. Null means no round under way.
  Trip? _activeTrip;
  StreamSubscription<Trip?>? _tripSub;
  String? _watchedDriverId;

  /// Subscribes to the assigned driver's active trip and, while one is
  /// running, follows the bus it is on. Called from `build`, so it no-ops
  /// unless the driver actually changed.
  void _ensureWatching(StudentInfo info) {
    final driverId = info.driverId;
    if (driverId == _watchedDriverId) return;
    _watchedDriverId = driverId;

    _tripSub?.cancel();
    _tripSub = null;
    _activeTrip = null;
    LiveBusService.instance.stop();

    final studentId = SessionService.instance.uid;
    if (driverId.isEmpty || studentId == null) return;
    _tripSub = TripRepository.instance
        .watchActiveTripForStudent(driverId, studentId)
        .listen(_onActiveTripChanged);
  }

  void _onActiveTripChanged(Trip? trip) {
    if (!mounted) return;
    setState(() => _activeTrip = trip);
    if (trip == null || trip.busId.isEmpty) {
      LiveBusService.instance.stop();
      return;
    }
    LiveBusService.instance.follow(
      busId: trip.busId,
      trip: trip,
      studentId: SessionService.instance.student.value?.id,
    );
  }

  /// Real check-in/absent history, replacing the two hardcoded "Oak Street
  /// stop" / "Arrived at school" rows this screen used to show
  /// unconditionally. Empty until the fetch below completes — a brand-new
  /// account then correctly shows no attendance activity rather than an
  /// invented one.
  List<AttendanceRecord> _attendanceRecords = const [];

  StreamSubscription<List<AttendanceRecord>>? _attendanceSub;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  /// Live, so a ride marked while this screen is open shows up on it.
  void _loadAttendance() {
    final studentId = SessionService.instance.student.value?.id;
    if (studentId == null || studentId.isEmpty) return;
    _attendanceSub = TripRepository.instance
        .watchAttendanceHistory(studentId)
        .listen(
          (records) {
            if (mounted) setState(() => _attendanceRecords = records);
          },
          onError: (Object e) =>
              debugPrint('dashboard attendance load failed: $e'),
        );
  }

  /// What the minutes on the Next Stop card count down to: this student's
  /// pickup while the van is still coming for them, then the institute; home
  /// on the way back. Read off the running trip — it always said "to school".
  String _etaDestinationLabel() {
    final trip = _activeTrip;
    if (trip == null || trip.type == TripType.morning) {
      final me = SessionService.instance.uid ?? '';
      final mine = trip?.stopFor(me);
      return mine != null && mine.isOpen
          ? AppStrings.t('to_pickup')
          : AppStrings.t('to_school');
    }
    return AppStrings.t('to_home');
  }

  /// The badge on a Today's Schedule row, from what actually happened.
  (String, Color)? _legBadge(TodayLeg leg) => switch (leg) {
    TodayLeg.upcoming => (AppStrings.t('upcoming'), AppTheme.info),
    TodayLeg.onTheWay => (AppStrings.t('leg_on_the_way'), AppTheme.warning),
    TodayLeg.done => (AppStrings.t('done'), AppTheme.success),
    TodayLeg.absent => (AppStrings.t('absent'), AppTheme.error),
    TodayLeg.unrecorded => null,
  };

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
            msg: switch (r.status) {
              AttendanceStatus.absent => AppStrings.t('marked_absent'),
              // Delivered at the other end of the ride: school in the
              // morning, home in the afternoon.
              AttendanceStatus.droppedOff => AppStrings.t('status_reached'),
              _ => AppStrings.t('checked_in_pickup'),
            },
            time: _formatTime(r.markedAt),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _tripSub?.cancel();
    LiveBusService.instance.stopAfterFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureWatching(StudentDataService.instance.studentInfo.value);

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
            // Same photographic banner the other dashboards open on —
            // see `DashboardHeader`. Replaces an amber-to-transparent wash
            // that only existed to give the greeting something to sit on.
            DashboardHeader(
              greeting: greeting,
              body: ValueListenableBuilder<StudentInfo>(
                valueListenable: StudentDataService.instance.studentInfo,
                builder: (_, info, _) => Text(
                  info.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              trailing: ValueListenableBuilder<List<AppNotification>>(
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
                            child: Text('🔔', style: TextStyle(fontSize: 18)),
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
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // ── Bus status card ───────────────────────────
                  GlassCard(
                    accent: AppTheme.success,
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
                                              ? AppStrings.t('no_bus_assigned')
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
                                  // Whether a round is running is a fact
                                  // about the driver's trip in Firestore.
                                  // Read from the local `TrackingService`
                                  // until now, which on a student's device
                                  // is never started, so this badge said
                                  // "Not on route" straight through a live
                                  // trip.
                                  _activeTrip == null
                                      ? StatusBadge(
                                          label: AppStrings.t('not_on_route'),
                                          color: AppTheme.warning,
                                        )
                                      : StatusBadge(
                                          label:
                                              '● ${AppStrings.t('on_route')}',
                                          color: AppTheme.success,
                                        ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Read `TrackingService.etaMinutes` and
                              // `.route` until now — both local to whichever
                              // device owns them, and on a student's phone
                              // `route` is always null, so this line said
                              // "Route not started yet" straight through a
                              // running trip. It follows the bus's own pings
                              // now; see `LiveBusService`.
                              ValueListenableBuilder<int?>(
                                valueListenable:
                                    LiveBusService.instance.etaMinutes,
                                builder: (_, eta, _) {
                                  // The minutes count to the student's own
                                  // stop only while it is still ahead; after
                                  // that, to the end of the leg.
                                  final mine = _activeTrip?.stopFor(
                                    SessionService.instance.uid ?? '',
                                  );
                                  final stopLabel = mine != null && mine.isOpen
                                      ? StudentDataService
                                            .instance
                                            .studentInfo
                                            .value
                                            .stop
                                      : _etaDestinationLabel();
                                  final String line;
                                  if (_activeTrip == null) {
                                    line = AppStrings.t('route_not_started');
                                  } else if (eta == null) {
                                    line = AppStrings.t('waiting_for_bus');
                                  } else {
                                    line =
                                        '${AppStrings.t('arriving_in')} '
                                        '$eta ${AppStrings.t('min_short')}'
                                        '${stopLabel.isEmpty ? '' : ' · $stopLabel'}';
                                  }
                                  return Text(
                                    line,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                      accent: AppTheme.studentAmber,
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
                                ValueListenableBuilder<int?>(
                                  valueListenable:
                                      LiveBusService.instance.etaMinutes,
                                  // Same source as the line in the header,
                                  // so the two can never disagree.
                                  builder: (_, eta, _) {
                                    if (_activeTrip == null || eta == null) {
                                      return Text(
                                        _activeTrip == null
                                            ? AppStrings.t('not_started_yet')
                                            : AppStrings.t(
                                                'waiting_for_bus_short',
                                              ),
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
                                          _etaDestinationLabel(),
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
                                    if (_activeTrip == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final stopLabel = StudentDataService
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
                      accent: AppTheme.error,
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
                        // Rebuilt as the driver marks attendance and trips
                        // start or finish, so the badges move on their own.
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            StudentDataService.instance.studentInfo,
                            ChildStatusService.instance,
                            SessionService.instance,
                          ]),
                          builder: (_, _) {
                            final info =
                                StudentDataService.instance.studentInfo.value;
                            final me = SessionService.instance.student.value;
                            final driver = SessionService.instance.driverFor(
                              info.driverId,
                            );
                            // The student's own round — what the driver
                            // actually runs — and the driver's older
                            // per-driver timings only when there is none.
                            // Ride badges only once a driver carries them.
                            final linked = driver != null;
                            // The student's own day — when their institute
                            // starts and lets out — as set in their weekly
                            // schedule, not the van's pickup times.
                            final today = me == null
                                ? const WeeklyTimes()
                                : WeeklyTimes.on(me);
                            // When the van is expected at this student,
                            // from the round's start and the order of its
                            // stops; their own school hours sit underneath.
                            final expected = me == null
                                ? null
                                : driver?.expectedTimes[me.id];
                            final pickupTime = clock12(expected?.pickup ?? '');
                            final dropoffTime = clock12(
                              expected?.dropoff ?? '',
                            );
                            final schoolHours =
                                today.schoolStartAt.isEmpty &&
                                    today.schoolEndAt.isEmpty
                                ? ''
                                : 'School ${clock12(today.schoolStartAt).isEmpty ? '—' : clock12(today.schoolStartAt)}'
                                      ' – ${clock12(today.schoolEndAt).isEmpty ? '—' : clock12(today.schoolEndAt)}';
                            final morning = me == null || !linked
                                ? null
                                : _legBadge(
                                    ChildStatusService.instance.legToday(
                                      me.id,
                                      morning: true,
                                    ),
                                  );
                            final home = me == null || !linked
                                ? null
                                : _legBadge(
                                    ChildStatusService.instance.legToday(
                                      me.id,
                                      morning: false,
                                    ),
                                  );
                            return Column(
                              children: [
                                _ScheduleItem(
                                  icon: '🌅',
                                  label: AppStrings.t('expected_pickup'),
                                  time: pickupTime.isEmpty ? '—' : pickupTime,
                                  status: morning?.$1,
                                  color: morning?.$2 ?? AppTheme.warning,
                                ),
                                _ScheduleItem(
                                  icon: '🌇',
                                  label: AppStrings.t('expected_dropoff'),
                                  time: dropoffTime.isEmpty ? '—' : dropoffTime,
                                  status: home?.$1,
                                  color: home?.$2 ?? AppTheme.warning,
                                ),
                                if (schoolHours.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      schoolHours,
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
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
                          label: AppStrings.t('fees_paid'),
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
                              AppStrings.t('recent_activity'),
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
                                AppStrings.t('no_recent_activity'),
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
  final String icon, label, time;

  /// Null when there is nothing honest to say about this leg yet.
  final String? status;
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
            AppGlyph(icon, size: 20, color: color),
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
            if (status != null) StatusBadge(label: status!, color: color),
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
      accent: color,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: AppGlyph(icon, size: 18, color: color)),
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
            AppGlyph(icon, size: 18),
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
