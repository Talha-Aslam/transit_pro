import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/ride_match_service.dart';
import '../../app/session_service.dart';
import '../../data/ride_request_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// Driver recommendations for one child, and the place a family asks for a seat.
///
/// The list is driven entirely by the child's own record: matchmaking looks for
/// drivers whose service areas include the child's school, ranks them by
/// proximity to the child's pickup point and by rating, and streams seat counts
/// live so a round that fills while the parent is reading updates in place.
///
/// Works for a self-registering student too — [SessionService] gives a student
/// their own record where a parent gets a child list, and the request is sent
/// with their own uid as the requester.
class FindDriversScreen extends StatefulWidget {
  /// The accent to theme with. Parents and students reach this screen from
  /// differently-coloured shells, and an unthemed screen looks like it belongs to
  /// the other app.
  final Color accent;

  const FindDriversScreen({super.key, this.accent = AppTheme.parentPurple});

  @override
  State<FindDriversScreen> createState() => _FindDriversScreenState();
}

class _FindDriversScreenState extends State<FindDriversScreen> {
  final _session = SessionService.instance;

  /// Which child we are searching for. A parent with several children searches
  /// per child, because school and pickup point differ per child and so does the
  /// answer.
  int _childIndex = 0;

  String? _busyDriverId;

  @override
  void initState() {
    super.initState();
    _childIndex = _session.selectedChildIndex.value;
    _session.children.addListener(_rebuild);
    _session.student.addListener(_rebuild);
    _session.rideRequests.addListener(_rebuild);
  }

  @override
  void dispose() {
    _session.children.removeListener(_rebuild);
    _session.student.removeListener(_rebuild);
    _session.rideRequests.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Every student this account can book a seat for — a parent's children, or a
  /// student's own single record.
  List<Student> get _candidates {
    final own = _session.student.value;
    if (own != null) return [own];
    return _session.children.value;
  }

  Student? get _subject {
    final list = _candidates;
    if (list.isEmpty) return null;
    return list[_childIndex.clamp(0, list.length - 1)];
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _request(DriverMatch match, Student student) async {
    final choice = await _pickRound(match, student);
    if (choice == null) return;

    setState(() => _busyDriverId = match.driver.id);
    try {
      await RideMatchService.instance.requestSeat(
        student: student,
        driver: match.driver,
        schedule: choice.schedule,
        note: choice.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent to ${match.driver.name}. You will be told as soon as '
            'they reply.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } on RideRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.warning),
      );
    } catch (e) {
      debugPrint('requestSeat failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send that request. Check your connection and try again.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyDriverId = null);
    }
  }

  Future<void> _cancel(RideRequest request) async {
    try {
      await RideMatchService.instance.cancelRequest(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request withdrawn.')),
      );
    } catch (e) {
      debugPrint('cancelRequest failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not withdraw that request.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<_RoundChoice?> _pickRound(DriverMatch match, Student student) {
    final noteCtrl = TextEditingController();
    DriverSchedule? selected = match.openSchedules.isEmpty
        ? null
        : match.openSchedules.first;

    return showModalBottomSheet<_RoundChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (innerCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(innerCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: innerCtx.cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Request a seat for ${student.name}',
                    style: TextStyle(
                      color: innerCtx.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick the round that fits their timings. '
                    '${match.driver.name} decides whether to accept.',
                    style: TextStyle(
                      color: innerCtx.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...match.driver.orderedSchedules.map((r) {
                    final free = r.hasSpace;
                    final isSelected = selected?.id == r.id;
                    return GestureDetector(
                      onTap: free
                          ? () => setSheetState(() => selected = r)
                          : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.accent.withValues(alpha: 0.16)
                              : innerCtx.cardBgElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? widget.accent
                                : innerCtx.inputBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: free
                                  ? (isSelected
                                      ? widget.accent
                                      : innerCtx.textTertiary)
                                  : innerCtx.textTertiary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.label,
                                    style: TextStyle(
                                      color: free
                                          ? innerCtx.textPrimary
                                          : innerCtx.textTertiary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${r.directionLabel} · ${r.timeRange}',
                                    style: TextStyle(
                                      color: innerCtx.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              free ? '${r.availableSeats} free' : 'Full',
                              style: TextStyle(
                                color: free
                                    ? AppTheme.success
                                    : AppTheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: TextStyle(
                      color: innerCtx.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Anything the driver should know? (optional)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: selected == null
                        ? null
                        : () => Navigator.pop(
                              innerCtx,
                              _RoundChoice(
                                schedule: selected!,
                                note: noteCtrl.text.trim().isEmpty
                                    ? null
                                    : noteCtrl.text.trim(),
                              ),
                            ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: selected == null
                            ? innerCtx.surfaceBorder
                            : widget.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        selected == null
                            ? 'No rounds have space'
                            : 'Send request',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected == null
                              ? innerCtx.textTertiary
                              : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(noteCtrl.dispose);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final subject = _subject;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _Header(accent: widget.accent, onBack: () => context.pop()),
              if (_candidates.length > 1)
                _ChildSwitcher(
                  students: _candidates,
                  index: _childIndex,
                  accent: widget.accent,
                  onChanged: (i) => setState(() => _childIndex = i),
                ),
              Expanded(
                child: subject == null
                    ? const _Message(
                        emoji: '👶',
                        title: 'No child on this account yet',
                        body: 'Add a child from your profile, then come back to '
                            'find drivers for their school.',
                      )
                    : subject.school.trim().isEmpty
                        ? _Message(
                            emoji: '🏫',
                            title: 'No school on ${subject.name}\'s record',
                            body: 'Driver search matches on the school your '
                                'child attends. Add it from your profile and '
                                'this list will fill in.',
                          )
                        : _MatchList(
                            student: subject,
                            accent: widget.accent,
                            busyDriverId: _busyDriverId,
                            onRequest: (m) => _request(m, subject),
                            onCancel: _cancel,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundChoice {
  final DriverSchedule schedule;
  final String? note;
  const _RoundChoice({required this.schedule, this.note});
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Color accent;
  final VoidCallback onBack;

  const _Header({required this.accent, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.2), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Icon(Icons.arrow_back, color: context.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find a Driver',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Drivers who already run to your school',
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
    );
  }
}

// ── Child switcher ──────────────────────────────────────────────────────────

class _ChildSwitcher extends StatelessWidget {
  final List<Student> students;
  final int index;
  final Color accent;
  final ValueChanged<int> onChanged;

  const _ChildSwitcher({
    required this.students,
    required this.index,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == index;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? accent : context.cardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? accent : context.inputBorder,
                ),
              ),
              child: Text(
                students[i].name.isEmpty ? 'Child ${i + 1}' : students[i].name,
                style: TextStyle(
                  color: active ? Colors.white : context.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Match list ──────────────────────────────────────────────────────────────

class _MatchList extends StatelessWidget {
  final Student student;
  final Color accent;
  final String? busyDriverId;
  final void Function(DriverMatch) onRequest;
  final void Function(RideRequest) onCancel;

  const _MatchList({
    required this.student,
    required this.accent,
    required this.busyDriverId,
    required this.onRequest,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverMatch>>(
      // Keyed by student id so switching child tears the old stream down rather
      // than leaving the previous child's results on screen under the new name.
      key: ValueKey(student.id),
      stream: RideMatchService.instance.watchMatchesFor(student),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('driver match stream: ${snap.error}');
          return const _Message(
            emoji: '⚠️',
            title: 'Could not load drivers',
            body: 'The server refused the request. Check your connection and '
                'pull back into this screen to retry.',
          );
        }
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          );
        }

        final matches = snap.data!;
        if (matches.isEmpty) {
          return _Message(
            emoji: '🔍',
            title: 'No drivers serve ${student.school} yet',
            body: 'Nobody has listed this institution. As drivers join, they '
                'will appear here automatically — nothing to check back on '
                'manually.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: matches.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${matches.length} driver${matches.length == 1 ? '' : 's'} '
                  'serving ${student.school}'
                  '${student.pickupLocation == null ? '' : ', nearest first'}',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                ),
              );
            }

            final match = matches[i - 1];
            final existing = SessionService.instance.requestFor(
              studentId: student.id,
              driverId: match.driver.id,
            );
            return _DriverMatchCard(
              match: match,
              accent: accent,
              existing: existing,
              busy: busyDriverId == match.driver.id,
              onRequest: () => onRequest(match),
              onCancel: existing == null ? null : () => onCancel(existing),
            );
          },
        );
      },
    );
  }
}

class _DriverMatchCard extends StatelessWidget {
  final DriverMatch match;
  final Color accent;

  /// The live request for this child/driver pair, if one exists. Drives whether
  /// the card offers "Request a seat", shows "Awaiting reply", or says the seat
  /// is already booked — so a parent cannot send a second request to a driver
  /// they are already talking to.
  final RideRequest? existing;

  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback? onCancel;

  const _DriverMatchCard({
    required this.match,
    required this.accent,
    required this.existing,
    required this.busy,
    required this.onRequest,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final d = match.driver;
    final pending = existing?.isPending ?? false;
    final booked = existing?.isAccepted ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        enableBlur: false,
        padding: const EdgeInsets.all(16),
        borderColor: booked
            ? AppTheme.success.withValues(alpha: 0.4)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('🧑‍✈️', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name.isEmpty ? 'Unnamed driver' : d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (d.isApproved)
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppTheme.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(d),
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
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  label: 'SEATS FREE',
                  value: '${match.availableSeats}',
                  color: match.hasOpenSeats
                      ? AppTheme.success
                      : AppTheme.error,
                ),
                _Stat(
                  label: 'DISTANCE',
                  // Null distance is "we don't know", never "0 km away". Showing
                  // 0 for an unpinned location would put an unranked driver at
                  // the top of a list the parent believes is sorted by distance.
                  value: match.distanceKm == null
                      ? '—'
                      : '${match.distanceKm!.toStringAsFixed(1)} km',
                  color: context.textPrimary,
                ),
                _Stat(
                  label: 'RATING',
                  value: d.ratingCount == 0
                      ? 'New'
                      : '${d.rating.toStringAsFixed(1)} (${d.ratingCount})',
                  color: context.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (match.driver.orderedSchedules.isNotEmpty) ...[
              Text(
                'ROUNDS',
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: match.driver.orderedSchedules.map((r) {
                  final color =
                      r.hasSpace ? AppTheme.success : AppTheme.error;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: color.withValues(alpha: 0.28)),
                    ),
                    child: Text(
                      '${r.directionLabel} ${r.timeRange} · '
                      '${r.hasSpace ? '${r.availableSeats} free' : 'full'}',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (busy)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            else if (booked)
              _Banner(
                color: AppTheme.success,
                icon: Icons.check_circle_rounded,
                text: 'Seat confirmed on ${existing!.scheduleLabel}',
              )
            else if (pending)
              Column(
                children: [
                  _Banner(
                    color: AppTheme.warning,
                    icon: Icons.hourglass_top_rounded,
                    text: 'Awaiting reply · ${existing!.scheduleLabel}',
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'Withdraw request',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: match.hasOpenSeats ? onRequest : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: match.hasOpenSeats
                        ? accent
                        : context.surfaceBorder.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    match.hasOpenSeats
                        ? 'Request a seat'
                        : 'No seats on any round',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: match.hasOpenSeats
                          ? Colors.white
                          : context.textTertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            if (existing != null &&
                existing!.status == RideRequestStatus.rejected) ...[
              const SizedBox(height: 8),
              Text(
                existing!.responseNote?.isNotEmpty == true
                    ? 'Previously declined: ${existing!.responseNote}'
                    : 'You asked before and this driver declined.',
                style: TextStyle(color: context.textTertiary, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _subtitle(Driver d) {
    final bits = <String>[
      if (d.experienceYears > 0) '${d.experienceYears} yrs experience',
      if (!d.isApproved) 'Verification pending',
    ];
    return bits.isEmpty ? 'Driver' : bits.join(' · ');
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message ─────────────────────────────────────────────────────────────────

class _Message extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;

  const _Message({
    required this.emoji,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
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
          ],
        ),
      ),
    );
  }
}
