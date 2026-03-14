import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _mapStyle;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);

    _notifSvc.init();

    // Load dark map style
    rootBundle.loadString('assets/map_style.json').then((style) {
      _mapStyle = style;
      _mapController?.setMapStyle(style);
    });

    // Initialise route & tracking
    final route = MockRouteBuilder.buildMorningRoute();
    _tracking.start(route);

    // Listen to bus position updates
    _tracking.busPosition.addListener(_onBusPositionChanged);
    _geofence.alerts.addListener(_onGeofenceAlert);

    // Build initial markers & polylines
    _buildMapOverlays();
  }

  void _onLangChanged() => setState(() {});

  void _onBusPositionChanged() {
    _buildMapOverlays();
    _geofence.evaluate(_tracking.busPosition.value, _tracking.route.stops);
    setState(() {});
  }

  void _onGeofenceAlert() {
    final alerts = _geofence.alerts.value;
    if (alerts.isNotEmpty) {
      _notifSvc.fromGeofence(alerts.last);
    }
  }

  void _buildMapOverlays() {
    final route = _tracking.route;
    final busPos = _tracking.busPosition.value;

    // Markers for stops
    final markers = <Marker>{};
    for (final stop in route.stops) {
      markers.add(
        Marker(
          markerId: MarkerId(stop.name),
          position: stop.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(switch (stop.status) {
            StopStatus.completed => BitmapDescriptor.hueGreen,
            StopStatus.current => BitmapDescriptor.hueViolet,
            StopStatus.upcoming => BitmapDescriptor.hueAzure,
            StopStatus.destination => BitmapDescriptor.hueOrange,
          }),
          infoWindow: InfoWindow(title: stop.name, snippet: stop.scheduledTime),
        ),
      );
    }

    // Bus marker
    markers.add(
      Marker(
        markerId: const MarkerId('bus'),
        position: busPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        rotation: _tracking.busHeading.value,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: '🚌 Bus #42'),
        zIndex: 10,
      ),
    );

    // Route polyline
    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: route.polylinePoints,
        color: const Color(0xFF7C3AED),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };

    // Completed portion (solid green)
    final completedIdx = route.polylinePoints.indexWhere(
      (p) => p.latitude == busPos.latitude && p.longitude == busPos.longitude,
    );
    if (completedIdx > 0) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('completed'),
          points: route.polylinePoints.sublist(0, completedIdx + 1),
          color: const Color(0xFF10B981),
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
            final safeIdx = children.isEmpty
                ? 0
                : selIdx.clamp(0, children.length - 1);
            final child = children.isEmpty ? null : children[safeIdx];

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.parentPurple.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onBack,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('live_tracking'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                child == null
                                    ? ''
                                    : '${child.busNumber} · ${child.route}',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _LiveBadge(tracking: _tracking),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // ── ETA Banner ──────────────────────────────────
                        ValueListenableBuilder<int>(
                          valueListenable: _tracking.etaMinutes,
                          builder: (_, eta, __) => GlassCard(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.parentPurple.withOpacity(0.2),
                                AppTheme.info.withOpacity(0.1),
                              ],
                            ),
                            borderColor: AppTheme.parentPurple.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ESTIMATED ARRIVAL',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '$eta',
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'min',
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'ARRIVAL TIME',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '07:45 AM',
                                      style: TextStyle(
                                        color: AppTheme.parentAccent,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Google Map ───────────────────────────────────
                        GlassCard(
                          backgroundColor: const Color(0xCC0A0F28),
                          borderRadius: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  10,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppStrings.t('route_map'),
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _tracking.toggleLive,
                                      child: ValueListenableBuilder<bool>(
                                        valueListenable: _tracking.isLive,
                                        builder: (_, live, __) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: live
                                                ? AppTheme.success.withOpacity(
                                                    0.2,
                                                  )
                                                : AppTheme.info.withOpacity(
                                                    0.15,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: live
                                                  ? AppTheme.success
                                                        .withOpacity(0.4)
                                                  : AppTheme.info.withOpacity(
                                                      0.3,
                                                    ),
                                            ),
                                          ),
                                          child: Text(
                                            live
                                                ? '📡 Live GPS'
                                                : '🔄 Simulated',
                                            style: TextStyle(
                                              color: live
                                                  ? AppTheme.successLight
                                                  : AppTheme.info,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                color: Color(0x10FFFFFF),
                                height: 1,
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                child: SizedBox(
                                  height: 240,
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: _tracking.busPosition.value,
                                      zoom: 13.5,
                                    ),
                                    markers: _markers,
                                    polylines: _polylines,
                                    myLocationEnabled: false,
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                    compassEnabled: false,
                                    trafficEnabled: true,
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                      if (_mapStyle != null) {
                                        controller.setMapStyle(_mapStyle!);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    _LegendDot(
                                      color: AppTheme.success,
                                      label: AppStrings.t('completed'),
                                    ),
                                    const SizedBox(width: 16),
                                    _LegendDot(
                                      color: AppTheme.purple,
                                      label: AppStrings.t('current'),
                                    ),
                                    const SizedBox(width: 16),
                                    _LegendDot(
                                      color: AppTheme.info,
                                      label: AppStrings.t('upcoming'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Route Stops ─────────────────────────────────
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('route_stops'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ..._tracking.route.stops.asMap().entries.map(
                                (e) => _StopRow(
                                  stop: e.value,
                                  isLast:
                                      e.key == _tracking.route.stops.length - 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Bus Info ────────────────────────────────────
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('bus_information'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.5,
                                children: [
                                  _InfoCard(
                                    icon: '👨‍✈️',
                                    label: AppStrings.t('driver'),
                                    value: child?.driver ?? 'N/A',
                                  ),
                                  _InfoCard(
                                    icon: '🚌',
                                    label: AppStrings.t('bus_number'),
                                    value: child?.busNumber ?? 'N/A',
                                  ),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _tracking.speed,
                                    builder: (_, spd, __) => _InfoCard(
                                      icon: '⚡',
                                      label: AppStrings.t('speed'),
                                      value: '$spd km/h',
                                    ),
                                  ),
                                  _InfoCard(
                                    icon: '👦',
                                    label: AppStrings.t('students'),
                                    value: '22 onboard',
                                  ),
                                ],
                              ),
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

// ── Live Badge ─────────────────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  final TrackingService tracking;
  const _LiveBadge({required this.tracking});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: tracking.isSimulating,
      builder: (_, sim, __) => ValueListenableBuilder<bool>(
        valueListenable: tracking.isLive,
        builder: (_, live, __) => Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withOpacity(0.6),
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

// ── Stop Row ───────────────────────────────────────────────────────────────────
class _StopRow extends StatelessWidget {
  final StopData stop;
  final bool isLast;
  const _StopRow({required this.stop, required this.isLast});

  Color get _color => switch (stop.status) {
    StopStatus.completed => AppTheme.success,
    StopStatus.current => AppTheme.purple,
    StopStatus.upcoming => AppTheme.info,
    StopStatus.destination => AppTheme.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color, width: 2),
                  boxShadow: stop.status == StopStatus.current
                      ? [
                          BoxShadow(
                            color: _color.withOpacity(0.4),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: stop.status == StopStatus.completed
                      ? Text(
                          '✓',
                          style: TextStyle(
                            color: _color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : stop.status == StopStatus.destination
                      ? const Text('🏫', style: TextStyle(fontSize: 12))
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: stop.status == StopStatus.completed
                      ? AppTheme.success.withOpacity(0.4)
                      : context.cardBgElevated,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      stop.name,
                      style: TextStyle(
                        color: stop.status == StopStatus.current
                            ? context.textPrimary
                            : context.textSecondary,
                        fontSize: 14,
                        fontWeight: stop.status == StopStatus.current
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (stop.status == StopStatus.current) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.purple.withOpacity(0.4),
                          ),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            color: AppTheme.parentAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  stop.scheduledTime,
                  style: TextStyle(
                    color: stop.status == StopStatus.completed
                        ? AppTheme.successLight
                        : stop.status == StopStatus.current
                        ? AppTheme.parentAccent
                        : context.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Legend Dot ──────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Info Card ──────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String icon, label, value;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: context.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
