/// Theme-aware style selection.
///
/// `MapboxStyles.LIGHT`/`.DARK` (the previous choice here) are Mapbox's
/// minimalist data-viz basemaps — by design they omit almost all POI
/// labels/icons (shops, landmarks, institutes), which is why the driver map
/// only ever showed roads and this app's own pins. `streets-v12` and
/// `navigation-night-v1` are the standard, POI-rich equivalents (the latter
/// is themed for exactly this — a dark map read while driving).
///
/// Uses plain style URIs rather than Mapbox Standard's `lightPreset`
/// import-config mechanism (which can flip a 3D style's lighting without a
/// full reload) — that mechanism is unverified against this package
/// version, whereas swapping between two known-good style URIs is
/// guaranteed to work. The tradeoff: a theme toggle destroys and recreates
/// the `MapWidget` (see the `ValueKey` on it in `RouteMapView`), which means
/// annotations are rebuilt from scratch — acceptable for an action the user
/// takes deliberately and rarely.
class MapStyle {
  MapStyle._();

  static String forBrightness(bool isDark) => isDark
      ? 'mapbox://styles/mapbox/navigation-night-v1'
      : 'mapbox://styles/mapbox/streets-v12';
}
