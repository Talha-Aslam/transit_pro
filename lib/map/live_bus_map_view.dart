import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../app/live_bus_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'google_geo.dart';
import 'map_icons.dart';
import 'map_style.dart';

/// The family's live map: the bus where it actually is, and this child's own
/// two points.
///
/// Distinct from [RouteMapView], which renders a [TrackingService] route —
/// the full stop list, the polyline, the progress line. That one only ever
/// has anything to draw on the *driver's* device, because reconstructing a
/// driver's route on a parent's phone would mean reading every other
/// family's pickup point, which `firestore.rules` rightly refuses. A parent
/// does not need the whole round, though: they need to see the bus moving
/// and how far it still is from their own door, which is exactly what
/// `liveLocations/{busId}` carries and what this draws.
class LiveBusMapView extends StatefulWidget {
  final double height;
  final BorderRadius? borderRadius;

  /// This child's pickup point, drawn as "your stop".
  final GeoCoord? pickup;

  /// Where the round ends for this child — their school.
  final GeoCoord? destination;

  final Color accent;

  /// Keeps the camera on the bus as it moves. Off lets the viewer pan away.
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

class _LiveBusMapViewState extends State<LiveBusMapView> {
  final _svc = LiveBusService.instance;

  GoogleMapController? _map;
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _schoolIcon;

  /// The last position the camera was moved to, so a ping that barely moves
  /// does not animate the camera on every tick.
  GeoCoord? _cameraAt;

  @override
  void initState() {
    super.initState();
    _svc.position.addListener(_onPosition);
  }

  @override
  void dispose() {
    _svc.position.removeListener(_onPosition);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadIcons() async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (_busIcon != null) return;
    final bus = await MapIcons.bus(dpr);
    final stop = await MapIcons.pin(widget.accent, dpr);
    final school = await MapIcons.pin(AppTheme.warning, dpr);
    if (!mounted) return;
    setState(() {
      _busIcon = BitmapDescriptor.bytes(bus, imagePixelRatio: dpr);
      _stopIcon = BitmapDescriptor.bytes(stop, imagePixelRatio: dpr);
      _schoolIcon = BitmapDescriptor.bytes(school, imagePixelRatio: dpr);
    });
  }

  void _onPosition() {
    if (!mounted) return;
    setState(() {});
    final ping = _svc.position.value;
    if (ping == null || !widget.followBus) return;

    // Roughly 15m — below that the camera would twitch on GPS noise rather
    // than follow the bus.
    final last = _cameraAt;
    if (last != null &&
        (last.lat - ping.lat).abs() < 0.00015 &&
        (last.lng - ping.lng).abs() < 0.00015) {
      return;
    }
    _cameraAt = GeoCoord(ping.lat, ping.lng);
    _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(ping.lat, ping.lng),
          zoom: 15.5,
          bearing: ping.heading,
        ),
      ),
    );
  }

  Set<Marker> _markers() {
    final ping = _svc.position.value;
    return {
      if (ping != null && _busIcon != null)
        Marker(
          markerId: const MarkerId('bus'),
          position: LatLng(ping.lat, ping.lng),
          icon: _busIcon!,
          rotation: ping.heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 3,
        ),
      if (widget.pickup != null && _stopIcon != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup!.latLng,
          icon: _stopIcon!,
          infoWindow: const InfoWindow(title: 'Your stop'),
          zIndexInt: 2,
        ),
      if (widget.destination != null && _schoolIcon != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.destination!.latLng,
          icon: _schoolIcon!,
          infoWindow: const InfoWindow(title: 'School'),
          zIndexInt: 1,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    unawaited(_loadIcons());
    final isDark = ThemeProvider.instance.isDark;
    final ping = _svc.position.value;

    // Open on the bus when there is one, otherwise on this child's stop, and
    // only then on the city — so the first frame is never an arbitrary
    // corner of the map.
    final initial =
        ping != null
            ? LatLng(ping.lat, ping.lng)
            : (widget.pickup ?? widget.destination)?.latLng ??
                const LatLng(31.5204, 74.3587);

    final map = GoogleMap(
      key: ValueKey('live-bus-map-$isDark'),
      initialCameraPosition: CameraPosition(target: initial, zoom: 14.5),
      style: MapStyle.forBrightness(isDark),
      markers: _markers(),
      onMapCreated: (c) => _map = c,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      rotateGesturesEnabled: widget.interactive,
      tiltGesturesEnabled: false,
    );

    return SizedBox(
      height: widget.height,
      child: widget.borderRadius == null
          ? map
          : ClipRRect(borderRadius: widget.borderRadius!, child: map),
    );
  }
}
