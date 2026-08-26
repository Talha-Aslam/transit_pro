import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../app/student_data_service.dart';
import '../../data/trip_repository.dart';
import '../../map/route_map_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StudentTracking extends StatefulWidget {
  final VoidCallback onBack;
  const StudentTracking({super.key, required this.onBack});
  @override
  State<StudentTracking> createState() => _StudentTrackingState();
}

class _StudentTrackingState extends State<StudentTracking> {
  /// The live `trips/{tripId}` document for this student's driver, or null
  /// when nothing is running. This — not a mock route started unconditionally
  /// in `initState` — is what used to make "Route Progress" and a moving bus
  /// show up on a brand-new account before any driver had ever started
  /// anything.
  Trip? _activeTrip;
  StreamSubscription<Trip?>? _tripSub;
  String? _watchedDriverId;

  /// This student's own row on the active trip's attendance manifest — the
  /// only per-stop detail this account is both allowed to read
  /// (`firestore.rules`'s `ownsStudent` check) and should see; every other
  /// rider's pickup point is another family's information.
  AttendanceRecord? _myAttendance;
  StreamSubscription<AttendanceRecord?>? _attendanceSub;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() => setState(() {});

  /// Called from [build] whenever the student's assigned driver might have
  /// changed. Cheap no-op when it hasn't.
  void _ensureWatching(String? driverId) {
    if (driverId == _watchedDriverId) return;
    _watchedDriverId = driverId;

    _tripSub?.cancel();
    _tripSub = null;
    _attendanceSub?.cancel();
    _attendanceSub = null;
    _activeTrip = null;
    _myAttendance = null;

    if (driverId == null || driverId.isEmpty) return;
    _tripSub = TripRepository.instance
        .watchActiveTripForDriver(driverId)
        .listen(_onActiveTripChanged);
  }

  void _onActiveTripChanged(Trip? trip) {
    if (!mounted) return;
    setState(() => _activeTrip = trip);

    _attendanceSub?.cancel();
    _attendanceSub = null;
    final studentId = SessionService.instance.uid;
    if (trip == null || studentId == null) {
      setState(() => _myAttendance = null);
      return;
    }
    _attendanceSub = TripRepository.instance
        .watchAttendanceForStudent(trip.id, studentId)
        .listen((record) {
      if (!mounted) return;
      setState(() => _myAttendance = record);
    });
  }

  String _relativeStart(DateTime? startedAt) {
    if (startedAt == null) return '—';
    final mins = DateTime.now().difference(startedAt).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '$mins min ago';
    final hours = mins ~/ 60;
    return '$hours hr ago';
  }

  String _attendanceLabel(AttendanceRecord? record) {
    switch (record?.status) {
      case AttendanceStatus.boarded:
        return 'Picked up';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.pending:
      case null:
        return 'Pending';
    }
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _tripSub?.cancel();
    _attendanceSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StudentInfo>(
      valueListenable: StudentDataService.instance.studentInfo,
      builder: (context, studentInfo, _) => _buildBody(context, studentInfo),
    );
  }

  Widget _buildBody(BuildContext context, StudentInfo studentInfo) {
    _ensureWatching(studentInfo.driverId.isEmpty ? null : studentInfo.driverId);
    final trip = _activeTrip;
    final stopLabel = studentInfo.stop.isEmpty ? 'your stop' : studentInfo.stop;
    final schoolLabel = studentInfo.school.isEmpty
        ? 'School'
        : studentInfo.school;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          _Header(title: AppStrings.t('track_my_bus'), onBack: widget.onBack),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Live map ─────────────────────────────────────
                GlassCard(
                  // The map is opaque and fills the card completely, so the
                  // blur layer behind it is never visible — pure wasted GPU
                  // work on what is also this screen's largest, continuously
                  // live-updating element.
                  enableBlur: false,
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        children: [
                          RouteMapView(
                            height: 220,
                            highlightedStopName: studentInfo.stop,
                          ),
                          // Status overlay
                          Positioned(
                            top: 12,
                            right: 12,
                            child: trip == null
                                ? StatusBadge(
                                    label: 'Not started',
                                    color: AppTheme.warning,
                                  )
                                : const StatusBadge(
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
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '📍 $stopLabel → $schoolLabel',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          // Expands to a fullscreen, pannable/zoomable map —
                          // this 220px preview stays gesture-locked so it
                          // doesn't fight the page's own scroll.
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => context.push(
                                '/student/track/map',
                                extra: {
                                  'highlightedStopName': studentInfo.stop,
                                },
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bus status ──────────────────────────────────
                GlassCard(
                  enableBlur: false,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.success.withValues(alpha: 0.12),
                      AppTheme.success.withValues(alpha: 0.04),
                    ],
                  ),
                  borderColor: AppTheme.success.withValues(alpha: 0.2),
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
                            Builder(builder: (_) {
                              final assignment = [
                                studentInfo.busNumber,
                                studentInfo.route,
                              ].where((s) => s.isNotEmpty).join(' · ');
                              return Text(
                                assignment.isEmpty
                                    ? 'No bus assigned yet'
                                    : assignment,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }),
                            const SizedBox(height: 3),
                            Text(
                              'Driver: ${studentInfo.driverName.isEmpty ? "N/A" : studentInfo.driverName}',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: trip == null ? 'Waiting for driver' : 'On Time',
                        color: trip == null ? AppTheme.warning : AppTheme.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (trip == null)
                  GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('🚏', style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 10),
                        Text(
                          "Your driver hasn't started the route yet",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "You'll see live progress here once the route "
                          'begins.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // ── Trip info ────────────────────────────────
                  GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ETAInfo(
                          icon: '⏱️',
                          label: 'Started',
                          value: _relativeStart(trip.startedAt),
                          color: AppTheme.studentAmber,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: context.surfaceBorder,
                        ),
                        _ETAInfo(
                          icon: '🧍',
                          label: 'Your status',
                          value: _attendanceLabel(_myAttendance),
                          color: AppTheme.purple,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Route progress ──────────────────────────────
                  //
                  // Just this student's own leg — every other rider's pickup
                  // point is information this account has no business
                  // seeing (and Firestore's rules agree: a student can only
                  // read their own attendance document).
                  GlassCard(
                    enableBlur: false,
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
                        Builder(builder: (_) {
                          final boarded =
                              _myAttendance?.status == AttendanceStatus.boarded;
                          return Column(
                            children: [
                              _StopItem(
                                name: '$stopLabel (Your Stop)',
                                time: '',
                                status: boarded ? 'passed' : 'current',
                                color: boarded
                                    ? AppTheme.success
                                    : AppTheme.studentAmber,
                              ),
                              _StopItem(
                                name: schoolLabel,
                                time: '',
                                status: boarded ? 'current' : 'upcoming',
                                color: boarded
                                    ? AppTheme.studentAmber
                                    : Colors.white24,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

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
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
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
                            ? context.textPrimary
                            : isPassed
                            ? context.textTertiary
                            : context.textSecondary,
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
                      color: isPassed ? context.textTertiary : context.textHint,
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
