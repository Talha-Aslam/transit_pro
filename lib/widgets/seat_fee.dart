import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../app/ride_match_service.dart';
import '../app/session_service.dart';
import '../data/ride_request_repository.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';
import 'text_controller_scope.dart';

/// The monthly fee on one seat, negotiated on its ride request: the driver
/// proposes, the family accepts or rejects. Before booking this decides
/// whether the seat can be accepted; after booking it changes the fee the
/// family is billed (applied by `FeeAgreementSync` on the driver's phone).

String _rs(int paisa) => 'Rs.${(paisa / 100).round()}';

// ── Driver: send a fee ──────────────────────────────────────────────────────

/// Asks the driver for the monthly fee to send, and a note. Returns
/// (rupees, note), or null when they backed out.
///
/// [currentFeePaisa] is the fee already in force on a booked seat (0 when
/// none), shown so the driver changes it knowingly.
Future<(int, String)?> showFeeProposalSheet(
  BuildContext context, {
  required RideRequest request,
  int currentFeePaisa = 0,
}) => showModalBottomSheet<(int, String)>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _FeeSheet(request: request, currentFeePaisa: currentFeePaisa),
);

class _FeeSheet extends StatefulWidget {
  final RideRequest request;
  final int currentFeePaisa;
  const _FeeSheet({required this.request, required this.currentFeePaisa});

  @override
  State<_FeeSheet> createState() => _FeeSheetState();
}

class _FeeSheetState extends State<_FeeSheet> {
  late final _amount = TextEditingController(
    text: _startPaisa > 0 ? '${(_startPaisa / 100).round()}' : '',
  );
  final _note = TextEditingController();
  String? _error;

  int get _startPaisa => widget.request.feePaisa > 0
      ? widget.request.feePaisa
      : widget.currentFeePaisa;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _send() {
    final rupees = int.tryParse(_amount.text.trim()) ?? 0;
    if (rupees <= 0) {
      setState(() => _error = 'Enter the fee per month.');
      return;
    }
    if (widget.request.isAccepted &&
        widget.currentFeePaisa > 0 &&
        rupees * 100 == widget.currentFeePaisa) {
      setState(() => _error = 'That is already the fee for this seat.');
      return;
    }
    Navigator.pop(context, (rupees, _note.text.trim()));
  }

  String get _explainer {
    final r = widget.request;
    final turnedDown = r.feeStatus == FeeStatus.rejected && r.feePaisa > 0;
    final declined = turnedDown
        ? 'The family turned down ${_rs(r.feePaisa)}'
              '${(r.feeFamilyNote ?? '').isEmpty ? '.' : ': "${r.feeFamilyNote}".'} '
        : '';
    if (!r.isAccepted) {
      return turnedDown
          ? '${declined}Send a new fee, or decline the request.'
          : 'The family accepts or rejects it. Billing starts the day you '
                'accept the seat, every 30 days.';
    }
    if (widget.currentFeePaisa > 0) {
      return '${declined}The fee now is ${_rs(widget.currentFeePaisa)} a month. '
          'If the family accepts the new one, it is billed from the next '
          'bill; until then the current fee stays.';
    }
    return '${declined}This seat has no fee yet. Once the family accepts, '
        'the first bill is issued and then every 30 days.';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final changing = r.isAccepted && widget.currentFeePaisa > 0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                changing
                    ? 'Change the fee for ${r.studentName}'
                    : 'Monthly fee for ${r.studentName}',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _explainer,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: context.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  prefixText: 'Rs. ',
                  suffixText: '/ month',
                  hintText: 'e.g. 4000',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Note for the family (optional)',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.driverCyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(changing ? 'Send new fee' : 'Send fee'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The driver sets or changes the fee on a booked seat: asks for it, sends
/// it to the family, and says how that went.
Future<void> requestSeatFee(
  BuildContext context,
  RideRequest request, {
  int currentFeePaisa = 0,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void toast(String message, Color color) => messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: color),
  );
  final result = await showFeeProposalSheet(
    context,
    request: request,
    currentFeePaisa: currentFeePaisa,
  );
  if (result == null) return;
  try {
    await RideMatchService.instance.proposeFee(
      request,
      feePaisa: result.$1 * 100,
      note: result.$2,
      currentFeePaisa: currentFeePaisa,
    );
    toast(
      'Fee sent. ${request.studentName}\'s family will accept or reject it.',
      AppTheme.success,
    );
  } on RideRequestException catch (e) {
    toast(e.message, AppTheme.warning);
  } catch (e) {
    debugPrint('fee proposal failed: $e');
    toast(
      'Could not send the fee. Check your connection and try again.',
      AppTheme.error,
    );
  }
}

/// One line about a booked seat's fee, for the roster card: what is in
/// force, and any proposal still open. Null when there is nothing to say.
(String, Color)? seatFeeSummary(Student student, RideRequest? request) {
  final current = student.monthlyFeePaisa;
  final r = request;
  if (r != null && r.isAccepted && r.feePaisa > 0) {
    if (r.feeStatus == FeeStatus.proposed) {
      return (
        current > 0
            ? 'Fee ${_rs(current)} · ${_rs(r.feePaisa)} sent, awaiting family'
            : '${_rs(r.feePaisa)} / month sent, awaiting family',
        AppTheme.warning,
      );
    }
    if (r.feeStatus == FeeStatus.rejected) {
      return (
        current > 0
            ? 'Fee ${_rs(current)} · family declined ${_rs(r.feePaisa)}'
            : 'No fee · family declined ${_rs(r.feePaisa)}',
        AppTheme.error,
      );
    }
  }
  if (current > 0) return ('Fee: ${_rs(current)} / month', AppTheme.success);
  return ('No monthly fee set', AppTheme.warning);
}

/// The fee section of a booked rider, for the driver: what is in force,
/// any open proposal, and the button to set or change it. Reads the live
/// roster and requests, so it updates the moment the family answers.
class DriverSeatFeeCard extends StatefulWidget {
  final String studentId;
  const DriverSeatFeeCard({super.key, required this.studentId});

  @override
  State<DriverSeatFeeCard> createState() => _DriverSeatFeeCardState();
}

class _DriverSeatFeeCardState extends State<DriverSeatFeeCard> {
  final _session = SessionService.instance;
  bool _busy = false;

  Student? get _student =>
      _session.roster.value.where((s) => s.id == widget.studentId).firstOrNull;

  RideRequest? get _request => _session.rideRequests.value
      .where((r) => r.studentId == widget.studentId && r.isAccepted)
      .firstOrNull;

  Future<void> _send(RideRequest request, int current) async {
    setState(() => _busy = true);
    try {
      await requestSeatFee(context, request, currentFeePaisa: current);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_session.roster, _session.rideRequests]),
      builder: (context, _) {
        final student = _student;
        final request = _request;
        if (student == null) return const SizedBox.shrink();
        final current = student.monthlyFeePaisa;
        final summary = seatFeeSummary(student, request);
        final proposed =
            request != null &&
            request.feeStatus == FeeStatus.proposed &&
            request.feePaisa > 0;
        return GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    color: AppTheme.driverCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly fee',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    current > 0 ? '${_rs(current)} / month' : 'Not set',
                    style: TextStyle(
                      color: current > 0
                          ? AppTheme.success
                          : context.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (summary != null &&
                  (proposed ||
                      current <= 0 ||
                      request?.feeStatus == FeeStatus.rejected)) ...[
                const SizedBox(height: 6),
                Text(
                  summary.$1,
                  style: TextStyle(color: summary.$2, fontSize: 12),
                ),
              ],
              if (request != null &&
                  request.feeStatus == FeeStatus.rejected &&
                  (request.feeFamilyNote ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '"${request.feeFamilyNote!.trim()}"',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              if (request == null)
                Text(
                  'This rider was not booked through a seat request, so the '
                  'fee cannot be sent from here.',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                )
              else if (_busy)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppTheme.driverCyan,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _send(request, current),
                    icon: Icon(
                      current > 0 || proposed
                          ? Icons.edit_rounded
                          : Icons.request_quote_rounded,
                      size: 18,
                    ),
                    label: Text(
                      proposed
                          ? 'Change the fee you sent'
                          : current > 0
                          ? 'Request a fee change'
                          : 'Request monthly fee',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.driverCyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: AppTheme.driverCyan.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Family: answer a fee ────────────────────────────────────────────────────

/// The driver's fee on a request: accept it, or turn it down with a reason
/// the driver reads before sending a new one.
///
/// On a waiting request this settles the fee before the seat is booked; on a
/// booked one ([RideRequest.isAccepted]) it changes the fee billed.
class FeeAnswerCard extends StatefulWidget {
  final RideRequest request;
  final Color accent;

  /// The fee in force on a booked seat, shown next to the proposed one.
  final int currentFeePaisa;

  const FeeAnswerCard({
    super.key,
    required this.request,
    required this.accent,
    this.currentFeePaisa = 0,
  });

  @override
  State<FeeAnswerCard> createState() => _FeeAnswerCardState();
}

class _FeeAnswerCardState extends State<FeeAnswerCard> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    String? note;
    if (!accept) {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => TextControllerScope(
          builder: (ctrl) => AlertDialog(
            title: const Text('Reject this fee?'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Tell the driver why — e.g. it is more than '
                    'others charge for this distance',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Reject fee'),
              ),
            ],
          ),
        ),
      );
      if (note == null) return;
    }
    setState(() => _busy = true);
    try {
      await RideMatchService.instance.answerFee(
        widget.request,
        accept: accept,
        note: note,
      );
    } catch (e) {
      debugPrint('fee answer failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send. Check your connection.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final booked = r.isAccepted;
    final driverNote = (r.feeDriverNote ?? '').trim();
    final mine = r.requesterId == SessionService.instance.uid;
    final current = widget.currentFeePaisa;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booked && current > 0
                ? '💰 New fee: ${_rs(r.feePaisa)} / month (now ${_rs(current)})'
                : '💰 Fee: ${_rs(r.feePaisa)} / month',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (driverNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"$driverNote"',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          switch (r.feeStatus) {
            FeeStatus.accepted => Text(
              booked
                  ? 'You accepted this fee. It is billed from the next bill.'
                  : 'You accepted this fee. Waiting for the driver to confirm '
                        'the seat.',
              style: const TextStyle(color: AppTheme.success, fontSize: 12),
            ),
            FeeStatus.rejected => Text(
              'You turned it down'
              '${(r.feeFamilyNote ?? '').isEmpty ? '' : ': "${r.feeFamilyNote}"'}'
              '. ${booked && current > 0 ? 'The current fee stays. ' : ''}'
              'Waiting for the driver.',
              style: const TextStyle(color: AppTheme.error, fontSize: 12),
            ),
            _ when !mine => Text(
              'Waiting for the family member who booked this seat to answer.',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            _ =>
              _busy
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _answer(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _answer(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept fee'),
                          ),
                        ),
                      ],
                    ),
          },
        ],
      ),
    );
  }
}

/// The fee section of the family's "my driver" screen: the fee in force, the
/// driver's fee request to answer, and — when there is no fee at all — a way
/// to ask the driver to set one. Shown only for a seat booked through a
/// request.
class FamilySeatFeeCard extends StatefulWidget {
  final String driverId;
  final String studentId;

  /// The fee on the child's record (0 when none).
  final int currentFeePaisa;
  final Color accent;

  const FamilySeatFeeCard({
    super.key,
    required this.driverId,
    required this.studentId,
    required this.currentFeePaisa,
    required this.accent,
  });

  @override
  State<FamilySeatFeeCard> createState() => _FamilySeatFeeCardState();
}

class _FamilySeatFeeCardState extends State<FamilySeatFeeCard> {
  late Stream<RideRequest?> _stream = _watch();
  bool _asking = false;

  Stream<RideRequest?> _watch() => RideRequestRepository.instance.watch(
    driverId: widget.driverId,
    studentId: widget.studentId,
  );

  @override
  void didUpdateWidget(covariant FamilySeatFeeCard old) {
    super.didUpdateWidget(old);
    if (old.driverId != widget.driverId || old.studentId != widget.studentId) {
      _stream = _watch();
    }
  }

  Future<void> _ask(RideRequest request) async {
    setState(() => _asking = true);
    try {
      await RideMatchService.instance.askForFee(request);
      _toast(
        'Asked ${request.driverName} to set the monthly fee.',
        AppTheme.success,
      );
    } on RideRequestException catch (e) {
      _toast(e.message, AppTheme.warning);
    } catch (e) {
      debugPrint('fee ask failed: $e');
      _toast('Could not send. Check your connection.', AppTheme.error);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _toast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RideRequest?>(
      stream: _stream,
      builder: (context, snap) {
        final r = snap.data;
        if (r == null || !r.isAccepted) return const SizedBox.shrink();
        final current = widget.currentFeePaisa;
        final open = r.feeStatus == FeeStatus.proposed && r.feePaisa > 0;
        final agreedNotApplied = r.hasAgreedFee && r.feePaisa != current;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GlassCard(
            enableBlur: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payments_rounded,
                      color: widget.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Monthly fee',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      current > 0 ? '${_rs(current)} / month' : 'Not set yet',
                      style: TextStyle(
                        color: current > 0
                            ? AppTheme.success
                            : context.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (open || r.feeStatus == FeeStatus.rejected)
                  FeeAnswerCard(
                    request: r,
                    accent: widget.accent,
                    currentFeePaisa: current,
                  )
                else if (agreedNotApplied)
                  Text(
                    'You accepted ${_rs(r.feePaisa)} a month. It shows here '
                    'as soon as the driver\'s app updates your bill.',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontSize: 12,
                    ),
                  )
                else if (current > 0)
                  Text(
                    'If the driver asks for a different fee, it appears here '
                    'for you to accept or reject.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (current <= 0 && !open && !agreedNotApplied) ...[
                  const SizedBox(height: 8),
                  Text(
                    'The driver has not set a monthly fee for this seat yet.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _asking
                        ? const Center(child: CircularProgressIndicator())
                        : OutlinedButton.icon(
                            onPressed: () => _ask(r),
                            icon: const Icon(
                              Icons.request_quote_rounded,
                              size: 18,
                            ),
                            label: const Text('Ask the driver to set the fee'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: widget.accent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: widget.accent.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
