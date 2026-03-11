import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/missed_bus_service.dart';
import '../../app/parent_data_service.dart';
import '../../models/missed_bus_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentMissedBusScreen extends StatefulWidget {
  const ParentMissedBusScreen({super.key});

  @override
  State<ParentMissedBusScreen> createState() => _ParentMissedBusScreenState();
}

class _ParentMissedBusScreenState extends State<ParentMissedBusScreen>
    with SingleTickerProviderStateMixin {
  final _service = MissedBusService.instance;
  final _parentService = ParentDataService.instance;
  String? _selectedDestination;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
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

  void _submitRequest() {
    if (_selectedDestination == null) return;
    final child = _parentService.selectedChild;
    if (child == null) return;
    _service.raiseRequest(
      studentName: child.name,
      studentId: 'STU-PARENT',
      missedBusNumber: child.busNumber,
      assignedRoute: child.route,
      currentStop: child.stop,
      destination: _selectedDestination!,
    );
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
                      AppTheme.purple.withOpacity(0.18),
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
                          Text('Missed Bus',
                              style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          if (child != null)
                            Text(child.name,
                                style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12)),
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
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: req == null
                            ? _ParentRequestForm(
                                child: child,
                                selectedDestination: _selectedDestination,
                                onDestinationChanged: (v) =>
                                    setState(() => _selectedDestination = v),
                                onSubmit: _submitRequest,
                              )
                            : _ParentStatusView(
                                request: req,
                                child: child,
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

// ─── Form ─────────────────────────────────────────────────────────────────────
class _ParentRequestForm extends StatelessWidget {
  final ChildInfo child;
  final String? selectedDestination;
  final ValueChanged<String?> onDestinationChanged;
  final VoidCallback onSubmit;

  const _ParentRequestForm({
    required this.child,
    required this.selectedDestination,
    required this.onDestinationChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final stops = MissedBusService.routeStops
        .where((s) => s != child.stop)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Child info card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                    child: Text('🧒', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name,
                        style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(
                      '${child.grade} · ${child.school}',
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('MISSED BUS',
                    style: TextStyle(
                        color: AppTheme.warningLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Assigned stop
        Text('Current Stop',
            style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.cardBgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.surfaceBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_rounded,
                  color: AppTheme.purple, size: 18),
              const SizedBox(width: 10),
              Text(child.stop,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Missed bus
        Text('Missed Bus',
            style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.cardBgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.surfaceBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_bus_rounded,
                  color: AppTheme.driverCyan, size: 18),
              const SizedBox(width: 10),
              Text('${child.busNumber}  ·  ${child.route}',
                  style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Destination
        Text('Destination',
            style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selectedDestination != null
                  ? AppTheme.purple.withOpacity(0.5)
                  : context.inputBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedDestination,
              hint: Text('Select destination',
                  style: TextStyle(
                      color: context.textHint, fontSize: 14)),
              isExpanded: true,
              dropdownColor: context.cardBg,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: context.textSecondary),
              items: stops
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s,
                            style: TextStyle(
                                color: context.textPrimary, fontSize: 14)),
                      ))
                  .toList(),
              onChanged: onDestinationChanged,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Submit
        GestureDetector(
          onTap: selectedDestination != null ? onSubmit : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: selectedDestination != null
                  ? const LinearGradient(
                      colors: [AppTheme.purple, Color(0xFF9333EA)])
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
                  Icon(Icons.send_rounded,
                      color: selectedDestination != null
                          ? Colors.white
                          : context.textTertiary,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Request Pickup for ${child.name.split(' ').first}',
                    style: TextStyle(
                        color: selectedDestination != null
                            ? Colors.white
                            : context.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
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

  const _ParentStatusView({
    required this.request,
    required this.child,
    required this.pulse,
    required this.onCancel,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    switch (request.status) {
      case RequestStatus.searching:
        return _ParentSearchingView(
            request: request, child: child, pulse: pulse, onCancel: onCancel);
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

// ─── Searching ────────────────────────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Transform.scale(
            scale: pulse.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purple.withOpacity(0.15),
                border: Border.all(
                    color: AppTheme.purple.withOpacity(0.4), width: 2),
              ),
              child: const Center(
                  child: Text('🔍', style: TextStyle(fontSize: 40))),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Searching for ${child.name.split(' ').first}\'s bus…',
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Looking for buses on ${request.assignedRoute}',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _JourneyRow(
                  from: request.currentStop, to: request.destination),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(AppTheme.purple),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Alerting nearby drivers…',
                      style: TextStyle(
                          color: AppTheme.purple.withOpacity(0.8),
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onCancel,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: context.cardBgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.surfaceBorder),
            ),
            child: Text('Cancel Request',
                style: TextStyle(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
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
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Text('✅', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text('Pickup Confirmed!',
                  style: TextStyle(
                      color: AppTheme.successLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${request.studentName.split(' ').first} will be picked up soon',
                  style: TextStyle(
                      color: context.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                label: 'Driver Phone',
                value: request.assignedDriverPhone ?? '—',
                color: AppTheme.purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: _JourneyRow(
              from: request.currentStop, to: request.destination),
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
                    colors: [AppTheme.purple, Color(0xFF9333EA)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Done',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
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
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text('No Buses Available',
                  style: TextStyle(
                      color: AppTheme.warningLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'No nearby bus accepted the pickup request. Try again or contact the school.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.textSecondary, fontSize: 13),
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
                        colors: [AppTheme.purple, Color(0xFF9333EA)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Try Again',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
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
                  child: Text('Contact School',
                      style: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
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
      child: Text('No child registered.',
          style: TextStyle(color: context.textSecondary, fontSize: 14)),
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
              Text('FROM',
                  style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(from,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded,
              color: AppTheme.purple, size: 20),
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
                      letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(to,
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
            Text(label,
                style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ],
    );
  }
}
