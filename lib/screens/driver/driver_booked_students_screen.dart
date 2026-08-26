import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/ride_match_service.dart';
import '../../app/session_service.dart';
import '../../data/ride_request_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// The driver's roster — everyone who has a seat on one of their rounds.
///
/// ## What "roster" means now
///
/// It used to mean "students an admin assigned to my route", which is still
/// possible but empty in practice: drivers sign themselves up and run their own
/// rounds. The roster that actually has people in it is
/// [SessionService.roster] — `students where driverId == me`, written when this
/// driver accepts a [RideRequest]. [SessionService.routeStudents] is merged in
/// behind it, de-duplicated by student id, so an admin-assigned student is not
/// invisible on the one screen meant to list everybody on board.
///
/// ## Why it is grouped by round
///
/// Seats are per-round, not per-vehicle (see [DriverSchedule]). A driver
/// standing at the kerb at 06:30 needs the six children on the 06:30 pickup,
/// not the eighteen across the whole morning. A flat list would make them count
/// heads against the wrong number.
///
/// Everything here streams from [SessionService], so accepting a request in the
/// inbox or releasing a seat below moves the counts without a refresh.
class DriverBookedStudentsScreen extends StatefulWidget {
  const DriverBookedStudentsScreen({super.key});

  @override
  State<DriverBookedStudentsScreen> createState() =>
      _DriverBookedStudentsScreenState();
}

class _DriverBookedStudentsScreenState
    extends State<DriverBookedStudentsScreen> {
  final _session = SessionService.instance;

  String _search = '';

  /// The student currently being released, so only their row shows a spinner
  /// instead of the whole roster freezing.
  String? _busyStudentId;

  /// Everything the roster is derived from, merged into one listenable.
  ///
  /// The individual notifiers are listened to rather than only
  /// [SessionService] itself, because the roster and route-student streams
  /// publish by assigning their notifier and do not call `notifyListeners` —
  /// a newly accepted student would otherwise not appear until something else
  /// happened to rebuild this tab.
  late final Listenable _live;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _live = Listenable.merge([
      _session,
      _session.state,
      _session.driver,
      _session.bus,
      _session.roster,
      _session.routeStudents,
      _session.rideRequests,
    ]);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  /// The two roster sources, merged and de-duplicated by student id.
  ///
  /// [SessionService.roster] wins on a collision: it is the live driver link,
  /// while the route list is the legacy admin-assigned path.
  List<Student> get _roster {
    final merged = <String, Student>{};
    for (final s in _session.roster.value) {
      merged[s.id] = s;
    }
    for (final s in _session.routeStudents.value) {
      merged.putIfAbsent(s.id, () => s);
    }
    final list = merged.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<Student> _applySearch(List<Student> students) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return students;
    return students
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.displayCode.toLowerCase().contains(q) ||
              s.grade.toLowerCase().contains(q) ||
              s.school.toLowerCase().contains(q),
        )
        .toList();
  }

  /// The accepted request that put [studentId] on this roster, or null.
  ///
  /// Null means the seat did not come from a request — an admin-assigned
  /// student, or a repair case where the request was closed but the student
  /// record still points here. Either way there is no seat for `release` to
  /// give back, so Remove has to be disabled rather than throwing.
  RideRequest? _acceptedRequestFor(String studentId) {
    for (final r in _session.rideRequests.value) {
      if (r.studentId == studentId && r.isAccepted) return r;
    }
    return null;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _confirmRemove(Student student, RideRequest request) async {
    final round = _session.driver.value?.scheduleById(request.scheduleId);
    final confirmed = await _askConfirm(
      title: 'Remove from your roster?',
      body: '${student.name} loses their seat on '
          '${round?.label ?? request.scheduleLabel}, and the seat goes back to '
          'your available count. Their family is told.',
    );
    if (confirmed != true) return;

    setState(() => _busyStudentId = student.id);
    try {
      await RideMatchService.instance.release(request);
      if (!mounted) return;
      _toast('${student.name} removed. Seat is free again.', AppTheme.success);
    } on RideRequestException catch (e) {
      // Expected outcomes of two people using the app at once — already
      // released, request closed, not yours. The message is written for the
      // driver, so it is shown as-is.
      if (!mounted) return;
      _toast(e.message, AppTheme.warning);
    } catch (e) {
      debugPrint('release student ${student.id} failed: $e');
      if (!mounted) return;
      _toast(
        'Could not save that. Check your connection and try again.',
        AppTheme.error,
      );
    } finally {
      if (mounted) setState(() => _busyStudentId = null);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<bool?> _askConfirm({required String title, required String body}) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sheetCtx.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: sheetCtx.inputBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: sheetCtx.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(color: sheetCtx.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sheetCtx.surfaceBorder),
                        ),
                        child: Text(
                          AppStrings.t('cancel'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sheetCtx.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          AppStrings.t('remove'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(Student student, RideRequest? request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PassengerDetailSheet(
        student: student,
        round: _session.driver.value?.scheduleById(student.scheduleId),
        bus: _session.bus.value,
        request: request,
        onRemove: request == null
            ? null
            : (sheetCtx) {
                Navigator.pop(sheetCtx);
                _confirmRemove(student, request);
              },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // A tab body inside DriverLayout's Scaffold — no Scaffold of its own.
    return ListenableBuilder(
      listenable: _live,
      builder: (context, _) {
        final driver = _session.driver.value;
        final roster = _roster;
        final filtered = _applySearch(roster);
        final pendingCount = _session.pendingRideRequests.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('booked_children_title'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppStrings.t('booked_children_subtitle'),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pendingCount > 0) ...[
                      _PendingRequestsPrompt(
                        count: pendingCount,
                        onTap: () => context.push('/driver/ride-requests'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _SummaryPill(
                                label: AppStrings.t('total_students'),
                                value: roster.length,
                                color: AppTheme.driverCyan,
                              ),
                              const SizedBox(width: 10),
                              _SummaryPill(
                                label: AppStrings.t('schedule'),
                                value: driver?.orderedSchedules.length ?? 0,
                                color: AppTheme.success,
                              ),
                            ],
                          ),
                          if (driver != null &&
                              driver.orderedSchedules.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${driver.totalAvailableSeats} of '
                              '${driver.totalSeatsOffered} seats free across '
                              'your rounds',
                              style: TextStyle(
                                color: driver.totalAvailableSeats > 0
                                    ? AppTheme.success
                                    : AppTheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.t('booked_children_title'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.t('booked_children_subtitle'),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.inputBorder),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 14, right: 10),
                            child: Icon(
                              Icons.search_rounded,
                              color: context.textTertiary,
                              size: 18,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _search = v),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: AppStrings.t('search_booked_hint'),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintStyle: TextStyle(color: context.textHint),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._buildBody(context, driver, roster, filtered),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Roster body, or the reason there isn't one.
  List<Widget> _buildBody(
    BuildContext context,
    Driver? driver,
    List<Student> roster,
    List<Student> filtered,
  ) {
    if (roster.isEmpty && _session.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.driverCyan),
          ),
        ),
      ];
    }

    if (roster.isEmpty && _session.hasError) {
      return [
        _NoticeCard(
          emoji: '⚠️',
          color: AppTheme.error,
          title: 'Your roster could not be read',
          body: 'Check your connection and try again. Nothing has been lost — '
              'the list is stored on the server.',
        ),
      ];
    }

    if (roster.isEmpty) {
      return [_EmptyRoster(driver: driver)];
    }

    if (filtered.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                const Text('🚌', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  AppStrings.t('no_booked_found'),
                  style: TextStyle(color: context.textTertiary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final rounds = driver?.orderedSchedules ?? const <DriverSchedule>[];
    final roundIds = rounds.map((r) => r.id).toSet();
    final searching = _search.trim().isNotEmpty;
    final sections = <Widget>[];

    for (final round in rounds) {
      final onRound = filtered.where((s) => s.scheduleId == round.id).toList();
      // While searching, a round with no match is noise. Otherwise every round
      // is shown, empty or not — its seat count is information in itself.
      if (searching && onRound.isEmpty) continue;
      sections.add(
        _RoundSection(
          round: round,
          rows: onRound.map(_buildRow).toList(),
        ),
      );
    }

    // Students on the roster whose round is missing — `scheduleId` never set, or
    // pointing at a round the driver has since deleted or renamed the id of.
    // They are listed, never dropped: a child who is on the vehicle but absent
    // from the driver's screen is a child left standing at the roadside. Showing
    // them here is also the only way the driver learns the round needs fixing.
    final orphans = filtered
        .where(
          (s) => s.scheduleId == null || !roundIds.contains(s.scheduleId),
        )
        .toList();
    if (orphans.isNotEmpty) {
      sections.add(_UnassignedSection(rows: orphans.map(_buildRow).toList()));
    }

    return sections;
  }

  Widget _buildRow(Student student) {
    final request = _acceptedRequestFor(student.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _BookedPassengerCard(
        student: student,
        removable: request != null,
        busy: _busyStudentId == student.id,
        onTap: () => _openDetails(student, request),
        onRemove: request == null
            ? null
            : () => _confirmRemove(student, request),
      ),
    );
  }
}

/// `🎓` for a college or university rider, `🧒` for a school child. Keeps the
/// avatar honest for the university rounds this app also serves.
String _avatarFor(Student student) {
  final type = student.instituteType.toLowerCase();
  if (type.contains('university') || type.contains('college')) return '🎓';
  return '🧒';
}

// ── Pending prompt ──────────────────────────────────────────────────────────

/// Seat requests still waiting on a reply.
///
/// Lives at the top of the roster because this is the screen a driver opens to
/// ask "who is riding with me?", and a family waiting on an answer is the part
/// of that question they can still act on.
class _PendingRequestsPrompt extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingRequestsPrompt({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: AppTheme.warning.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('📬', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count seat request${count == 1 ? '' : 's'} waiting',
                  style: const TextStyle(
                    color: AppTheme.warningLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Tap to answer them.',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.textTertiary),
        ],
      ),
    );
  }
}

// ── Sections ────────────────────────────────────────────────────────────────

/// One round, with its live seat count and the students booked on it.
class _RoundSection extends StatelessWidget {
  final DriverSchedule round;
  final List<Widget> rows;

  const _RoundSection({required this.round, required this.rows});

  @override
  Widget build(BuildContext context) {
    final seatColor = round.hasSpace ? AppTheme.success : AppTheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round.label.isEmpty ? AppStrings.t('schedule') : round.label,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${round.directionLabel} · ${round.timeRange}',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: seatColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: seatColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${round.availableSeats} of ${round.totalSeats} seats free',
                  style: TextStyle(
                    color: seatColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'No one booked on this round yet.',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
          )
        else
          ...rows,
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Roster students whose round cannot be resolved. See the comment at the call
/// site for why they are never hidden.
class _UnassignedSection extends StatelessWidget {
  final List<Widget> rows;

  const _UnassignedSection({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Not assigned to a round',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'On your roster, but no round of yours matches. Fix their '
                      'round so they are not missed at pickup.',
                      style: TextStyle(
                        color: AppTheme.warningLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('⚠️', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        ...rows,
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Student row ─────────────────────────────────────────────────────────────

class _BookedPassengerCard extends StatelessWidget {
  final Student student;

  /// Whether an accepted [RideRequest] backs this seat. Only then is there a
  /// seat for `release` to hand back.
  final bool removable;

  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _BookedPassengerCard({
    required this.student,
    required this.removable,
    required this.busy,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.cardBgElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _avatarFor(student),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name.isEmpty ? 'Unnamed student' : student.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (student.grade.isNotEmpty) student.grade,
                        if (student.school.isNotEmpty) student.school,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    if (!removable) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Not booked through a seat request, so it cannot be '
                        'removed here.',
                        style: TextStyle(
                          color: AppTheme.warningLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.driverCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.driverCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      student.displayCode.isEmpty ? '—' : student.displayCode,
                      style: const TextStyle(
                        color: AppTheme.driverAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppTheme.driverCyan,
                      ),
                    )
                  else
                    Tooltip(
                      message: removable
                          ? AppStrings.t('remove')
                          : 'Only students who booked through a seat request '
                              'can be removed here.',
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_remove_alt_1_rounded,
                              size: 14,
                              color: removable
                                  ? AppTheme.error
                                  : context.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppStrings.t('remove'),
                              style: TextStyle(
                                color: removable
                                    ? AppTheme.error
                                    : context.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail sheet ────────────────────────────────────────────────────────────

/// Everything the driver knows about one rider, from live records only.
///
/// The chat thread and "alert the parent" chips that used to live here were
/// backed by hardcoded messages and a device-local notification that never left
/// the driver's phone, so they have been removed rather than dressed up in real
/// names. Messaging a family is `MessagingRepository`'s job and belongs on a
/// screen that actually does it.
class _PassengerDetailSheet extends StatelessWidget {
  final Student student;
  final DriverSchedule? round;
  final Bus? bus;
  final RideRequest? request;

  /// Null when no accepted request backs this seat, which is also what turns the
  /// Remove button into an explanation.
  final void Function(BuildContext sheetContext)? onRemove;

  const _PassengerDetailSheet({
    required this.student,
    required this.round,
    required this.bus,
    required this.request,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.inputBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.driverCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            _avatarFor(student),
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name.isEmpty
                                  ? 'Unnamed student'
                                  : student.name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (student.grade.isNotEmpty) student.grade,
                                if (student.school.isNotEmpty) student.school,
                              ].join(' · '),
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
                  const SizedBox(height: 16),
                  GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Code',
                          value: student.displayCode.isEmpty
                              ? 'Not set'
                              : student.displayCode,
                        ),
                        _DetailRow(
                          label: AppStrings.t('grade'),
                          value: student.grade.isEmpty
                              ? 'Not given'
                              : student.grade,
                        ),
                        _DetailRow(
                          label: AppStrings.t('school'),
                          value: student.school.isEmpty
                              ? 'Not given'
                              : student.school,
                        ),
                        _DetailRow(
                          label: 'Round',
                          value: round == null
                              ? 'Not assigned to a round'
                              : '${round!.label} · ${round!.directionLabel} '
                                  '${round!.timeRange}',
                        ),
                        if (round != null)
                          _DetailRow(
                            label: 'Seats on this round',
                            value: '${round!.availableSeats} of '
                                '${round!.totalSeats} seats free',
                          ),
                        _DetailRow(
                          label: AppStrings.t('bus_lbl'),
                          value: bus == null
                              ? 'No vehicle assigned'
                              : [
                                  bus!.busNumber,
                                  if (bus!.plateNumber.isNotEmpty)
                                    bus!.plateNumber,
                                ].join(' · '),
                        ),
                        _DetailRow(
                          label: 'Seat status',
                          value: request?.statusLabel ??
                              'Assigned without a seat request',
                        ),
                        if (student.medicalNotes != null &&
                            student.medicalNotes!.trim().isNotEmpty)
                          _DetailRow(
                            label: 'Medical notes',
                            value: student.medicalNotes!.trim(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (onRemove == null)
                    Text(
                      'This student was not booked through a seat request, so '
                      'there is no seat here to give back. Ask your admin to '
                      'change their assignment.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => onRemove!(context),
                        icon: const Icon(
                          Icons.person_remove_alt_1_rounded,
                          size: 18,
                          color: AppTheme.error,
                        ),
                        label: Text(
                          '${AppStrings.t('remove')} — free the seat',
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.cardBgElevated,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(AppStrings.t('close')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Empty & notice states ───────────────────────────────────────────────────

/// Says *why* the roster is empty.
///
/// For a driver with no listed institutions or no rounds, "no students yet" is a
/// lie by omission: no family can even find them, and they would wait forever
/// for a request that cannot be sent. That case points at the setup screen
/// instead.
class _EmptyRoster extends StatelessWidget {
  final Driver? driver;

  const _EmptyRoster({required this.driver});

  @override
  Widget build(BuildContext context) {
    final noAreas = (driver?.serviceAreas ?? const []).isEmpty;
    final noRounds = (driver?.schedules ?? const []).isEmpty;
    final setupGap = noAreas || noRounds;

    if (!setupGap) {
      return _NoticeCard(
        emoji: '🚌',
        color: AppTheme.driverCyan,
        title: 'No students booked yet',
        body: 'Accepted seat requests appear here, grouped by the round they '
            'are on.',
      );
    }

    return _NoticeCard(
      emoji: '🔎',
      color: AppTheme.warning,
      title: 'Families cannot find you yet',
      body: [
        if (noAreas) 'you have not listed any school, college or university',
        if (noRounds) 'you have no rounds set up',
      ].join(', and ').replaceFirstMapped(
            RegExp('^.'),
            (m) => m[0]!.toUpperCase(),
          ),
      actionLabel: 'Set up my service',
      onAction: () => context.push('/driver/service'),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String emoji;
  final Color color;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _NoticeCard({
    required this.emoji,
    required this.color,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderColor: color.withValues(alpha: 0.4),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.driverGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Small shared pieces ─────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
