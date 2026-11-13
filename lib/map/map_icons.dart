import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rasterises the bus icon and the five stop-status pins once, app-wide, and
/// caches the PNG bytes.
///
/// `BitmapDescriptor.bytes` takes raw bitmap bytes plus an
/// `imagePixelRatio` — without it a 52×52 PNG renders as 52 *device*
/// pixels, not 52 logical ones, so on a 3x phone the icon would come out a
/// third of its intended size. Callers rasterise at
/// `baseSize * devicePixelRatio` and pass `dpr` as `imagePixelRatio`.
class MapIcons {
  MapIcons._();

  static final Map<double, Future<Uint8List>> _busCache = {};
  static final Map<String, Future<Uint8List>> _pinCache = {};

  /// A cyan circular bus icon, matching the one `driver_route.dart` used to
  /// paint directly. [dpr] is the device pixel ratio the icon will be shown
  /// at — pass `MediaQuery.devicePixelRatioOf(context)`.
  static Future<Uint8List> bus(double dpr) =>
      _busCache.putIfAbsent(dpr, () => _drawBus(dpr));

  /// A teardrop pin filled with [color], white stroke and inner dot —
  /// matches this app's own stop-status palette directly, rather than
  /// `BitmapDescriptor.defaultMarkerWithHue`'s fixed hue wheel.
  static Future<Uint8List> pin(Color color, double dpr) {
    final key = '${color.toARGB32()}@$dpr';
    return _pinCache.putIfAbsent(key, () => _drawPin(color, dpr));
  }

  static final Map<String, Future<Uint8List>> _arrowCache = {};

  /// The navigation arrow, the way a turn-by-turn map draws the vehicle.
  ///
  /// A bus pictogram tells a viewer *what* is moving; at the zoom a family
  /// actually watches, what they want to know is *which way* it is facing —
  /// whether it has turned into their street yet. An arrow carries that in
  /// its shape, so a glance answers it without reading the map around it.
  /// Rotated by the marker's `rotation`, which is the ping's heading.
  static Future<Uint8List> arrow(Color color, double dpr) {
    final key = '${color.toARGB32()}@$dpr';
    return _arrowCache.putIfAbsent(key, () => _drawArrow(color, dpr));
  }

  static Future<Uint8List> _drawArrow(Color color, double dpr) async {
    const baseSize = 54.0;
    final size = baseSize * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    const c = Offset(27, 27);
    // A soft disc under the arrow, so it stays legible over dark map tiles
    // and over the route line it sits on.
    canvas.drawCircle(c, 21, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(
      c,
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Pointing up: the marker is drawn `flat` and rotated to the heading,
    // so "up" here means "the way the vehicle is travelling".
    final path = Path()
      ..moveTo(27, 10)
      ..lineTo(38, 38)
      ..lineTo(27, 31)
      ..lineTo(16, 38)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
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

  static final Map<String, Future<Uint8List>> _numberCache = {};

  /// A numbered stop: the visiting order on a coloured disc, so the map and
  /// the stop list can be read against each other ("stop 2 is Ali").
  /// [label] is drawn as given — a number, or a short glyph like a flag for
  /// the destination.
  static Future<Uint8List> numbered(String label, Color color, double dpr) {
    final key = '$label|${color.toARGB32()}@$dpr';
    return _numberCache.putIfAbsent(
      key,
      () => _drawNumbered(label, color, dpr),
    );
  }

  static Future<Uint8List> _drawNumbered(
    String label,
    Color color,
    double dpr,
  ) async {
    const baseSize = 40.0;
    final size = baseSize * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    // Same teardrop as [pin], tip at (20, 38), with a white face for the
    // label instead of the dot.
    final path = Path()
      ..moveTo(20, 38)
      ..lineTo(8, 20)
      ..arcToPoint(
        const Offset(32, 20),
        radius: const Radius.circular(12),
        clockwise: true,
      )
      ..close();
    canvas.drawShadow(path, Colors.black, 2, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(const Offset(20, 16), 8.5, Paint()..color = Colors.white);

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: label.length > 1 ? 9.5 : 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(20 - text.width / 2, 16 - text.height / 2));

    return _toPng(recorder, size);
  }

  static Future<Uint8List> _toPng(
    ui.PictureRecorder recorder,
    double size,
  ) async {
    final picture = recorder.endRecording();
    final sizeInt = size.isFinite && size > 0 ? size.round() : 52;
    final img = await picture.toImage(sizeInt, sizeInt);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
