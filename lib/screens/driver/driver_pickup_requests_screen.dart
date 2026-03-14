import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/missed_bus_service.dart';
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

  void _confirmAccept(MissedBusRequest req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        request: req,
        onConfirm: () {
          _service.acceptRequest(req.id);
          Navigator.pop(context);
        },
      ),
    );
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
                      AppTheme.driverCyan.withOpacity(0.15),
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
                          child: Icon(Icons.arrow_back,
                              color: context.textPrimary, size: 16),
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
                                  color: AppTheme.warningLight, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (requests.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: const TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
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
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: requests.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _RequestCard(
                            request: requests[i],
                            onAccept: () => _confirmAccept(requests[i]),
                            onDecline: () =>
                                _service.declineRequest(requests[i].id),
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
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      clipContent: true,
      child: Column(
        children: [
          // Top accent bar
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.error, AppTheme.warning]),
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
                        color: AppTheme.error.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                          child:
                              Text('🧒', style: TextStyle(fontSize: 20))),
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
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MISSED BUS',
                        style: TextStyle(
                            color: AppTheme.warningLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
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
                            Text('FROM',
                                style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7)),
                            const SizedBox(height: 2),
                            Text(request.currentStop,
                                style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: AppTheme.driverCyan, size: 18),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('TO',
                                style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7)),
                            const SizedBox(height: 2),
                            Text(request.destination,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis),
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
                    Icon(Icons.route_rounded,
                        color: AppTheme.driverCyan, size: 14),
                    const SizedBox(width: 6),
                    Text(request.assignedRoute,
                        style: TextStyle(
                            color: context.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onDecline,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.error.withOpacity(0.5)),
                          ),
                          child: Center(
                            child: Text('Decline',
                                style: TextStyle(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: onAccept,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              AppTheme.success,
                              Color(0xFF10B981),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('Accept Pickup',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confirm Sheet ────────────────────────────────────────────────────────────
class _ConfirmSheet extends StatelessWidget {
  final MissedBusRequest request;
  final VoidCallback onConfirm;

  const _ConfirmSheet(
      {required this.request, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
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
          const Text('🚌', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Accept Pickup?',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'You\'ll pick up ${request.studentName} from ${request.currentStop} heading to ${request.destination}.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: context.cardBgElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.surfaceBorder),
                    ),
                    child: Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: context.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTheme.success, Color(0xFF10B981)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('Yes, Accept',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          Text('No Pending Requests',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('All clear! No students need a pickup.',
              style:
                  TextStyle(color: context.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
