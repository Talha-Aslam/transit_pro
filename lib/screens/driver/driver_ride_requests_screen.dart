import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/ride_match_service.dart';
import '../../app/session_service.dart';
import '../../data/ride_request_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// The driver's seat-request inbox: accept, decline, or release a booked seat.
///
/// Distinct from `driver_pickup_requests_screen.dart`, which handles one-off
/// missed-bus pickups. This is the ongoing arrangement — a family asking to ride
/// every day on a specific round.
///
/// Everything on screen is streamed from [SessionService], so a seat count moves
/// the moment the transaction commits and a family cancelling a request removes
/// the card without a refresh.
class DriverRideRequestsScreen extends StatefulWidget {
  const DriverRideRequestsScreen({super.key});

  @override
  State<DriverRideRequestsScreen> createState() =>
      _DriverRideRequestsScreenState();
}

class _DriverRideRequestsScreenState extends State<DriverRideRequestsScreen> {
  final _session = SessionService.instance;

  /// `pending` or `booked`.
  String _tab = 'pending';

  /// The request currently being written, so only its card shows a spinner
  /// rather than the whole list freezing.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _session.rideRequests.addListener(_rebuild);
    _session.driver.addListener(_rebuild);
  }

  @override
  void dispose() {
    _session.rideRequests.removeListener(_rebuild);
    _session.driver.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Runs one request action, surfacing its outcome.
  ///
  /// [RideRequestException] carries a message written for the driver — "that
  /// round is full", "already answered" — and is shown as-is. Anything else is a
  /// genuine fault, so it gets a generic message and the real error goes to the
  /// log rather than onto the screen.
  Future<void> _run(
    RideRequest request,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busyId = request.id);
    try {
      await action();
      if (!mounted) return;
      _toast(successMessage, AppTheme.success);
    } on RideRequestException catch (e) {
      if (!mounted) return;
      _toast(e.message, AppTheme.warning);
    } catch (e) {
      debugPrint('ride request action failed: $e');
      if (!mounted) return;
      _toast(
        'Could not save that. Check your connection and try again.',
        AppTheme.error,
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _accept(RideRequest request) => _run(
    request,
    () => RideMatchService.instance.accept(request),
    successMessage: '${request.studentName} is on your roster.',
  );

  Future<void> _decline(RideRequest request) async {
    final reason = await _askReason(
      title: 'Decline this request?',
      body:
          '${request.studentName} will be told you could not take them. You '
          'can add a reason.',
      confirmLabel: 'Decline',
      confirmColor: AppTheme.error,
    );
    if (reason == null) return;
    await _run(
      request,
      () => RideMatchService.instance.reject(request, reason: reason),
      successMessage: 'Request declined.',
    );
  }

  Future<void> _release(RideRequest request) async {
    final reason = await _askReason(
      title: 'Remove from your roster?',
      body:
          '${request.studentName} loses their seat on '
          '${request.scheduleLabel}, and the seat goes back to your available '
          'count.',
      confirmLabel: 'Remove',
      confirmColor: AppTheme.error,
      askForText: false,
    );
    if (reason == null) return;
    await _run(
      request,
      () => RideMatchService.instance.release(request),
      successMessage: 'Seat released.',
    );
  }

  /// Returns the entered reason, `''` when confirmed without one, or null when
  /// the driver backed out. Null-vs-empty is the difference between "cancelled"
  /// and "confirmed silently", which a bare bool could not express.
  Future<String?> _askReason({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
    bool askForText = true,
  }) {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sheetCtx.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
              if (askForText) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  style: TextStyle(color: sheetCtx.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Reason (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sheetCtx.surfaceBorder),
                        ),
                        child: Text(
                          'Cancel',
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
                      onTap: () =>
                          Navigator.pop(sheetCtx, controller.text.trim()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: confirmColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          confirmLabel,
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
    ).whenComplete(controller.dispose);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final driver = _session.driver.value;
    final all = _session.rideRequests.value;
    final pending = all.where((r) => r.isPending).toList();
    final booked = all.where((r) => r.isAccepted).toList();
    final shown = _tab == 'pending' ? pending : booked;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                pendingCount: pending.length,
                onBack: () => context.pop(),
              ),
              _SeatSummary(driver: driver),
              // The round card(s) above were sitting almost flush against
              // the "Waiting / On my roster" toggle below -- a deliberate
              // gap here (matching the one `_Tabs` already puts under
              // itself, `EdgeInsets.fromLTRB(16, 0, 16, 14)`) gives both
              // blocks room to read as separate sections.
              const SizedBox(height: 14),
              _Tabs(
                active: _tab,
                pendingCount: pending.length,
                bookedCount: booked.length,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: shown.isEmpty
                    ? _EmptyState(tab: _tab, driver: driver)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final request = shown[i];
                          return _RideRequestCard(
                            request: request,
                            schedule: driver?.scheduleById(request.scheduleId),
                            busy: _busyId == request.id,
                            onAccept: () => _accept(request),
                            onDecline: () => _decline(request),
                            onRelease: () => _release(request),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onBack;

  const _Header({required this.pendingCount, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.driverCyan.withValues(alpha: 0.15),
            Colors.transparent,
          ],
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
                  'Seat Requests',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  pendingCount == 0
                      ? 'Nothing waiting for you'
                      : '$pendingCount waiting on your reply',
                  style: TextStyle(
                    color: pendingCount == 0
                        ? context.textSecondary
                        : AppTheme.warningLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: AppTheme.warningLight,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Seat summary ────────────────────────────────────────────────────────────

/// Live seat availability, per round.
///
/// This is the number a driver is being asked to manage, so it belongs above the
/// requests rather than buried in a profile screen — accepting is only a sensible
/// decision if you can see what it costs you.
class _SeatSummary extends StatelessWidget {
  final Driver? driver;
  const _SeatSummary({required this.driver});

  @override
  Widget build(BuildContext context) {
    final rounds = driver?.orderedSchedules ?? const <DriverSchedule>[];

    if (rounds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: AppTheme.warning.withValues(alpha: 0.4),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have no rounds set up, so no family can request a seat. '
                  'Add them from your profile.',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Full-width, stacked vertically -- was a horizontal-scrolling row of
    // fixed `width: 168` cards, which is exactly why "Round 1" looked
    // squished and centered instead of matching the screen's own margins.
    // `16` on both sides matches `_Header` and `_Tabs` below exactly (both
    // `EdgeInsets.fromLTRB(16, ...)`), so the card's left/right edges line
    // up with everything above and below it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rounds.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _RoundCard(round: rounds[i]),
          ],
        ],
      ),
    );
  }
}

/// One round's live seat availability -- "Round 1", its pickup/drop-off
/// window, a fill-level progress bar, and "N of M free". Its own widget
/// (rather than inline per-item code) now that it no longer needs the
/// `Builder`-per-item trick a horizontal `Row` conversion used to require.
class _RoundCard extends StatelessWidget {
  final DriverSchedule round;
  const _RoundCard({required this.round});

  @override
  Widget build(BuildContext context) {
    final r = round;
    final color = r.isFull ? AppTheme.error : AppTheme.success;
    final filled = r.totalSeats <= 0
        ? 0.0
        : (r.totalSeats - r.availableSeats) / r.totalSeats;
    // One gap size reused between every internal element (icon row → time
    // text → progress bar → bottom label) instead of the previous 8/10/8 —
    // uniform spacing reads as deliberate, mismatched spacing reads as
    // sloppy even when the differences are only a couple of pixels.
    const gap = SizedBox(height: 10);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.directions_bus_filled_rounded,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          gap,
          Text(
            '${r.directionLabel} · ${r.timeRange}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textTertiary, fontSize: 11),
          ),
          gap,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: filled.clamp(0, 1),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          gap,
          Text(
            r.isFull
                ? 'Full — ${r.totalSeats} booked'
                : '${r.availableSeats} of ${r.totalSeats} free',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tabs ────────────────────────────────────────────────────────────────────

/// A single-track segmented control rather than two independently-sized
/// chips — those gave "Waiting (0)" and "On my roster (0)" different widths
/// purely from label length, which reads as unbalanced. Equal-width cells in
/// one shared track fixes that regardless of what the counts are.
class _Tabs extends StatelessWidget {
  final String active;
  final int pendingCount;
  final int bookedCount;
  final ValueChanged<String> onChanged;

  const _Tabs({
    required this.active,
    required this.pendingCount,
    required this.bookedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.cardBgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.surfaceBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabChip(
                label: 'Waiting',
                count: pendingCount,
                active: active == 'pending',
                onTap: () => onChanged('pending'),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _TabChip(
                label: 'On my roster',
                count: bookedCount,
                active: active == 'booked',
                onTap: () => onChanged('booked'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.driverCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.driverCyan.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : context.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : context.textTertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: active ? Colors.white : context.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

// ── Request card ────────────────────────────────────────────────────────────

class _RideRequestCard extends StatelessWidget {
  final RideRequest request;

  /// The round as it stands *now*, not as it was when the request was sent — so a
  /// driver sees "Full" on a request for a round that filled up in between, and
  /// null when they have since deleted the round entirely.
  final DriverSchedule? schedule;

  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRelease;

  const _RideRequestCard({
    required this.request,
    required this.schedule,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final accent = request.isAccepted ? AppTheme.success : AppTheme.driverCyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        // One instance per row of a `ListView.builder` — the blur pass would
        // repeat for every visible card on every scroll frame.
        enableBlur: false,
        padding: const EdgeInsets.all(0),
        clipContent: true,
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.4)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('🧒', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.studentName.isEmpty
                                  ? 'Unnamed student'
                                  : request.studentName,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                if (request.studentGrade.isNotEmpty)
                                  request.studentGrade,
                                if (request.school.isNotEmpty) request.school,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: request.statusLabel, color: accent),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    icon: Icons.route_rounded,
                    label: 'ROUND',
                    value: request.scheduleLabel.isEmpty
                        ? 'Not specified'
                        : request.scheduleLabel,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.event_seat_rounded,
                    label: 'SEATS NOW',
                    value: schedule == null
                        ? 'That round no longer exists'
                        : '${schedule!.availableSeats} of '
                              '${schedule!.totalSeats} free',
                    valueColor: schedule == null
                        ? AppTheme.error
                        : (schedule!.isFull
                              ? AppTheme.error
                              : AppTheme.success),
                  ),
                  if (request.note != null && request.note!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.sticky_note_2_outlined,
                      label: 'FROM THE FAMILY',
                      value: request.note!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (busy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    )
                  else if (request.isPending)
                    Row(
                      children: [
                        Expanded(
                          child: _OutlineButton(
                            label: 'Decline',
                            color: AppTheme.error,
                            onTap: onDecline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilledButton(
                            // A round that has filled since the request arrived
                            // must not offer an Accept that is guaranteed to
                            // fail. Disabling it here is cosmetic — the
                            // transaction refuses it anyway — but it stops the
                            // driver hunting for what they did wrong.
                            label: schedule == null
                                ? 'Round gone'
                                : (schedule!.isFull ? 'Round full' : 'Accept'),
                            color: AppTheme.success,
                            onTap: (schedule == null || schedule!.isFull)
                                ? null
                                : onAccept,
                          ),
                        ),
                      ],
                    )
                  else if (request.isAccepted)
                    _OutlineButton(
                      label: 'Remove from roster',
                      color: AppTheme.error,
                      onTap: onRelease,
                    )
                  else
                    Text(
                      request.responseNote?.isNotEmpty == true
                          ? 'You replied: ${request.responseNote}'
                          : 'Closed — no seat was booked.',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: context.textTertiary),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: context.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilledButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _FilledButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: enabled ? color : context.surfaceBorder.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled ? Colors.white : context.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

/// Says *why* the list is empty, which for a new driver is usually a setup gap
/// rather than a quiet day. Showing "no requests" to a driver who has listed no
/// schools is the failure that leaves them waiting forever.
class _EmptyState extends StatelessWidget {
  final String tab;
  final Driver? driver;

  const _EmptyState({required this.tab, required this.driver});

  @override
  Widget build(BuildContext context) {
    final noAreas = (driver?.serviceAreas ?? const []).isEmpty;
    final noRounds = (driver?.schedules ?? const []).isEmpty;

    final String title;
    final String body;
    if (tab == 'booked') {
      title = 'No students yet';
      body =
          'Accepted requests appear here, with an option to free the seat '
          'again.';
    } else if (noAreas || noRounds) {
      title = 'Families cannot find you yet';
      body =
          [
                if (noAreas)
                  'you have not listed any school, college or university',
                if (noRounds) 'you have no rounds set up',
              ]
              .join(', and ')
              .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());
    } else {
      title = 'Nothing waiting';
      body =
          'When a parent requests a seat on one of your rounds, it lands '
          'here.';
    }

    return Align(
      alignment: const Alignment(0, -0.22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          decoration: BoxDecoration(
            color: context.cardBgElevated.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.surfaceBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.driverCyan.withValues(alpha: 0.22),
                      AppTheme.driverCyan.withValues(alpha: 0.06),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.driverCyan.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('📭', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
