import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../app/trip_controller.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'geo_utils.dart';
import 'google_geo.dart';
import 'map_icons.dart';
import 'map_style.dart';
import 'smooth_marker.dart';
import 'trip_map_renderer.dart';

/// The driver's round on a map: the van as an arrow, every stop numbered in
/// visiting order, the road ahead outlined and the stretch to the next stop
/// drawn stronger, and the road already driven in grey.
///
/// Rebuilt from [TripController] on every change. Opens framed on the whole
/// round, then follows the van — centred, tilted, turned to the heading —
/// until the driver moves the map themselves, at which point following
/// stops and a Re-centre button takes them back.
class TripMapView extends StatefulWidget {
  final TripController controller;
  final double? height;
  final BorderRadius? borderRadius;
  final Color accent;

  /// Space at the bottom the camera keeps clear, for a card drawn over the
  /// map.
  final double bottomPadding;

  const TripMapView({
    super.key,
    required this.controller,
    this.height,
    this.borderRadius,
    this.accent = AppTheme.driverCyan,
    this.bottomPadding = 0,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _map;
  late final SmoothMarker _van;
  BitmapDescriptor? _arrow;
  final _stopIcons = <String, BitmapDescriptor>{};
  BitmapDescriptor? _destinationIcon;

  bool _following = true;
  String? _framedTripId;
  DateTime? _framedPlan;
  bool _cameraBusy = false;

  TripController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _van = SmoothMarker(
      vsync: this,
      onFrame: () {
        if (mounted) setState(() {});
        _followVan();
      },
    );
    _c.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(TripMapView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _van.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final pos = _c.position;
    if (pos != null) _van.moveTo(pos, _c.heading);
    unawaited(_loadStopIcons());
    _frameIfNewPlan();
    setState(() {});
  }

  Future<void> _loadIcons() async {
    if (_arrow != null) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final arrow = await MapIcons.arrow(widget.accent, dpr);
    final dest = await MapIcons.pin(AppTheme.parentPurple, dpr);
    if (!mounted) return;
    setState(() {
      _arrow = BitmapDescriptor.bytes(arrow, imagePixelRatio: dpr);
      _destinationIcon = BitmapDescriptor.bytes(dest, imagePixelRatio: dpr);
    });
  }

  String _iconKey(TripStop s) => '${s.order}|${s.status.name}';

  /// Numbered icons are drawn on demand, once per number and status.
  Future<void> _loadStopIcons() async {
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    var added = false;
    for (final s in _c.stops) {
      if (s.isInstitute) continue;
      final key = _iconKey(s);
      if (_stopIcons.containsKey(key)) continue;
      final bytes = await MapIcons.numbered(
        '${s.order}',
        TripMapRenderer.stopColor(s),
        dpr,
      );
      _stopIcons[key] = BitmapDescriptor.bytes(bytes, imagePixelRatio: dpr);
      added = true;
    }
    if (added && mounted) setState(() {});
  }

  /// Frames the whole round once per trip, then hands the camera back to
  /// following.
  void _frameIfNewPlan() {
    final trip = _c.trip;
    final map = _map;
    if (trip == null || map == null || _c.plannedAt == null) return;
    if (_framedTripId == trip.id) return;
    _framedTripId = trip.id;
    _framedPlan = _c.plannedAt;
    final bounds = TripMapRenderer.boundsOf([
      ?_c.position,
      ..._c.remainingLine,
      for (final s in _c.openStops) s.location,
    ]);
    if (bounds == null) return;
    unawaited(() async {
      _cameraBusy = true;
      try {
        await map.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
        // Long enough to read the whole round before the camera closes in.
        await Future<void>.delayed(const Duration(seconds: 3));
      } catch (_) {
        // The map can be torn down mid-animation; nothing to recover.
      } finally {
        _cameraBusy = false;
      }
      _followVan(force: true);
    }());
  }

  /// Close enough to drive by, far enough out that the stop the van is
  /// heading for stays on screen — a fixed street-level zoom lost every
  /// stop but the van once it was more than a few hundred metres away.
  double _followZoom(GeoCoord van) {
    final next = _c.nextStop?.location;
    if (next == null) return 17;
    final meters = GeoUtils.distance(van, next);
    if (meters < 150) return 17;
    final halfScreen = MediaQuery.sizeOf(context).height * 0.3;
    final metersPerPixelAtZoom0 =
        156543.03392 * math.cos(van.lat * math.pi / 180);
    final zoom =
        math.log(metersPerPixelAtZoom0 * halfScreen / (meters * 1.3)) /
        math.ln2;
    return zoom.clamp(11.0, 17.0);
  }

  void _followVan({bool force = false}) {
    final map = _map;
    final pos = _van.position;
    if (map == null || pos == null || !_following || _cameraBusy) return;
    if (!force && _framedPlan == null) return;
    unawaited(
      map
          .moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: pos.latLng,
                zoom: _followZoom(pos),
                tilt: 45,
                bearing: _van.heading,
              ),
            ),
          )
          .catchError((_) {}),
    );
  }

  /// The whole round at once — where it starts, every stop, where it ends
  /// — until the driver taps Re-centre.
  void _overview() {
    final map = _map;
    if (map == null) return;
    setState(() => _following = false);
    final bounds = TripMapRenderer.boundsOf([
      ?_van.position,
      for (final s in _c.stops) s.location,
    ]);
    if (bounds == null) return;
    unawaited(
      map
          .animateCamera(CameraUpdate.newLatLngBounds(bounds, 56))
          .catchError((_) {}),
    );
  }

  void _recentre() {
    setState(() => _following = true);
    _framedPlan ??= _c.plannedAt;
    final map = _map;
    final pos = _van.position;
    if (map == null || pos == null) return;
    unawaited(
      map
          .animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: pos.latLng,
                zoom: 17,
                tilt: 45,
                bearing: _van.heading,
              ),
            ),
          )
          .catchError((_) {}),
    );
  }

  Set<Marker> _markers() {
    final out = <Marker>{};
    for (final s in _c.stops) {
      if (s.isInstitute) {
        final icon = _destinationIcon;
        if (icon == null) continue;
        out.add(
          Marker(
            markerId: MarkerId('institute-${s.id}'),
            position: s.location.latLng,
            icon: icon,
            anchor: const Offset(0.5, 1),
            zIndexInt: 2,
            alpha: s.isOpen ? 1 : 0.6,
            infoWindow: InfoWindow(title: _c.instituteName(s)),
          ),
        );
        continue;
      }
      final icon = _stopIcons[_iconKey(s)];
      if (icon == null) continue;
      final names = _c.ridersAt(s).map((r) => r.name).join(', ');
      out.add(
        Marker(
          markerId: MarkerId(s.id),
          position: s.location.latLng,
          icon: icon,
          anchor: const Offset(0.5, 1),
          zIndexInt: s.isOpen ? 3 : 1,
          alpha: s.isOpen ? 1 : 0.7,
          infoWindow: InfoWindow(title: '${s.order}. $names'),
        ),
      );
    }
    final van = _van.position;
    if (van != null && _arrow != null) {
      out.add(
        Marker(
          markerId: const MarkerId('van'),
          position: van.latLng,
          icon: _arrow!,
          rotation: _van.heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 10,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    unawaited(_loadIcons());
    if (_stopIcons.isEmpty && _c.stops.isNotEmpty) {
      unawaited(_loadStopIcons());
    }
    final isDark = ThemeProvider.instance.isDark;
    final start = _c.position ?? _c.nextStop?.location;

    Widget content;
    if (!AppConfig.hasGoogleMapsKey) {
      content = const ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Text(
            'Map unavailable — no Google Maps API key configured.',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    } else {
      content = Stack(
        children: [
          // Any finger on the map is the driver taking the camera; follow
          // stops until they ask for it back.
          Listener(
            onPointerDown: (_) {
              if (_following) setState(() => _following = false);
            },
            child: GoogleMap(
              key: ValueKey('trip-map-$isDark'),
              initialCameraPosition: CameraPosition(
                target: (start ?? const GeoCoord(31.5204, 74.3587)).latLng,
                zoom: 15,
              ),
              style: MapStyle.forBrightness(isDark),
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              markers: _markers(),
              polylines: TripMapRenderer.polylines(
                remaining: _c.remainingLine,
                currentLeg: _c.currentLegLine,
                travelled: _c.travelledLine,
                color: widget.accent,
              ),
              onMapCreated: (map) {
                _map = map;
                _framedTripId = null;
                _frameIfNewPlan();
              },
              compassEnabled: false,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          Positioned(
            right: 12,
            bottom: widget.bottomPadding + 12,
            child: _following
                ? _RecentreButton(
                    accent: widget.accent,
                    onTap: _overview,
                    label: 'Overview',
                    icon: Icons.zoom_out_map_rounded,
                  )
                : _RecentreButton(accent: widget.accent, onTap: _recentre),
          ),
        ],
      );
    }

    final sized = widget.height == null
        ? content
        : SizedBox(height: widget.height, child: content);
    return widget.borderRadius == null
        ? sized
        : ClipRRect(borderRadius: widget.borderRadius!, child: sized);
  }
}

class _RecentreButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  const _RecentreButton({
    required this.accent,
    required this.onTap,
    this.label = 'Re-centre',
    this.icon = Icons.navigation_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardBg,
      elevation: 4,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
