import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../app/tracking_service.dart';
import '../../app/geofence_service.dart';
import '../../app/notification_service.dart';
import '../../models/route_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentTracking extends StatefulWidget {
  final VoidCallback onBack;
  const ParentTracking({super.key, required this.onBack});

  @override
  State<ParentTracking> createState() => _ParentTrackingState();
}

class _ParentTrackingState extends State<ParentTracking> {
  final _tracking = TrackingService.instance;
  final _geofence = GeofenceService.instance;
  final _notifSvc = NotificationService.instance;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _tracking.busPosition.addListener(_onBusPositionChanged);
    _geofence.alerts.addListener(_onGeofenceAlert);

    // Start simulation if not running (Ensures _tracking.route is initialized)
    if (!_tracking.isMoving.value) {
      final route = MockRouteBuilder.buildMorningRoute();
      _tracking.start(route);
    }

    // Initial overlays (Needs _tracking.route)
    _buildMapOverlays(ParentDataService.instance.currentChild);

    // Load map style
    DefaultAssetBundle.of(context).loadString('assets/map_style.json').then((
      s,
    ) {
      if (mounted) setState(() => _mapStyle = s);
    });
  }

  void _onLangChanged() => setState(() {});

  void _onBusPositionChanged() {
    _buildMapOverlays(ParentDataService.instance.currentChild);
    _geofence.evaluate(_tracking.busPosition.value, _tracking.route.stops);
    if (mounted) setState(() {});
  }

  void _onGeofenceAlert() {
    final alerts = _geofence.alerts.value;
    if (alerts.isNotEmpty) {
      _notifSvc.fromGeofence(alerts.last);
    }
  }

  void _buildMapOverlays(ChildInfo? child) {
    final route = _tracking.route;
    final busPos = _tracking.busPosition.value;
    final studentStopName = child?.stop ?? '';

    // Markers
    final markers = <Marker>{};
    for (final stop in route.stops) {
      final isStudentStop = stop.name == studentStopName;
      markers.add(
        Marker(
          markerId: MarkerId(stop.name),
          position: stop.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isStudentStop
                ? BitmapDescriptor.hueYellow
                : switch (stop.status) {
                    StopStatus.completed => BitmapDescriptor.hueGreen,
                    StopStatus.current => BitmapDescriptor.hueViolet,
                    StopStatus.upcoming => BitmapDescriptor.hueAzure,
                    StopStatus.destination => BitmapDescriptor.hueOrange,
                  },
          ),
          infoWindow: InfoWindow(
            title: isStudentStop ? '📍 ${stop.name} (Stop)' : stop.name,
            snippet: stop.scheduledTime,
          ),
        ),
      );
    }

    // Bus marker (Yellow/Amber per student system)
    markers.add(
      Marker(
        markerId: const MarkerId('bus'),
        position: busPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        rotation: _tracking.busHeading.value,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: '🚌 ${route.busNumber}'),
        zIndexInt: 10,
      ),
    );

    // Polylines
    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: route.polylinePoints,
        color: AppTheme.studentAmber.withValues(alpha: 0.3),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };

    final completedIdx = route.polylinePoints.indexWhere(
      (p) => p.latitude == busPos.latitude && p.longitude == busPos.longitude,
    );
    if (completedIdx > 0) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('completed'),
          points: route.polylinePoints.sublist(0, completedIdx + 1),
          color: AppTheme.success,
          width: 5,
        ),
      );
    }

    _markers = markers;
    _polylines = polylines;
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _tracking.busPosition.removeListener(_onBusPositionChanged);
    _geofence.alerts.removeListener(_onGeofenceAlert);
    _tracking.stop();
    _geofence.reset();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ParentDataService.instance;

    return ValueListenableBuilder<List<ChildInfo>>(
      valueListenable: svc.children,
      builder: (context, children, _) {
        return ValueListenableBuilder<int>(
          valueListenable: svc.selectedChildIndex,
          builder: (context, selIdx, _) {
            final child = svc.currentChild;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  _Header(
                    title: AppStrings.t('live_tracking'),
                    onBack: widget.onBack,
                    child: child,
                    children: children,
                    onChildSelected: (idx) {
                      svc.selectedChildIndex.value = idx;
                      _buildMapOverlays(svc.currentChild);
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // ── Google Map ─────────────────────────────────
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              height: 220,
                              child: Stack(
                                children: [
                                  GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: _tracking.busPosition.value,
                                      zoom: 13.5,
                                    ),
                                    style: _mapStyle,
                                    markers: _markers,
                                    polylines: _polylines,
                                    myLocationEnabled: false,
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                    compassEnabled: false,
                                    trafficEnabled: true,
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                    },
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: _LiveBadge(tracking: _tracking),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '📍 ${child?.route ?? "Route A"}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: _tracking.toggleLive,
                                      child: ValueListenableBuilder<bool>(
                                        valueListenable: _tracking.isLive,
                                        builder: (_, live, _) => Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            live
                                                ? Icons.gps_fixed
                                                : Icons.gps_off,
                                            color: live
                                                ? AppTheme.success
                                                : Colors.white70,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Bus status ──────────────────────────────────
                        GlassCard(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.success.withValues(alpha: 0.12),
                              AppTheme.success.withValues(alpha: 0.04),
                            ],
                          ),
                          borderColor: AppTheme.success.withValues(alpha: 0.2),
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.studentGradient,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🚌',
                                    style: TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (_) {
                                        final assignment = [
                                          child?.busNumber ?? '',
                                          child?.route ?? '',
                                        ]
                                            .where((s) => s.isNotEmpty)
                                            .join(' · ');
                                        return Text(
                                          assignment.isEmpty
                                              ? 'No bus assigned yet'
                                              : assignment,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${AppStrings.t('driver')}: ${child?.driver ?? "N/A"}',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                label: AppStrings.t('on_time'),
                                color: AppTheme.success,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Stat Row ────────────────────────────────────
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable: _tracking.speed,
                                builder: (_, spd, _) => _StatChip(
                                  icon: '⚡',
                                  label: AppStrings.t('speed'),
                                  value: '$spd km/h',
                                  color: AppTheme.info,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: context.surfaceBorder,
                              ),
                              ValueListenableBuilder<int>(
                                valueListenable: _tracking.etaMinutes,
                                builder: (_, eta, _) => _StatChip(
                                  icon: '⏱️',
                                  label: 'ETA',
                                  value: '$eta min',
                                  color: AppTheme.studentAmber,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: context.surfaceBorder,
                              ),
                              _StatChip(
                                icon: '🚏',
                                label: AppStrings.t('stops_left'),
                                value:
                                    '${_tracking.route.stops.where((s) => s.status == StopStatus.upcoming || s.status == StopStatus.destination).length}',
                                color: AppTheme.purple,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Route progress ──────────────────────────────
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('route_progress'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ..._tracking.route.stops.asMap().entries.map((
                                entry,
                              ) {
                                final idx = entry.key;
                                final stop = entry.value;
                                final isLast =
                                    idx == _tracking.route.stops.length - 1;
                                final isYourStop = stop.name == child?.stop;

                                return _StopTimelineItem(
                                  name: stop.name,
                                  time: stop.scheduledTime,
                                  status: stop.status,
                                  isLast: isLast,
                                  isYourStop: isYourStop,
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final ChildInfo? child;
  final List<ChildInfo> children;
  final Function(int) onChildSelected;

  const _Header({
    required this.title,
    required this.onBack,
    required this.child,
    required this.children,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.cardBgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.inputBorder),
                  ),
                  child: Center(
                    child: Text(
                      '←',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (children.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: children.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final isSelected = children[idx].name == child?.name;
                  return GestureDetector(
                    onTap: () => onChildSelected(idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.parentPurple.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.parentPurple
                              : context.surfaceBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          children[idx].name,
                          style: TextStyle(
                            color: isSelected
                                ? context.textPrimary
                                : context.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 10),
        ),
      ],
    );
  }
}

class _StopTimelineItem extends StatelessWidget {
  final String name, time;
  final StopStatus status;
  final bool isLast;
  final bool isYourStop;

  const _StopTimelineItem({
    required this.name,
    required this.time,
    required this.status,
    required this.isLast,
    required this.isYourStop,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = status == StopStatus.completed;
    final bool isCurrent = status == StopStatus.current;
    final bool isPastOrCurrent = isCompleted || isCurrent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline line and dot ──────────────────────────────────────────
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Top line (connector)
                // Container(width: 2, height: 4, color: isPastOrCurrent ? AppTheme.success : context.surfaceBorder),
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isPastOrCurrent
                        ? AppTheme.success
                        : context.surfaceBorder,
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      // The line below should only be green if NEXT is completed/current.
                      // But for simplicity in a stateless widget without next-stop context,
                      // we use isCompleted as a proxy.
                      color: isCompleted
                          ? AppTheme.success
                          : context.surfaceBorder.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // ── Name and Time ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isYourStop
                          ? "$name (${AppStrings.t('your_stop')})"
                          : name,
                      style: TextStyle(
                        color: (isYourStop || isCurrent)
                            ? context.textPrimary
                            : context.textSecondary,
                        fontSize: 15,
                        fontWeight: (isYourStop || isCurrent)
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final TrackingService tracking;
  const _LiveBadge({required this.tracking});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: tracking.isSimulating,
      builder: (_, sim, _) => ValueListenableBuilder<bool>(
        valueListenable: tracking.isLive,
        builder: (_, live, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              live ? 'GPS' : (sim ? 'LIVE' : ''),
              style: const TextStyle(
                color: AppTheme.successLight,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
