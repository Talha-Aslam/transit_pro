import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../app/live_bus_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'geo_utils.dart';
import 'google_geo.dart';
import 'map_icons.dart';
import 'map_style.dart';
import 'smooth_marker.dart';
import 'trip_map_renderer.dart';

/// The family's live map: the van gliding along the road it is really
/// taking, the rest of that road ahead of it, this child's own stop and the
/// school.
///
/// Everything drawn comes from [LiveBusService]: the van from
/// `liveLocations/{busId}`, the road from the route the driver's app cached
/// on the trip document. Nothing here asks Google for anything — the line a
/// parent sees is the line the driver is following, and a hundred families
/// watching cost the same as one.
///
/// Other children's stops are not drawn. Which house is whose is another
/// family's business; this one needs to see the van coming to *their* gate.
class LiveBusMapView extends StatefulWidget {
  final double height;
  final BorderRadius? borderRadius;

  /// This child's pickup point — used when the trip carries no stop for
  /// them (an older driver build, or no trip yet).
  final GeoCoord? pickup;

  /// Where the round ends for this child — their school.
  final GeoCoord? destination;

  final Color accent;

  /// Keeps the camera on the van. Moving the map by hand pauses it until
  /// Re-centre is tapped.
  final bool followBus;

  final bool interactive;

  const LiveBusMapView({
    super.key,
    required this.height,
    this.borderRadius,
    this.pickup,
    this.destination,
    this.accent = AppTheme.parentPurple,
    this.followBus = true,
    this.interactive = true,
  });

  @override
  State<LiveBusMapView> createState() => _LiveBusMapViewState();
}

class _LiveBusMapViewState extends State<LiveBusMapView>
    with SingleTickerProviderStateMixin {
  final _svc = LiveBusService.instance;

  GoogleMapController? _map;
  late final SmoothMarker _van;
  BitmapDescriptor? _arrowIcon;
  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _schoolIcon;

  bool _userMovedMap = false;
  GeoCoord? _cameraAt;
  Timer? _clock;

  /// Decoded once per computed route, not on every frame.
  DateTime? _decodedFor;
  List<GeoCoord> _line = const [];
  List<GeoCoord> _firstLeg = const [];

  @override
  void initState() {
    super.initState();
    _van = SmoothMarker(
      vsync: this,
      onFrame: () {
        if (!mounted) return;
        setState(() {});
        _recentre(animate: false);
      },
    );
    _svc.lastKnown.addListener(_onPing);
    _svc.trip.addListener(_onTrip);
    // Re-reads "last updated" once the van has gone quiet.
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    _onTrip();
    _onPing();
  }

  @override
  void didUpdateWidget(covariant LiveBusMapView old) {
    super.didUpdateWidget(old);
    // Follow has just been switched on: go to the van now, not on the next
    // ping — on a van stopped at a light that is a long wait.
    if (widget.followBus && !old.followBus) {
      _userMovedMap = false;
      _cameraAt = null;
      _recentre(animate: true);
    }
  }

  @override
  void dispose() {
    _svc.lastKnown.removeListener(_onPing);
    _svc.trip.removeListener(_onTrip);
    _clock?.cancel();
    _van.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _onPing() {
    final ping = _svc.lastKnown.value;
    if (ping == null) return;
    _van.moveTo(GeoCoord(ping.lat, ping.lng), ping.heading);
  }

  void _onTrip() {
    final route = _svc.trip.value?.route;
    final at = route?.computedAt;
    if (route == null || route.legs.isEmpty) {
      _line = const [];
      _firstLeg = const [];
      _decodedFor = null;
    } else if (at != _decodedFor) {
      _decodedFor = at;
      final legs = [
        for (final l in route.legs) GeoUtils.decodePolyline(l.encodedPolyline),
      ];
      _line = [
        for (var i = 0; i < legs.length; i++)
          ...(i == 0 ? legs[i] : legs[i].skip(1)),
      ];
      _firstLeg = legs.first;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadIcons() async {
    if (_arrowIcon != null) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final arrow = await MapIcons.arrow(widget.accent, dpr);
    final stop = await MapIcons.numbered('★', AppTheme.studentAmber, dpr);
    final school = await MapIcons.pin(AppTheme.warning, dpr);
    if (!mounted) return;
    setState(() {
      _arrowIcon = BitmapDescriptor.bytes(arrow, imagePixelRatio: dpr);
      _stopIcon = BitmapDescriptor.bytes(stop, imagePixelRatio: dpr);
      _schoolIcon = BitmapDescriptor.bytes(school, imagePixelRatio: dpr);
    });
  }

  void _recentre({required bool animate}) {
    final pos = _van.position;
    if (pos == null || !widget.followBus || _userMovedMap || _map == null) {
      return;
    }
    // Roughly 15 m — below that the camera would twitch on GPS noise.
    final last = _cameraAt;
    if (last != null && GeoUtils.distance(last, pos) < 15) return;
    _cameraAt = pos;
    final update = CameraUpdate.newCameraPosition(
      CameraPosition(target: pos.latLng, zoom: 16, bearing: _van.heading),
    );
    unawaited(
      (animate ? _map!.animateCamera(update) : _map!.moveCamera(update))
          .catchError((_) {}),
    );
  }

  /// This child's stop on the trip, or the pin the family set.
  GeoCoord? get _myStop {
    final id = _svc.studentId;
    final t = _svc.trip.value;
    final stop = id == null ? null : t?.stopFor(id);
    if (stop != null) return stop.isOpen ? stop.location : null;
    return widget.pickup;
  }

  /// This child's own institute: where the morning round sets *them* down —
  /// a round can drop at more than one — and otherwise the pin their family
  /// saved. The round's single destination used to stand in for everyone,
  /// which put one school ("Allied School") on every family's map.
  GeoCoord? get _school {
    final t = _svc.trip.value;
    final id = _svc.studentId;
    if (t != null && id != null && t.type == TripType.morning) {
      final mine = t.instituteStopFor(id);
      if (mine != null) return mine.location;
    }
    return widget.destination;
  }

  Set<Polyline> _polylines() {
    if (_line.length < 2) return const {};
    final van = _van.position;
    if (van == null) {
      return TripMapRenderer.polylines(
        remaining: _line,
        currentLeg: _firstLeg,
        color: widget.accent,
      );
    }
    final onLine = GeoUtils.project(van, _line);
    final onLeg = GeoUtils.project(van, _firstLeg);
    return TripMapRenderer.polylines(
      remaining: onLine == null ? _line : GeoUtils.ahead(_line, onLine),
      currentLeg: onLeg == null || onLeg.offsetMeters > 150
          ? const []
          : GeoUtils.ahead(_firstLeg, onLeg),
      color: widget.accent,
    );
  }

  Set<Marker> _markers() {
    final van = _van.position;
    final mine = _myStop;
    final school = _school;
    return {
      if (van != null && _arrowIcon != null)
        Marker(
          markerId: const MarkerId('bus'),
          position: van.latLng,
          icon: _arrowIcon!,
          rotation: _van.heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 3,
        ),
      if (mine != null && _stopIcon != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: mine.latLng,
          icon: _stopIcon!,
          anchor: const Offset(0.5, 1),
          infoWindow: const InfoWindow(title: 'Your stop'),
          zIndexInt: 2,
        ),
      if (school != null && _schoolIcon != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: school.latLng,
          icon: _schoolIcon!,
          anchor: const Offset(0.5, 1),
          infoWindow: const InfoWindow(title: 'School'),
          zIndexInt: 1,
        ),
    };
  }

  /// "Last updated 3 min ago", once the van has been quiet for a minute.
  String? get _staleLabel {
    final ping = _svc.lastKnown.value;
    if (ping == null) return null;
    final age = DateTime.now().difference(ping.time);
    if (age < const Duration(seconds: 60)) return null;
    final m = age.inMinutes;
    return m < 60
        ? 'Last updated $m min ago'
        : 'Last updated ${m ~/ 60} hr ago';
  }

  @override
  Widget build(BuildContext context) {
    unawaited(_loadIcons());
    final isDark = ThemeProvider.instance.isDark;
    final initial =
        _van.position ?? _myStop ?? _school ?? const GeoCoord(31.5204, 74.3587);
    final stale = _staleLabel;

    final map = Stack(
      children: [
        Listener(
          onPointerDown: (_) {
            if (!widget.interactive || _userMovedMap) return;
            setState(() => _userMovedMap = true);
          },
          child: GoogleMap(
            key: ValueKey('live-bus-map-$isDark'),
            initialCameraPosition: CameraPosition(
              target: initial.latLng,
              zoom: 14.5,
            ),
            style: MapStyle.forBrightness(isDark),
            markers: _markers(),
            polylines: _polylines(),
            onMapCreated: (c) {
              _map = c;
              _cameraAt = null;
              _recentre(animate: false);
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: widget.interactive,
            zoomGesturesEnabled: widget.interactive,
            rotateGesturesEnabled: widget.interactive,
            tiltGesturesEnabled: false,
          ),
        ),
        if (stale != null)
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                stale,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (_userMovedMap && widget.followBus && _van.position != null)
          Positioned(
            right: 10,
            bottom: 10,
            child: Material(
              color: context.cardBg,
              elevation: 3,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() => _userMovedMap = false);
                  _cameraAt = null;
                  _recentre(animate: true);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.navigation_rounded,
                        size: 14,
                        color: widget.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Re-centre',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return SizedBox(
      height: widget.height,
      child: widget.borderRadius == null
          ? map
          : ClipRRect(borderRadius: widget.borderRadius!, child: map),
    );
  }
}
