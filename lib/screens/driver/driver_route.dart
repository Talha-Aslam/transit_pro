import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../app/language_provider.dart';
import '../../app/tracking_service.dart';
import '../../app/geofence_service.dart';
import '../../app/notification_service.dart';
import '../../models/route_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverRoute extends StatefulWidget {
  final VoidCallback onBack;
  const DriverRoute({super.key, required this.onBack});

  @override
  State<DriverRoute> createState() => _DriverRouteState();
}

class _DriverRouteState extends State<DriverRoute> {
  final _tracking = TrackingService.instance;
  final _geofence = GeofenceService.instance;
  final _notifSvc = NotificationService.instance;

  GoogleMapController? _mapController;
  String? _mapStyle;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _sharingLocation = true;
  bool _followCamera = true;
  BitmapDescriptor? _busIcon;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _notifSvc.init();

    rootBundle.loadString('assets/map_style.json').then((style) {
      _mapStyle = style;
      _mapController?.setMapStyle(style);
    });

    final route = MockRouteBuilder.buildMorningRoute();
    _tracking.start(route);

    _tracking.busPosition.addListener(_onBusPositionChanged);
    _geofence.alerts.addListener(_onGeofenceAlert);

    _createBusIcon().then((_) {
      _buildMapOverlays();
      if (mounted) setState(() {});
    });
  }

  /// Renders a cyan circle bus icon on a Flutter canvas and converts it to a
  /// [BitmapDescriptor] used as the live bus marker on the map.
  Future<void> _createBusIcon() async {
    const size = 52.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Filled circle
    canvas.drawCircle(
      const Offset(26, 26),
      22,
      Paint()..color = AppTheme.driverCyan,
    );
    // White border
    canvas.drawCircle(
      const Offset(26, 26),
      22,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Bus body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(10, 15, 42, 31),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );
    // Windows
    final winPaint = Paint()..color = AppTheme.driverCyan;
    for (final left in [13.0, 22.0, 31.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 17, left + 7, 23),
          const Radius.circular(2),
        ),
        winPaint,
      );
    }
    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawCircle(const Offset(17, 31), 4, wheelPaint);
    canvas.drawCircle(const Offset(33, 31), 4, wheelPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null && mounted) {
      _busIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    }
  }

  void _onLangChanged() => setState(() {});

  void _onBusPositionChanged() {
    _buildMapOverlays();
    _geofence.evaluate(_tracking.busPosition.value, _tracking.route.stops);
    if (_followCamera) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _tracking.busPosition.value,
            zoom: 15.5,
            bearing: _tracking.busHeading.value,
            tilt: 30,
          ),
        ),
      );
    }
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

    final markers = <Marker>{};
    for (final stop in route.stops) {
      markers.add(
        Marker(
          markerId: MarkerId(stop.name),
          position: stop.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(switch (stop.status) {
            StopStatus.completed => BitmapDescriptor.hueGreen,
            StopStatus.current => BitmapDescriptor.hueViolet,
            StopStatus.upcoming => BitmapDescriptor.hueCyan,
            StopStatus.destination => BitmapDescriptor.hueOrange,
          }),
          infoWindow: InfoWindow(
            title: stop.name,
            snippet: '${stop.scheduledTime} · ${stop.studentCount} students',
          ),
        ),
      );
    }

    markers.add(
      Marker(
        markerId: const MarkerId('bus'),
        position: busPos,
        icon:
            _busIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        rotation: _tracking.busHeading.value,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: '🚌 Your Bus'),
        zIndex: 10,
      ),
    );

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: route.polylinePoints,
        color: const Color(0xFF0EA5E9),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };

    final completedIdx = _tracking.waypointIndex;
    if (completedIdx > 0) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('completed'),
          points: route.polylinePoints.sublist(
            0,
            (completedIdx + 1).clamp(0, route.polylinePoints.length),
          ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.driverCyan.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(onTap: widget.onBack, child: _backBtn(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('route_navigator'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _tracking.route.name,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
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
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppTheme.successLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Google Map ─────────────────────────────────────────
                GlassCard(
                  backgroundColor: const Color(0xCC05081E),
                  borderRadius: 20,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.t('live_route_map'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                // Follow-camera toggle
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _followCamera = !_followCamera,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _followCamera
                                          ? AppTheme.driverCyan.withOpacity(0.2)
                                          : const Color(0x10FFFFFF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _followCamera
                                            ? AppTheme.driverCyan
                                            : const Color(0x20FFFFFF),
                                      ),
                                    ),
                                    child: Text(
                                      _followCamera ? '📍 Follow' : '🗺 Free',
                                      style: TextStyle(
                                        color: _followCamera
                                            ? AppTheme.driverCyan
                                            : Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  '⚡ ',
                                  style: TextStyle(fontSize: 13),
                                ),
                                ValueListenableBuilder<int>(
                                  valueListenable: _tracking.speed,
                                  builder: (_, spd, __) => Text(
                                    '$spd km/h',
                                    style: const TextStyle(
                                      color: AppTheme.driverAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0x10FFFFFF), height: 1),
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: SizedBox(
                          height: 320,
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
                              label: 'Completed',
                            ),
                            const SizedBox(width: 14),
                            _LegendDot(
                              color: AppTheme.purple,
                              label: 'Current',
                            ),
                            const SizedBox(width: 14),
                            _LegendDot(color: AppTheme.info, label: 'Next'),
                            const SizedBox(width: 14),
                            _LegendDot(
                              color: AppTheme.warning,
                              label: 'School',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Location sharing toggle ───────────────────────────
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _sharingLocation
                                ? Icons.location_on
                                : Icons.location_off,
                            color: _sharingLocation
                                ? AppTheme.success
                                : context.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Share Location',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _sharingLocation,
                        activeColor: AppTheme.success,
                        onChanged: (v) => setState(() => _sharingLocation = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Live stats bar ────────────────────────────────────
                Row(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: _tracking.etaMinutes,
                      builder: (_, eta, __) => _LiveStatCard(
                        icon: '⏱️',
                        label: AppStrings.t('eta_school'),
                        value: '$eta min',
                      ),
                    ),
                    const SizedBox(width: 10),
                    _LiveStatCard(
                      icon: '📏',
                      label: AppStrings.t('distance_left'),
                      value: '4.2 km',
                    ),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: _tracking.speed,
                      builder: (_, spd, __) => _LiveStatCard(
                        icon: '⚡',
                        label: AppStrings.t('avg_speed'),
                        value: '$spd km/h',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Route stops ───────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route Stops',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._tracking.route.stops.asMap().entries.map(
                        (e) => _StopRow(
                          stop: e.value,
                          isLast: e.key == _tracking.route.stops.length - 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Action buttons ────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _tracking.markCurrentStopDone();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.driverGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '✅  Mark Stop Done',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.warning.withOpacity(0.3),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '⚠️  Report Issue',
                            style: TextStyle(
                              color: AppTheme.warningLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _LiveStatCard extends StatelessWidget {
  final String icon, label, value;
  const _LiveStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

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
          style: TextStyle(color: context.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final StopData stop;
  final bool isLast;
  const _StopRow({required this.stop, required this.isLast});

  Color get _color => switch (stop.status) {
    StopStatus.completed => AppTheme.success,
    StopStatus.current => AppTheme.purple,
    StopStatus.destination => AppTheme.warning,
    _ => AppTheme.info,
  };

  String get _icon => switch (stop.status) {
    StopStatus.completed => '✓',
    StopStatus.destination => '🏫',
    _ => '📍',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color, width: 2),
                  boxShadow: stop.status == StopStatus.current
                      ? [
                          BoxShadow(
                            color: _color.withOpacity(0.5),
                            blurRadius: 12,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Text(_icon, style: const TextStyle(fontSize: 13)),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
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
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stop.name,
                          style: TextStyle(
                            color:
                                stop.status == StopStatus.current ||
                                    stop.status == StopStatus.destination
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
                              'NEXT',
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
                    if (stop.note != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.note!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stop.scheduledTime,
                      style: TextStyle(
                        color: switch (stop.status) {
                          StopStatus.completed => AppTheme.successLight,
                          StopStatus.current => AppTheme.parentAccent,
                          StopStatus.destination => AppTheme.warning,
                          _ => AppTheme.driverAccent,
                        },
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (stop.studentCount > 0)
                      Text(
                        '👦 ${stop.studentCount}',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _backBtn(BuildContext context) => Container(
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
      style: TextStyle(color: context.textPrimary, fontSize: 16),
    ),
  ),
);
