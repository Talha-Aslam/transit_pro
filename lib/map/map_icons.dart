import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rasterises the bus icon and the five stop-status pins once, app-wide, and
/// caches the PNG bytes.
///
/// Mapbox's [PointAnnotationOptions.image] takes raw bitmap bytes with no
/// scale parameter — a 52×52 PNG renders as 52 *device* pixels, not 52
/// logical ones, so on a 3x phone the icon would come out a third of its
/// intended size. Callers rasterise at `baseSize * devicePixelRatio` and
/// compensate with `iconSize: 1 / devicePixelRatio`.
class MapIcons {
  MapIcons._();

  static final Map<double, Future<Uint8List>> _busCache = {};
  static final Map<String, Future<Uint8List>> _pinCache = {};

  /// A cyan circular bus icon, matching the one `driver_route.dart` used to
  /// paint directly. [dpr] is the device pixel ratio the icon will be shown
  /// at — pass `MediaQuery.devicePixelRatioOf(context)`.
  static Future<Uint8List> bus(double dpr) =>
      _busCache.putIfAbsent(dpr, () => _drawBus(dpr));

  /// A teardrop pin filled with [color], white stroke and inner dot — the
  /// closest match to Google Maps' `defaultMarkerWithHue` pins, since Mapbox
  /// has no built-in hue-tinted marker.
  static Future<Uint8List> pin(Color color, double dpr) {
    final key = '${color.toARGB32()}@$dpr';
    return _pinCache.putIfAbsent(key, () => _drawPin(color, dpr));
  }

  static Future<Uint8List> _drawBus(double dpr) async {
    const baseSize = 52.0;
    final size = baseSize * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    canvas.drawCircle(
      const Offset(26, 26),
      22,
      Paint()..color = AppTheme.driverCyan,
    );
    canvas.drawCircle(
      const Offset(26, 26),
      22,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(10, 15, 42, 31),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );
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
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawCircle(const Offset(17, 31), 4, wheelPaint);
    canvas.drawCircle(const Offset(33, 31), 4, wheelPaint);

    return _toPng(recorder, size);
  }

  static Future<Uint8List> _drawPin(Color color, double dpr) async {
    const baseSize = 40.0;
    final size = baseSize * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    // Teardrop: a circle with a triangular point at the bottom, tip at
    // (20, 38) — matches iconAnchor: BOTTOM in the callers.
    final path = Path()
      ..moveTo(20, 38)
      ..lineTo(9, 20)
      ..arcToPoint(
        const Offset(31, 20),
        radius: const Radius.circular(11),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(const Offset(20, 16), 6, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    return _toPng(recorder, size);
  }

  static Future<Uint8List> _toPng(ui.PictureRecorder recorder, double size) async {
    final picture = recorder.endRecording();
    final sizeInt = size.isFinite && size > 0 ? size.round() : 52;
    final img = await picture.toImage(sizeInt, sizeInt);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
