import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/missed_bus_service.dart';
import '../../app/session_service.dart';
import '../../models/missed_bus_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverPickupRequestsScreen extends StatefulWidget {
  const DriverPickupRequestsScreen({super.key});

  @override
  State<DriverPickupRequestsScreen> createState() =>
      _DriverPickupRequestsScreenState();
}

class _DriverPickupRequestsScreenState
    extends State<DriverPickupRequestsScreen> {
  final _service = MissedBusService.instance;

  @override
  void initState() {
    super.initState();
    _service.driverIncomingRequests.addListener(_rebuild);
  }

  @override
  void dispose() {
    _service.driverIncomingRequests.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _openRequest(MissedBusRequest req) async {
    try {
      await _service.startViewing(req.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // The sheet is dismissible by tapping outside it, not just the
      // buttons inside — mirrored by `onDismissed` below withdrawing the
      // bid, so a driver who backs out this way doesn't leave the request
      // stuck on "viewing" forever.
      builder: (_) => _BidSheet(request: req),
    ).then((_) {
      final stillPending = _service.driverActiveBid.value?.id == req.id;
      if (stillPending) _service.withdrawBid();
    });
  }

  @override
  Widget build(BuildContext context) {
    final requests = _service.driverIncomingRequests.value;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.inputBorder),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: context.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup Requests',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (requests.isNotEmpty)
                            Text(
                              '${requests.length} student${requests.length > 1 ? 's' : ''} waiting',
                              style: TextStyle(
                                color: AppTheme.warningLight,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (requests.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Body ─────────────────────────────────────────────────────
              Expanded(
                child: requests.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: requests.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _RequestCard(
                            request: requests[i],
                            onView: () => _openRequest(requests[i]),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final MissedBusRequest request;
  final VoidCallback onView;

  const _RequestCard({required this.request, required this.onView});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      // One instance per row of a `ListView.builder` — the blur pass would
      // repeat for every visible card on every scroll frame.
      enableBlur: false,
      padding: const EdgeInsets.all(0),
      clipContent: true,
      child: Column(
        children: [
          // Top accent bar
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.error, AppTheme.warning],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student info row
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🧒', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.studentName,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'ID: ${request.studentId}  ·  ${request.missedBusNumber}',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MISSED BUS',
                        style: TextStyle(
                          color: AppTheme.warningLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Journey row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cardBgElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FROM',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.currentStop,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.driverCyan,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TO',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.destination,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Route info
                Row(
                  children: [
                    Icon(
                      Icons.route_rounded,
                      color: AppTheme.driverCyan,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      request.assignedRoute,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Action button — a driver who isn't interested just leaves
                // it in the shared queue for someone else, rather than
                // declining it away from every other driver too.
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: onView,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.driverCyan, AppTheme.driverTeal],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'View & Send Offer',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
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

// ─── Bid Sheet ────────────────────────────────────────────────────────────────
/// Opened once [MissedBusService.startViewing] has already flipped the
/// request to `viewing` (see `_openRequest` above). Lets the driver type in
/// a fare and send it; once sent, switches to a "waiting for the family"
/// view fed live by [MissedBusService.driverActiveBid] — driven off that
/// notifier rather than a local flag, so it also reacts if the requester
/// accepts or rejects while this sheet is still open.
class _BidSheet extends StatefulWidget {
  final MissedBusRequest request;
  const _BidSheet({required this.request});

  @override
  State<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<_BidSheet> {
  late final TextEditingController _fareCtrl;
  final _service = MissedBusService.instance;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final presetPaisa =
        SessionService.instance.driver.value?.missedBusFarePaisa ?? 0;
    _fareCtrl = TextEditingController(
      text: presetPaisa > 0 ? (presetPaisa / 100).round().toString() : '',
    );
    _service.driverActiveBid.addListener(_onBidChanged);
  }

  @override
  void dispose() {
    _service.driverActiveBid.removeListener(_onBidChanged);
    _fareCtrl.dispose();
    super.dispose();
  }

  void _onBidChanged() {
    if (!mounted) return;
    // Null means the requester rejected it (or another path cleared it);
    // `accepted` means they took it. Either way there's nothing left for
    // this sheet to do.
    final bid = _service.driverActiveBid.value;
    if (bid == null || bid.status == RequestStatus.accepted) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  Future<void> _sendOffer() async {
    final rupees = int.tryParse(_fareCtrl.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() => _error = 'Enter a valid fare amount');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.sendBid(
        requestId: widget.request.id,
        farePaisa: rupees * 100,
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final bid = _service.driverActiveBid.value;
    final offerSent = bid?.status == RequestStatus.bidOffered;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: context.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(offerSent ? '🕒' : '🚌', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            offerSent ? 'Offer sent' : 'Send a fare offer',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            offerSent
                ? 'Waiting for ${request.studentName} to accept or reject '
                      'Rs.${bid?.fareDisplay?.replaceFirst('Rs.', '') ?? int.tryParse(_fareCtrl.text) ?? ''}.'
                : 'Pickup for ${request.studentName}: ${request.currentStop} '
                      '→ ${request.destination}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (offerSent)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.driverCyan),
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: context.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.inputBorder),
              ),
              child: TextField(
                controller: _fareCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  prefixText: 'Rs. ',
                  prefixStyle: TextStyle(color: context.textPrimary),
                  hintText: 'Charges',
                  hintStyle: TextStyle(color: context.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _sending ? null : _sendOffer,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.driverCyan, AppTheme.driverTeal],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _sending ? 'Sending…' : 'Send Offer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All clear! No students need a pickup.',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
