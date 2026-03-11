import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../app/missed_bus_service.dart';
import '../../app/student_data_service.dart';
import '../../models/missed_bus_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class MissedBusScreen extends StatefulWidget {
  const MissedBusScreen({super.key});

  @override
  State<MissedBusScreen> createState() => _MissedBusScreenState();
}

class _MissedBusScreenState extends State<MissedBusScreen>
    with SingleTickerProviderStateMixin {
  final _service = MissedBusService.instance;
  String? _selectedDestination;
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

  void _submitRequest() {
    if (_selectedDestination == null) return;
    final info = StudentDataService.instance.studentInfo.value;
    _service.raiseRequest(
      studentName: info.name,
      studentId: info.studentId,
      missedBusNumber: info.busNumber,
      assignedRoute: info.route,
      currentStop: info.stop,
      destination: _selectedDestination!,
    );
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
                      AppTheme.error.withOpacity(0.18),
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
                      'Missed Bus',
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
                          selectedDestination: _selectedDestination,
                          onDestinationChanged: (v) =>
                              setState(() => _selectedDestination = v),
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
  final String? selectedDestination;
  final ValueChanged<String?> onDestinationChanged;
  final VoidCallback onSubmit;

  const _RequestForm({
    required this.selectedDestination,
    required this.onDestinationChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final info = StudentDataService.instance.studentInfo.value;
    final stops = MissedBusService.routeStops
        .where((s) => s != info.stop)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alert banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.15),
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
                      'Missed your bus?',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Send a request to nearby buses on the same route.',
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

        // Current stop (read-only)
        Text(
          'Your Current Stop',
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
              Icon(Icons.location_on_rounded, color: AppTheme.error, size: 18),
              const SizedBox(width: 10),
              Text(
                info.stop,
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

        // Missed bus (read-only)
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selectedDestination != null
                  ? AppTheme.driverCyan.withOpacity(0.5)
                  : context.inputBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedDestination,
              hint: Text(
                'Select your destination',
                style: TextStyle(color: context.textHint, fontSize: 14),
              ),
              isExpanded: true,
              dropdownColor: context.cardBg,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: context.textSecondary,
              ),
              items: stops
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onDestinationChanged,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Submit button
        GestureDetector(
          onTap: selectedDestination != null ? onSubmit : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: selectedDestination != null
                  ? const LinearGradient(
                      colors: [AppTheme.error, Color(0xFFFF6B35)],
                    )
                  : null,
              color: selectedDestination == null
                  ? context.cardBgElevated
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.send_rounded,
                    color: selectedDestination != null
                        ? Colors.white
                        : context.textTertiary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Send Pickup Request',
                    style: TextStyle(
                      color: selectedDestination != null
                          ? Colors.white
                          : context.textTertiary,
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
          builder: (_, __) => Transform.scale(
            scale: pulse.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.warning.withOpacity(0.15),
                border: Border.all(
                  color: AppTheme.warning.withOpacity(0.4),
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
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
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
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
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
            color: color.withOpacity(0.12),
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
