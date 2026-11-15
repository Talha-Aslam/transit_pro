import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/missed_bus_service.dart';
import '../../app/navigation_launcher.dart';
import '../../app/route_optimization_service.dart';
import '../../app/route_service.dart';
import '../../app/trip_session.dart';
import '../../map/google_geo.dart';
import '../../map/map_style.dart';
import '../../theme/app_theme.dart';

/// The missed-bus pickup a family has just accepted, on a map.
///
/// Opened automatically the moment the family accepts the driver's fare (see
/// `DriverLayout`), or from the "Offer accepted" push. It plans the whole
/// job at once — from where the van is, to the student's pickup point, on to
/// the drop-off — so the driver never has to search for either place.
class DriverMissedBusJobScreen extends StatefulWidget {
  const DriverMissedBusJobScreen({super.key});

  @override
  State<DriverMissedBusJobScreen> createState() =>
      _DriverMissedBusJobScreenState();
}

class _DriverMissedBusJobScreenState extends State<DriverMissedBusJobScreen> {
  final _service = MissedBusService.instance;

  GoogleMapController? _map;
  String? _plannedFor;
  GeoCoord? _origin;
  GeoCoord? _pickup;
  GeoCoord? _dropoff;
  List<LatLng> _toPickup = const [];
  List<LatLng> _toDropoff = const [];
  int? _minutesToPickup;
  int? _minutesToDropoff;
  bool _planning = false;
  bool _busy = false;
  String? _error;

  /// Set when the job has gone away (finished or cancelled), so the screen
  /// can say so once instead of vanishing under the driver.
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _service.driverAcceptedJob.addListener(_onJob);
    _onJob();
  }

  @override
  void dispose() {
    _service.driverAcceptedJob.removeListener(_onJob);
    _map?.dispose();
    super.dispose();
  }

  void _onJob() {
    final job = _service.driverAcceptedJob.value;
    if (!mounted) return;
    if (job == null) {
      if (_plannedFor != null) setState(() => _closed = true);
      return;
    }
    if (job.id != _plannedFor) _plan(job);
    setState(() {});
  }

  /// Where a place is: its saved pin, or a search on its name when the
  /// request was raised without one.
  Future<GeoCoord?> _locate(GeoCoord? pin, String name, GeoCoord? near) async {
    if (pin != null) return pin;
    if (name.trim().isEmpty) return null;
    final hits = await RouteService.instance.forwardGeocode(
      name,
      near: near,
      limit: 1,
    );
    return hits.isEmpty ? null : hits.first.coord;
  }

  Future<void> _plan(MissedBusRequest job) async {
    _plannedFor = job.id;
    setState(() {
      _planning = true;
      _error = null;
      _closed = false;
    });
    try {
      final origin = await TripSession.currentPosition();
      final pickup = await _locate(
        job.currentStopCoord,
        job.currentStopName,
        origin,
      );
      final dropoff = await _locate(
        job.destinationCoord,
        job.destinationStopName,
        pickup ?? origin,
      );
      if (!mounted || _plannedFor != job.id) return;
      _origin = origin;
      _pickup = pickup;
      _dropoff = dropoff;

      if (pickup == null) {
        setState(() {
          _planning = false;
          _error =
              'This request has no pickup pin and "${job.currentStopName}" '
              'could not be found on the map.';
        });
        return;
      }

      // Already collected → only the second leg is left to drive.
      final start = job.pickedUpAt != null ? pickup : (origin ?? pickup);
      final stops = <PlanStop>[
        if (job.pickedUpAt == null && origin != null)
          PlanStop('pickup', pickup),
      ];
      final plan = await GoogleRouteOptimizer.instance.plan(
        origin: start,
        destination: dropoff,
        stops: stops,
        optimize: false,
      );
      if (!mounted || _plannedFor != job.id) return;

      final legs = plan.legs;
      final hasPickupLeg = stops.isNotEmpty && legs.isNotEmpty;
      setState(() {
        _toPickup = hasPickupLeg
            ? [for (final p in legs.first.points) p.latLng]
            : const [];
        final rest = hasPickupLeg ? legs.skip(1) : legs;
        _toDropoff = [
          for (final l in rest)
            for (final p in l.points) p.latLng,
        ];
        _minutesToPickup = hasPickupLeg
            ? (legs.first.seconds / 60).ceil()
            : null;
        _minutesToDropoff = rest.isEmpty
            ? null
            : (rest.fold<int>(0, (s, l) => s + l.seconds) / 60).ceil();
        _planning = false;
      });
      _fit();
    } catch (e) {
      debugPrint('missed-bus job plan failed: $e');
      if (!mounted) return;
      // The pins are still worth showing, with straight lines between them.
      setState(() {
        _planning = false;
        _toPickup = [
          if (_origin != null) _origin!.latLng,
          if (_pickup != null) _pickup!.latLng,
        ];
        _toDropoff = [
          if (_pickup != null) _pickup!.latLng,
          if (_dropoff != null) _dropoff!.latLng,
        ];
      });
      _fit();
    }
  }

  void _fit() {
    final map = _map;
    final points = [
      ?_origin?.latLng,
      ?_pickup?.latLng,
      ?_dropoff?.latLng,
      ..._toPickup,
      ..._toDropoff,
    ];
    if (map == null || points.isEmpty) return;
    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    if (minLat == maxLat && minLng == maxLng) {
      map.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  Set<Marker> _markers(MissedBusRequest job) => {
    if (_pickup != null)
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup!.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup — ${job.studentName}',
          snippet: job.currentStopName,
        ),
      ),
    if (_dropoff != null)
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoff!.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Drop-off',
          snippet: job.destinationStopName,
        ),
      ),
  };

  Set<Polyline> _polylines(bool pickedUp) => {
    if (!pickedUp && _toPickup.length >= 2)
      Polyline(
        polylineId: const PolylineId('to-pickup'),
        points: _toPickup,
        width: 6,
        color: AppTheme.success,
      ),
    if (_toDropoff.length >= 2)
      Polyline(
        polylineId: const PolylineId('to-dropoff'),
        points: _toDropoff,
        width: 6,
        color: AppTheme.driverCyan,
      ),
  };

  Future<void> _navigate(GeoCoord? to) async {
    if (to == null) return;
    final ok = await NavigationLauncher.navigateTo(to);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _service.driverAcceptedJob.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missed-bus pickup'),
        backgroundColor: context.cardBgElevated,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: job == null
          ? _Finished(closed: _closed)
          : Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    key: ValueKey('mb-job-$isDark'),
                    initialCameraPosition: CameraPosition(
                      target:
                          (job.currentStopCoord ??
                                  job.destinationCoord ??
                                  const GeoCoord(31.5204, 74.3587))
                              .latLng,
                      zoom: 13,
                    ),
                    style: MapStyle.forBrightness(isDark),
                    markers: _markers(job),
                    polylines: _polylines(job.pickedUpAt != null),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    padding: const EdgeInsets.only(bottom: 260),
                    onMapCreated: (c) {
                      _map = c;
                      _fit();
                    },
                  ),
                ),
                if (_planning)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(child: _Chip(text: 'Planning the route…')),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: SafeArea(top: false, child: _panel(job)),
                ),
              ],
            ),
    );
  }

  Widget _panel(MissedBusRequest job) {
    final pickedUp = job.pickedUpAt != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.studentName.isEmpty ? 'Student' : job.studentName,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (job.displayFare != null)
            Text(
              'Agreed fare ${job.displayFare}',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          const SizedBox(height: 10),
          _Leg(
            icon: Icons.trip_origin,
            color: AppTheme.success,
            label: 'Pickup',
            place: job.currentStopName,
            minutes: pickedUp ? null : _minutesToPickup,
            done: pickedUp,
          ),
          const SizedBox(height: 6),
          _Leg(
            icon: Icons.place,
            color: AppTheme.error,
            label: 'Drop-off',
            place: job.destinationStopName,
            minutes: _minutesToDropoff,
            done: false,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigate(pickedUp ? _dropoff : _pickup),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text(pickedUp ? 'Navigate to drop-off' : 'Navigate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: pickedUp
                        ? AppTheme.success
                        : AppTheme.driverCyan,
                  ),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => pickedUp
                              ? _service.markCompleted(job)
                              : _service.markPickedUp(job),
                        ),
                  child: Text(
                    pickedUp ? 'Dropped off' : 'Picked up',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

class _Leg extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String place;
  final int? minutes;
  final bool done;

  const _Leg({
    required this.icon,
    required this.color,
    required this.label,
    required this.place,
    required this.minutes,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(done ? Icons.check_circle : icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: ${place.isEmpty ? 'On the map' : place}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 13,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (minutes != null)
          Text(
            '~$minutes min',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: context.inputBorder),
    ),
    child: Text(
      text,
      style: TextStyle(color: context.textPrimary, fontSize: 12),
    ),
  );
}

class _Finished extends StatelessWidget {
  final bool closed;
  const _Finished({required this.closed});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            closed ? Icons.check_circle_outline : Icons.directions_bus_outlined,
            size: 48,
            color: closed ? AppTheme.success : context.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            closed
                ? 'This pickup is finished or was cancelled.'
                : 'No accepted pickup right now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/driver'),
            child: const Text('Back'),
          ),
        ],
      ),
    ),
  );
}
