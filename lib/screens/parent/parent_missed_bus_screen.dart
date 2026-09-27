import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart' show GeoCoord;
import '../../app/missed_bus_service.dart';
import '../../app/parent_data_service.dart';
import '../../models/missed_bus_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/profile_form_fields.dart';

class ParentMissedBusScreen extends StatefulWidget {
  const ParentMissedBusScreen({super.key});

  @override
  State<ParentMissedBusScreen> createState() => _ParentMissedBusScreenState();
}

class _ParentMissedBusScreenState extends State<ParentMissedBusScreen>
    with SingleTickerProviderStateMixin {
  final _service = MissedBusService.instance;
  final _parentService = ParentDataService.instance;
  GeoCoord? _currentStopCoord;
  String? _currentStopAddress;
  GeoCoord? _destinationCoord;
  String? _destinationAddress;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _service.studentActiveRequest.addListener(_rebuild);
    _parentService.children.addListener(_rebuild);
  }

  @override
  void dispose() {
    _service.studentActiveRequest.removeListener(_rebuild);
    _parentService.children.removeListener(_rebuild);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// A human-readable label to persist for a picked point — the resolved
  /// address once reverse-geocoding catches up, or the raw coordinates as an
  /// honest fallback if the parent submits before that finishes.
  String _labelFor(GeoCoord coord, String? address) =>
      address ??
      '${coord.lat.toStringAsFixed(6)}, ${coord.lng.toStringAsFixed(6)}';

  Future<void> _submitRequest() async {
    final currentStopCoord = _currentStopCoord;
    final destinationCoord = _destinationCoord;
    if (currentStopCoord == null || destinationCoord == null) return;
    final child = _parentService.selectedChild;
    if (child == null || child.id.isEmpty) return;
    try {
      await _service.raiseRequest(
        studentName: child.name,
        studentId: child.id,
        missedBusNumber: child.busNumber,
        assignedRoute: child.route,
        currentStop: _labelFor(currentStopCoord, _currentStopAddress),
        destination: _labelFor(destinationCoord, _destinationAddress),
        currentStopCoord: currentStopCoord,
        destinationCoord: destinationCoord,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _parentService.selectedChild;
    final req = _service.studentActiveRequest.value;

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
                      AppTheme.purple.withValues(alpha: 0.18),
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
                            'Missed Bus',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (child != null)
                            Text(
                              child.name,
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
              ),

              // ── Body ─────────────────────────────────────────────────────
              Expanded(
                child: child == null
                    ? _NoChildState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: req == null
                            ? _ParentRequestForm(
                                child: child,
                                currentStopCoord: _currentStopCoord,
                                destinationCoord: _destinationCoord,
                                onCurrentStopPicked: (p) =>
                                    setState(() => _currentStopCoord = p),
                                onCurrentStopAddressResolved: (a) =>
                                    setState(() => _currentStopAddress = a),
                                onDestinationPicked: (p) =>
                                    setState(() => _destinationCoord = p),
                                onDestinationAddressResolved: (a) =>
                                    setState(() => _destinationAddress = a),
                                onSubmit: _submitRequest,
                              )
                            : _ParentStatusView(
                                request: req,
                                child: child,
                                pulse: _pulse,
                                onCancel: _service.cancelRequest,
                                onClear: _service.clearRequest,
                                onAcceptOffer: _service.acceptOffer,
                                onRejectOffer: _service.rejectOffer,
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

// ─── Form ─────────────────────────────────────────────────────────────────────
class _ParentRequestForm extends StatelessWidget {
  final ChildInfo child;
  final GeoCoord? currentStopCoord;
  final GeoCoord? destinationCoord;
  final ValueChanged<GeoCoord> onCurrentStopPicked;
  final ValueChanged<String?> onCurrentStopAddressResolved;
  final ValueChanged<GeoCoord> onDestinationPicked;
  final ValueChanged<String?> onDestinationAddressResolved;
  final VoidCallback onSubmit;

  const _ParentRequestForm({
    required this.child,
    required this.currentStopCoord,
    required this.destinationCoord,
    required this.onCurrentStopPicked,
    required this.onCurrentStopAddressResolved,
    required this.onDestinationPicked,
    required this.onDestinationAddressResolved,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final canSubmit = currentStopCoord != null && destinationCoord != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Child info card
        GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🧒', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${child.grade} · ${child.school}',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
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
        ),
        const SizedBox(height: 20),

        // Current stop — where to pick the child up from right now, dropped
        // on the map rather than trusting the stale registered stop label.
        Text(
          'Current Stop',
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        MapPointField(
          placeholder: 'Tap to pin where they are',
          value: currentStopCoord,
          onPicked: onCurrentStopPicked,
          onAddressResolved: onCurrentStopAddressResolved,
        ),
        const SizedBox(height: 16),

        // Missed bus
        Text(
          'Missed Bus',
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.cardBgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.surfaceBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.directions_bus_rounded,
                color: AppTheme.driverCyan,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                '${child.busNumber}  ·  ${child.route}',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Destination
        Text(
          'Destination',
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        MapPointField(
          placeholder: 'Tap to pin where they need to go',
          value: destinationCoord,
          onPicked: onDestinationPicked,
          onAddressResolved: onDestinationAddressResolved,
        ),
        const SizedBox(height: 32),

        // Submit
        GestureDetector(
          onTap: canSubmit ? onSubmit : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: canSubmit
                  ? const LinearGradient(
                      colors: [AppTheme.purple, Color(0xFF9333EA)],
                    )
                  : null,
              color: canSubmit ? null : context.cardBgElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.send_rounded,
                    color: canSubmit ? Colors.white : context.textTertiary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Request Pickup for ${child.name.split(' ').first}',
                    style: TextStyle(
                      color: canSubmit ? Colors.white : context.textTertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Status View ──────────────────────────────────────────────────────────────
class _ParentStatusView extends StatelessWidget {
  final MissedBusRequest request;
  final ChildInfo child;
  final Animation<double> pulse;
  final VoidCallback onCancel;
  final VoidCallback onClear;
  final VoidCallback onAcceptOffer;
  final VoidCallback onRejectOffer;

  const _ParentStatusView({
    required this.request,
    required this.child,
    required this.pulse,
    required this.onCancel,
    required this.onClear,
    required this.onAcceptOffer,
    required this.onRejectOffer,
  });

  @override
  Widget build(BuildContext context) {
    switch (request.status) {
      case RequestStatus.searching:
      case RequestStatus.viewing:
        return _ParentSearchingView(
          request: request,
          child: child,
          pulse: pulse,
          onCancel: onCancel,
        );
      case RequestStatus.bidOffered:
        return _ParentOfferReviewView(
          request: request,
          onAccept: onAcceptOffer,
          onReject: onRejectOffer,
        );
      case RequestStatus.accepted:
        return _ParentAcceptedView(request: request, onDone: onClear);
      case RequestStatus.noDrivers:
      case RequestStatus.declined:
        return _ParentNoDriversView(onTryAgain: onClear);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Searching / Viewing ───────────────────────────────────────────────────────
class _ParentSearchingView extends StatelessWidget {
  final MissedBusRequest request;
  final ChildInfo child;
  final Animation<double> pulse;
  final VoidCallback onCancel;

  const _ParentSearchingView({
    required this.request,
    required this.child,
    required this.pulse,
    required this.onCancel,
  });

  bool get _isViewing => request.status == RequestStatus.viewing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: pulse,
          builder: (_, _) => Transform.scale(
            scale: pulse.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purple.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppTheme.purple.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _isViewing ? '👀' : '🔍',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isViewing
              ? '${request.assignedDriverName ?? 'A driver'} is viewing your request…'
              : 'Searching for ${child.name.split(' ').first}\'s bus…',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isViewing
              ? 'Waiting for them to send a fare offer'
              : 'Looking for buses on ${request.assignedRoute}',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _JourneyRow(from: request.currentStop, to: request.destination),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.purple),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isViewing
                        ? '${request.assignedDriverName ?? 'Driver'} is viewing your request…'
                        : 'Alerting nearby drivers…',
                    style: TextStyle(
                      color: AppTheme.purple.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onCancel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: context.cardBgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.surfaceBorder),
            ),
            child: Text(
              'Cancel Request',
              style: TextStyle(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Offer Review ──────────────────────────────────────────────────────────────
class _ParentOfferReviewView extends StatelessWidget {
  final MissedBusRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ParentOfferReviewView({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          'Offer Received',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Review the driver\'s offer before confirming',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.driverCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      image: request.assignedDriverPhotoUrl == null
                          ? null
                          : DecorationImage(
                              image: NetworkImage(
                                request.assignedDriverPhotoUrl!,
                              ),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: request.assignedDriverPhotoUrl == null
                        ? const Center(
                            child: Text('🚍', style: TextStyle(fontSize: 22)),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.assignedDriverName ?? 'Driver',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          request.assignedBusNumber ?? '—',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'REQUESTED CHARGES',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.fareDisplay ?? '—',
                      style: const TextStyle(
                        color: AppTheme.warningLight,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JourneyRow(from: request.currentStop, to: request.destination),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onReject,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Reject',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: onAccept,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.success, Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Accept',
                      style: TextStyle(
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
        ),
      ],
    );
  }
}

// ─── Accepted ─────────────────────────────────────────────────────────────────
class _ParentAcceptedView extends StatelessWidget {
  final MissedBusRequest request;
  final VoidCallback onDone;

  const _ParentAcceptedView({required this.request, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Text('✅', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(
                'Pickup Confirmed!',
                style: TextStyle(
                  color: AppTheme.successLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${request.studentName.split(' ').first} will be picked up soon',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _InfoTile(
                icon: Icons.person_rounded,
                label: 'Driver',
                value: request.assignedDriverName ?? '—',
                color: AppTheme.driverCyan,
              ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.directions_bus_rounded,
                label: 'Bus',
                value: request.assignedBusNumber ?? '—',
                color: AppTheme.driverCyan,
              ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.access_time_rounded,
                label: 'ETA',
                value: request.assignedETA ?? '—',
                color: AppTheme.success,
              ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.call_rounded,
                label: 'Driver Phone',
                value: request.assignedDriverPhone ?? '—',
                color: AppTheme.purple,
              ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.payments_rounded,
                label: 'Fare (pay driver directly)',
                value: request.fareDisplay ?? 'Ask driver',
                color: AppTheme.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(16),
          child: _JourneyRow(
            from: request.currentStop,
            to: request.destination,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.purple, Color(0xFF9333EA)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── No Drivers ───────────────────────────────────────────────────────────────
class _ParentNoDriversView extends StatelessWidget {
  final VoidCallback onTryAgain;
  const _ParentNoDriversView({required this.onTryAgain});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text(
                'No Buses Available',
                style: TextStyle(
                  color: AppTheme.warningLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No nearby bus accepted the pickup request. Try again or contact the school.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onTryAgain,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.purple, Color(0xFF9333EA)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: context.cardBgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.surfaceBorder),
                ),
                child: Center(
                  child: Text(
                    'Contact School',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── No Child State ───────────────────────────────────────────────────────────
class _NoChildState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No child registered.',
        style: TextStyle(color: context.textSecondary, fontSize: 14),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _JourneyRow extends StatelessWidget {
  final String from;
  final String to;
  const _JourneyRow({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Row(
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
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                from,
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
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: AppTheme.purple,
            size: 20,
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
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                to,
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
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
