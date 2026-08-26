import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart' show GeoCoord;
import '../../app/language_provider.dart';
import '../../app/missed_bus_service.dart';
import '../../app/session_service.dart';
import '../../app/student_data_service.dart';
import '../../models/missed_bus_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/profile_form_fields.dart';

class MissedBusScreen extends StatefulWidget {
  const MissedBusScreen({super.key});

  @override
  State<MissedBusScreen> createState() => _MissedBusScreenState();
}

class _MissedBusScreenState extends State<MissedBusScreen>
    with SingleTickerProviderStateMixin {
  final _service = MissedBusService.instance;
  GeoCoord? _currentStopCoord;
  String? _currentStopAddress;
  GeoCoord? _destinationCoord;
  String? _destinationAddress;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_rebuild);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _service.studentActiveRequest.addListener(_rebuild);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_rebuild);
    _service.studentActiveRequest.removeListener(_rebuild);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// A human-readable label to persist for a picked point — the resolved
  /// address once reverse-geocoding catches up, or the raw coordinates as an
  /// honest fallback if the user submits before that finishes.
  String _labelFor(GeoCoord coord, String? address) =>
      address ??
      '${coord.lat.toStringAsFixed(6)}, ${coord.lng.toStringAsFixed(6)}';

  Future<void> _submitRequest() async {
    final currentStopCoord = _currentStopCoord;
    final destinationCoord = _destinationCoord;
    if (currentStopCoord == null || destinationCoord == null) return;
    final info = StudentDataService.instance.studentInfo.value;
    // The document field `MissedBusRepository` queries on is the real
    // Firestore student id, not `StudentInfo.studentId` (that's the
    // school-issued display number).
    final studentId = SessionService.instance.student.value?.id ?? '';
    if (studentId.isEmpty) return;
    try {
      await _service.raiseRequest(
        studentName: info.name,
        studentId: studentId,
        missedBusNumber: info.busNumber,
        assignedRoute: info.route,
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
    final req = _service.studentActiveRequest.value;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.error.withValues(alpha: 0.18),
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
                    Text(
                      AppStrings.t('missed_bus_title'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: req == null
                      ? _RequestForm(
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
                      : _RequestStateView(
                          request: req,
                          pulse: _pulse,
                          onCancel: _service.cancelRequest,
                          onClear: _service.clearRequest,
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

// ─── Request Form ─────────────────────────────────────────────────────────────
class _RequestForm extends StatelessWidget {
  final GeoCoord? currentStopCoord;
  final GeoCoord? destinationCoord;
  final ValueChanged<GeoCoord> onCurrentStopPicked;
  final ValueChanged<String?> onCurrentStopAddressResolved;
  final ValueChanged<GeoCoord> onDestinationPicked;
  final ValueChanged<String?> onDestinationAddressResolved;
  final VoidCallback onSubmit;

  const _RequestForm({
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
    final info = StudentDataService.instance.studentInfo.value;
    final canSubmit = currentStopCoord != null && destinationCoord != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alert banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🚌', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('missed_alert_title'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.t('missed_alert_subtitle'),
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
        const SizedBox(height: 24),

        // Current stop — where to pick you up from right now, dropped on the
        // map rather than trusting the stale registered stop label.
        Text(
          AppStrings.t('your_current_stop'),
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        MapPointField(
          placeholder: 'Tap to pin where you are',
          value: currentStopCoord,
          accentColor: AppTheme.studentAmber,
          onPicked: onCurrentStopPicked,
          onAddressResolved: onCurrentStopAddressResolved,
        ),
        const SizedBox(height: 20),

        // Missed bus (read-only)
        Text(
          AppStrings.t('missed_bus_title'),
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
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
                '${info.busNumber}  ·  ${info.route}',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Destination picker
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
          placeholder: 'Tap to pin where you need to go',
          value: destinationCoord,
          accentColor: AppTheme.studentAmber,
          onPicked: onDestinationPicked,
          onAddressResolved: onDestinationAddressResolved,
        ),
        const SizedBox(height: 32),

        // Submit button
        GestureDetector(
          onTap: canSubmit ? onSubmit : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: canSubmit
                  ? const LinearGradient(
                      colors: [AppTheme.error, Color(0xFFFF6B35)],
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
                    AppStrings.t('send_pickup_request'),
                    style: TextStyle(
                      color: canSubmit ? Colors.white : context.textTertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

// ─── State View (searching / accepted / noDrivers / declined) ─────────────────
class _RequestStateView extends StatelessWidget {
  final MissedBusRequest request;
  final Animation<double> pulse;
  final VoidCallback onCancel;
  final VoidCallback onClear;

  const _RequestStateView({
    required this.request,
    required this.pulse,
    required this.onCancel,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    switch (request.status) {
      case RequestStatus.searching:
        return _SearchingView(
          request: request,
          pulse: pulse,
          onCancel: onCancel,
        );
      case RequestStatus.accepted:
        return _AcceptedView(request: request, onDone: onClear);
      case RequestStatus.noDrivers:
      case RequestStatus.declined:
        return _NoDriversView(onTryAgain: onClear);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Searching ────────────────────────────────────────────────────────────────
class _SearchingView extends StatelessWidget {
  final MissedBusRequest request;
  final Animation<double> pulse;
  final VoidCallback onCancel;

  const _SearchingView({
    required this.request,
    required this.pulse,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Pulsing ring
        AnimatedBuilder(
          animation: pulse,
          builder: (_, _) => Transform.scale(
            scale: pulse.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.warning.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('🔍', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Searching for nearby buses…',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Looking for buses on ${request.assignedRoute} near ${request.currentStop}',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 32),

        // Journey summary card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _JourneyRow(from: request.currentStop, to: request.destination),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.warning),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Alerting nearby drivers…',
                    style: TextStyle(
                      color: AppTheme.warningLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Cancel
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

// ─── Accepted ─────────────────────────────────────────────────────────────────
class _AcceptedView extends StatelessWidget {
  final MissedBusRequest request;
  final VoidCallback onDone;

  const _AcceptedView({required this.request, required this.onDone});

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
              const SizedBox(height: 12),
              Text(
                'Driver Accepted!',
                style: TextStyle(
                  color: AppTheme.successLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your bus is on the way',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Driver / bus info
        GlassCard(
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
                label: 'Phone',
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

        // Journey
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: _JourneyRow(
            from: request.currentStop,
            to: request.destination,
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/student'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.driverCyan, AppTheme.driverTeal],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.gps_fixed_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Track Bus',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: context.cardBgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.surfaceBorder),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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

// ─── No Drivers ───────────────────────────────────────────────────────────────
class _NoDriversView extends StatelessWidget {
  final VoidCallback onTryAgain;
  const _NoDriversView({required this.onTryAgain});

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
                'No nearby bus on your route could accept the request at this time.',
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
                      colors: [AppTheme.error, Color(0xFFFF6B35)],
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
            color: AppTheme.driverCyan,
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
