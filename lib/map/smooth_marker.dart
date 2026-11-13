import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:transit_core/transit_core.dart';

import 'geo_utils.dart';

/// Glides a marker between position updates instead of jumping.
///
/// Positions arrive every few seconds; drawn as they come, the van hops
/// forty metres at a time. This interpolates from where the marker is drawn
/// to the new position over [duration], turning the heading the short way
/// round. Repaints are capped at [frameGap] so a 60 Hz ticker does not push
/// sixty marker updates a second across the platform channel.
class SmoothMarker {
  SmoothMarker({
    required TickerProvider vsync,
    required this.onFrame,
    this.duration = const Duration(milliseconds: 1000),
    this.frameGap = const Duration(milliseconds: 50),
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  final void Function() onFrame;
  final Duration duration;
  final Duration frameGap;
  late final Ticker _ticker;

  GeoCoord? _from;
  GeoCoord? _to;
  double _fromHeading = 0;
  double _toHeading = 0;
  Duration _lastFrame = Duration.zero;

  GeoCoord? position;
  double heading = 0;

  /// Starts a glide to [target]. The first call places the marker directly.
  void moveTo(GeoCoord target, double targetHeading) {
    final current = position;
    if (current == null) {
      position = target;
      heading = targetHeading;
      onFrame();
      return;
    }
    if (_to != null &&
        _to!.lat == target.lat &&
        _to!.lng == target.lng &&
        _toHeading == targetHeading) {
      return;
    }
    _from = current;
    _to = target;
    _fromHeading = heading;
    _toHeading = targetHeading;
    _lastFrame = Duration.zero;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final t = (elapsed.inMicroseconds / duration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    final eased = Curves.easeOutCubic.transform(t);
    position = GeoUtils.lerp(from, to, eased);
    heading = GeoUtils.lerpAngle(_fromHeading, _toHeading, eased);
    final done = t >= 1;
    if (done || elapsed - _lastFrame >= frameGap) {
      _lastFrame = elapsed;
      onFrame();
    }
    if (done) _ticker.stop();
  }

  void dispose() => _ticker.dispose();
}
