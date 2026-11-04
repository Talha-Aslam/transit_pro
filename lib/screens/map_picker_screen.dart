import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../app/location_permissions.dart';
import '../app/route_service.dart';
import '../map/google_geo.dart';
import '../map/map_style.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// What [MapPickerScreen] hands back: the coordinates the user actually
/// wants stored, plus whatever human-readable address was resolved for them
/// while they were picking — so a caller that already has it doesn't need to
/// spend a second network round trip re-resolving the same point.
class PickedLocation {
  final GeoCoord coord;
  final String? address;
  const PickedLocation({required this.coord, this.address});
}

class MapPickerScreen extends StatefulWidget {
  final GeoCoord? initial;

  /// Tints the pin, the "confirm" button and the locate-me FAB so this screen
  /// reads as part of whichever role's flow opened it (parent purple, driver
  /// cyan, student amber) instead of always defaulting to one colour.
  final Color accentColor;

  const MapPickerScreen({
    super.key,
    this.initial,
    this.accentColor = AppTheme.parentPurple,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  /// The point under the fixed centre pin — the single source of truth for
  /// "what is currently selected". Dragging the map, tapping a point, picking
  /// a search result and "my location" all funnel through moving the camera;
  /// this is just read back off wherever the camera ends up.
  late GeoCoord _selected;
  GoogleMapController? _map;

  /// Whether a Google Maps API key is configured at all — the only signal
  /// available up front. google_maps_flutter has no portable "style loaded"
  /// / "tile load failed" callback the way Mapbox did, so an unauthorized
  /// key can't be distinguished from a good one here — the native view
  /// renders its own chrome either way and just shows no tiles.
  String? _loadError;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<GeocodeResult> _searchResults = [];
  bool _searching = false;
  bool _locating = false;

  /// The device's real GPS fix, fetched once on open — used to bias search
  /// results (via `near`) toward where the user actually is rather
  /// than wherever the pin happens to be sitting, and to show each result's
  /// distance the way inDrive's route-entry search does. Best-effort only:
  /// left null on denied/disabled location services, in which case results
  /// fall back to biasing off [_selected] and no distance is shown — this
  /// screen must stay usable without location permission.
  GeoCoord? _userLocation;

  /// Places Autocomplete session token — see
  /// [RouteService.newSessionToken]. Minted on the field gaining focus or
  /// the first non-empty query (whichever happens first) and reused for
  /// every autocomplete/details call until the search is cleared back to
  /// empty, per Google's per-session billing model.
  String? _searchSessionToken;

  /// Drives the pin's little "lift" animation — purely cosmetic feedback that
  /// the map (not the pin) is what's moving.
  bool _isMovingCamera = false;

  /// The reverse-geocoded address for [_addressFor], resolved after the
  /// camera settles. `_addressFor` guards against a slow lookup for a point
  /// the user has already panned away from overwriting the label for
  /// wherever they've since landed.
  String? _address;
  GeoCoord? _addressFor;
  bool _resolvingAddress = false;
  Timer? _geocodeDebounce;

  // Manual entry — the fallback when there is no Google Maps API key at
  // all and no map ever renders to drag a pin across.
  late final _manualLatCtrl = TextEditingController(
    text: _selected.lat.toStringAsFixed(6),
  );
  late final _manualLngCtrl = TextEditingController(
    text: _selected.lng.toStringAsFixed(6),
  );

  @override
  void initState() {
    super.initState();
    _selected =
        widget.initial ?? const GeoCoord(31.5204, 74.3587); // default Lahore

    if (!AppConfig.hasGoogleMapsKey) {
      // No point even constructing the native view — with no key it just
      // renders chrome and no tiles.
      _loadError = 'no_key';
      return;
    }

    _searchFocus.addListener(_onSearchFocusChanged);
    unawaited(_loadUserLocation());
  }

  Future<void> _loadUserLocation() async {
    final allowed = await ensureLocationPermission();
    if (!allowed || !mounted) return;
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(
        () => _userLocation = GeoCoord(position.latitude, position.longitude),
      );
    } catch (_) {
      // Best-effort — search and the map both work fine without this.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _geocodeDebounce?.cancel();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _manualLatCtrl.dispose();
    _manualLngCtrl.dispose();
    super.dispose();
  }

  /// Mints a session token the moment the search field gains focus, if a
  /// session isn't already open — covers the "tapped the field but hasn't
  /// typed yet" case; [_onSearchChanged] covers the fallback of a session
  /// starting on the first keystroke without an intervening focus event.
  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus) {
      _searchSessionToken ??= RouteService.newSessionToken();
    }
  }

  void _onMapCreated(GoogleMapController map) {
    _map = map;
    // compass/myLocation etc. are GoogleMap widget params now, not
    // post-creation controller calls — set once in build() below.
    _scheduleReverseGeocode(immediate: true);
  }

  /// Fires continuously while the camera moves (drag, pinch, animated move)
  /// — carries the new camera position directly, no need to turn around and
  /// query it back.
  void _onCameraMove(CameraPosition position) {
    if (_map == null) return;
    setState(() {
      _selected = position.target.geoCoord;
      _isMovingCamera = true;
    });
  }

  /// Fires once the camera has actually settled — the right moment to spend
  /// a real geocoding request, rather than firing one every frame of a drag.
  void _onCameraIdle() {
    if (!mounted) return;
    setState(() => _isMovingCamera = false);
    _scheduleReverseGeocode();
  }

  void _scheduleReverseGeocode({bool immediate = false}) {
    _geocodeDebounce?.cancel();
    final point = _selected;

    Future<void> run() async {
      if (!mounted) return;
      setState(() => _resolvingAddress = true);
      final address = await RouteService.instance.reverseGeocode(point);
      // The map may have settled somewhere else entirely while this was in
      // flight — never let a slow, stale lookup overwrite a newer one.
      if (!mounted || _selected != point) return;
      setState(() {
        _addressFor = point;
        _address = address;
        _resolvingAddress = false;
      });
    }

    if (immediate) {
      run();
    } else {
      _geocodeDebounce = Timer(const Duration(milliseconds: 350), run);
    }
  }

  /// Moves the camera so [point] ends up under the fixed centre pin. Shared
  /// by map taps, search results and "my location" — the three ways a point
  /// can be chosen without dragging.
  Future<void> _flyTo(GeoCoord point) async {
    setState(() => _selected = point); // optimistic — feels instant
    await _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: point.latLng, zoom: 16),
      ),
    );
  }

  Future<void> _onTap(LatLng point) async {
    _searchFocus.unfocus();
    await _flyTo(point.geoCoord);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      // Back to empty — the session is over; the next non-empty query (or
      // focus event) starts a fresh one.
      _searchSessionToken = null;
      return;
    }
    // First keystroke without a preceding focus event still needs a token.
    final token = _searchSessionToken ??= RouteService.newSessionToken();
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      // Search Box API first — it actually indexes POIs/landmarks, unlike
      // plain address geocoding. Fall back to forwardGeocode only when it
      // comes back empty (no cost when the primary call already succeeded),
      // since Geocoding v6 can still do better on plain street addresses.
      final near = _userLocation ?? _selected;
      var results = await RouteService.instance.searchPlaces(
        query,
        sessionToken: token,
        near: near,
      );
      if (results.isEmpty) {
        results = await RouteService.instance.forwardGeocode(query, near: near);
      }
      if (!mounted || _searchCtrl.text != query) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  Future<void> _onResultSelected(GeocodeResult result) async {
    setState(() {
      _searchCtrl.text = result.label;
      _searchResults = [];
    });
    _searchFocus.unfocus();
    await _flyTo(result.coord);
  }

  Future<void> _onLocateMe() async {
    setState(() => _locating = true);
    try {
      // One message for three different refusals, and no way to act on
      // any of them. `ensureLocationOrExplain` names the actual block and
      // puts the right destination behind the button — the phone's
      // location toggle, or this app's permission page.
      if (!mounted) return;
      final allowed = await ensureLocationOrExplain(
        context,
        accent: widget.accentColor,
      );
      if (!allowed) return;
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      await _flyTo(GeoCoord(position.latitude, position.longitude));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get your location: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    final resolved = _addressFor == _selected ? _address : null;
    Navigator.of(
      context,
    ).pop(PickedLocation(coord: _selected, address: resolved));
  }

  void _confirmManual() {
    final lat = double.tryParse(_manualLatCtrl.text.trim());
    final lng = double.tryParse(_manualLngCtrl.text.trim());
    final valid =
        lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid latitude (-90 to 90) and longitude (-180 to 180).',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(PickedLocation(coord: GeoCoord(lat, lng)));
  }

  /// Mirrors the app's existing role gradients so the confirm button reads
  /// as "part of this role's flow" rather than a flat, unrelated colour.
  Gradient get _buttonGradient {
    final accent = widget.accentColor;
    if (accent == AppTheme.driverCyan) return AppTheme.driverGradient;
    if (accent == AppTheme.studentAmber) return AppTheme.studentGradient;
    if (accent == AppTheme.parentPurple) return AppTheme.parentGradient;
    return LinearGradient(colors: [accent, accent.withValues(alpha: 0.75)]);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final showSearchUi = _loadError == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select location'),
        backgroundColor: context.cardBgElevated,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: GestureDetector(
        // Tapping the map (not the search UI) should dismiss any open
        // results/keyboard, same as tapping outside a search field anywhere
        // else in the app.
        onTap: _searchFocus.unfocus,
        child: Stack(
          children: [
            if (_loadError == null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selected.latLng,
                  zoom: 15,
                ),
                style: MapStyle.forBrightness(context.isDark),
                onMapCreated: _onMapCreated,
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
                onTap: _onTap,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                zoomControlsEnabled: false,
              ),
            if (_loadError == null) _buildCenterPin(accent),
            if (showSearchUi)
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: _SearchBox(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  searching: _searching,
                  results: _searchResults,
                  userLocation: _userLocation,
                  onChanged: _onSearchChanged,
                  onResultTap: _onResultSelected,
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() => _searchResults = []);
                    _searchSessionToken = null;
                  },
                ),
              ),
            if (showSearchUi)
              Positioned(
                right: 16,
                bottom: 206,
                child: FloatingActionButton(
                  heroTag: 'locate-me',
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  onPressed: _locating ? null : _onLocateMe,
                  child: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            if (_loadError == null)
              _buildInfoCard(accent)
            else
              _buildManualEntry(accent),
          ],
        ),
      ),
    );
  }

  /// A pin fixed at the exact centre of the screen — the map moves under it,
  /// rather than a native annotation the user drags. This is what makes a
  /// point always visibly "selected": no marker asset to fail to load, no
  /// platform-channel round trip to place or move it, and it works exactly
  /// the same whether the point came from a drag, a tap, a search result or
  /// "my location".
  Widget _buildCenterPin(Color accent) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          height: 64,
          width: 56,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: _isMovingCamera ? 8 : 13,
                height: 4,
                margin: EdgeInsets.only(bottom: _isMovingCamera ? 3 : 0),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              AnimatedSlide(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                offset: _isMovingCamera
                    ? const Offset(0, -0.62)
                    : const Offset(0, -0.42),
                child: Icon(
                  Icons.location_on,
                  size: 46,
                  color: accent,
                  shadows: const [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(Color accent) {
    final coordsText =
        '${_selected.lat.toStringAsFixed(6)}, ${_selected.lng.toStringAsFixed(6)}';
    final resolved = _addressFor == _selected ? _address : null;
    final primaryText =
        resolved ?? (_resolvingAddress ? 'Finding address…' : coordsText);
    final secondaryText = resolved != null ? coordsText : null;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.place_rounded, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (secondaryText != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          secondaryText,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_resolvingAddress)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: 'Confirm location',
              gradient: _buttonGradient,
              glowColor: accent,
              onTap: _confirm,
            ),
          ],
        ),
      ),
    );
  }

  /// Shown instead of the map when there is no Google Maps API key. The old
  /// version of this screen said "you can still tap below to enter
  /// coordinates manually" with nothing underneath that actually let you —
  /// this is that fallback made real.
  Widget _buildManualEntry(Color accent) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      top: 12,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Map tiles are unavailable — the Google Maps API key '
                      'is not configured yet. Enter coordinates manually '
                      'instead; what gets saved is unaffected.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CoordField(
                      label: 'LATITUDE',
                      controller: _manualLatCtrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CoordField(
                      label: 'LONGITUDE',
                      controller: _manualLngCtrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Use these coordinates',
                gradient: _buttonGradient,
                glowColor: accent,
                onTap: _confirmManual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _CoordField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}

/// Search field + its results dropdown, floating over the map. The result
/// row layout — bold title, muted address below, distance pinned to the
/// trailing edge — mirrors the route-entry search inDrive and similar
/// ride-hailing apps use, since parents picking a pickup/dropoff point are
/// solving the exact same "which of these nearby places did I mean" problem.
class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final List<GeocodeResult> results;

  /// The device's real location, when known — purely presentational here
  /// (each result's distance is computed against it); the actual proximity
  /// bias sent to the search API happens in
  /// [_MapPickerScreenState._onSearchChanged].
  final GeoCoord? userLocation;
  final ValueChanged<String> onChanged;
  final ValueChanged<GeocodeResult> onResultTap;
  final VoidCallback onClear;

  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.results,
    required this.userLocation,
    required this.onChanged,
    required this.onResultTap,
    required this.onClear,
  });

  /// "850 m" below a kilometre, "2.4 km" above — matches how inDrive/Google
  /// Maps switch units, and avoids a misleadingly precise "0.2 km" for
  /// anything genuinely nearby. Null with no known [userLocation].
  String? _distanceLabel(GeoCoord to) {
    final from = userLocation;
    if (from == null) return null;
    final meters = Geolocator.distanceBetween(
      from.lat,
      from.lng,
      to.lat,
      to.lng,
    );
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          color: context.cardBgElevated,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search for a place or address',
              hintStyle: TextStyle(color: context.textTertiary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              prefixIcon: Icon(Icons.search, color: context.textTertiary),
              suffixIcon: searching
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.textTertiary,
                        ),
                      ),
                    )
                  : (controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: context.textTertiary,
                            ),
                            onPressed: onClear,
                          )
                        : null),
            ),
          ),
        ),
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              color: context.cardBgElevated,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.surfaceBorder),
                  itemBuilder: (_, i) {
                    final r = results[i];
                    final subtitle = r.placeFormatted ?? r.label;
                    final title = r.name ?? r.label;
                    final distance = _distanceLabel(r.coord);
                    return InkWell(
                      onTap: () => onResultTap(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.place_outlined,
                              color: context.textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (subtitle != title) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (distance != null) ...[
                              const SizedBox(width: 10),
                              Text(
                                distance,
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
