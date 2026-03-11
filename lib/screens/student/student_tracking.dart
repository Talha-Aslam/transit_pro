import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../app/language_provider.dart';
import '../../app/tracking_service.dart';
import '../../models/route_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StudentTracking extends StatefulWidget {
  final VoidCallback onBack;
  const StudentTracking({super.key, required this.onBack});
  @override
  State<StudentTracking> createState() => _StudentTrackingState();
}

class _StudentTrackingState extends State<StudentTracking> {
  final _tracking = TrackingService.instance;

  GoogleMapController? _mapController;
  String? _mapStyle;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);

    rootBundle.loadString('assets/map_style.json').then((style) {
      _mapStyle = style;
      _mapController?.setMapStyle(style);
    });

    final route = MockRouteBuilder.buildMorningRoute();
    _tracking.start(route);
    _tracking.busPosition.addListener(_onBusPositionChanged);
    _buildMapOverlays();
  }

  void _onLangChanged() => setState(() {});

  void _onBusPositionChanged() {
    _buildMapOverlays();
    setState(() {});
  }

  void _buildMapOverlays() {
    final route = _tracking.route;
    final busPos = _tracking.busPosition.value;

    final markers = <Marker>{};

    // Student's stop highlighted
    const studentStopName = 'Pine Road';

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
            title: isStudentStop ? '📍 ${stop.name} (Your Stop)' : stop.name,
            snippet: stop.scheduledTime,
          ),
        ),
      );
    }

    markers.add(
      Marker(
        markerId: const MarkerId('bus'),
        position: busPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        rotation: _tracking.busHeading.value,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: '🚌 Bus #42'),
        zIndex: 10,
      ),
    );

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: route.polylinePoints,
        color: const Color(0xFFF59E0B),
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
    _tracking.stop();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          _Header(title: AppStrings.t('track_my_bus'), onBack: widget.onBack),
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
                          // Status overlay
                          Positioned(
                            top: 12,
                            right: 12,
                            child: StatusBadge(
                              label: '● LIVE',
                              color: AppTheme.success,
                            ),
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
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '📍 Pine Road → School',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
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
                      AppTheme.success.withOpacity(0.12),
                      AppTheme.success.withOpacity(0.04),
                    ],
                  ),
                  borderColor: AppTheme.success.withOpacity(0.2),
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
                          child: Text('🚌', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_tracking.route.busNumber} · Route A',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Driver: ${_tracking.route.driverName}',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: 'On Time', color: AppTheme.success),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── ETA info ────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _tracking.etaMinutes,
                        builder: (_, eta, __) => _ETAInfo(
                          icon: '⏱️',
                          label: 'ETA',
                          value: '$eta min',
                          color: AppTheme.studentAmber,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      _ETAInfo(
                        icon: '📏',
                        label: AppStrings.t('distance'),
                        value: '2.4 km',
                        color: AppTheme.info,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      _ETAInfo(
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
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('route_progress'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._tracking.route.stops.map(
                        (stop) => _StopItem(
                          name: stop.name == 'Pine Road'
                              ? '${stop.name} (Your Stop)'
                              : stop.name,
                          time: stop.scheduledTime,
                          status: switch (stop.status) {
                            StopStatus.completed => 'passed',
                            StopStatus.current => 'current',
                            _ => 'upcoming',
                          },
                          color: switch (stop.status) {
                            StopStatus.completed => AppTheme.success,
                            StopStatus.current => AppTheme.studentAmber,
                            _ => Colors.white24,
                          },
                        ),
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
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _Header({required this.title, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
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
                  style: TextStyle(color: context.textPrimary, fontSize: 18),
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
    );
  }
}

class _ETAInfo extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _ETAInfo({
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
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _StopItem extends StatelessWidget {
  final String name, time, status;
  final Color color;
  const _StopItem({
    required this.name,
    required this.time,
    required this.status,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final isPassed = status == 'passed';
    final isCurrent = status == 'current';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: isCurrent ? 14 : 10,
                height: isCurrent ? 14 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: isCurrent
                      ? Border.all(color: context.textPrimary, width: 2)
                      : null,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              if (status != 'upcoming' || name != 'Lincoln Elementary')
                Container(
                  width: 2,
                  height: 24,
                  color: isPassed
                      ? AppTheme.success.withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : Colors.white.withOpacity(isPassed ? 0.5 : 0.35),
                        fontSize: 13,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withOpacity(isPassed ? 0.35 : 0.25),
                      fontSize: 11,
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
