import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:transit_core/transit_core.dart';

/// What the Worker's Gemini reader is asked to read.
enum AiReadKind { slip, license, registration, cnic }

/// The Gemini fallback, through the Worker: `POST {pushWorkerUrl}/ai/read`.
///
/// Used only when on-device OCR could not read the fields that matter. The
/// Gemini key lives in the Worker as a secret — never in this app — and the
/// Worker only answers a signed-in user of this project.
///
/// Best-effort: every failure (no Worker, no key on the Worker, timeout, bad
/// answer) returns null and the caller keeps its OCR-only result.
class AiReaderClient {
  AiReaderClient._();
  static final AiReaderClient instance = AiReaderClient._();

  /// Overridable for tests.
  @visibleForTesting
  http.Client client = http.Client();

  static const timeout = Duration(seconds: 30);

  /// Longest side of the image sent, in pixels.
  static const maxSide = 1280;

  bool get isConfigured => AppConfig.pushWorkerUrl.isNotEmpty;

  /// Gemini's JSON reading of [file], or null.
  Future<Map<String, dynamic>?> read({
    required AiReadKind kind,
    required File file,
  }) async {
    if (!isConfigured) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final jpeg = await shrinkToJpeg(file);
      if (jpeg == null) return null;
      final idToken = await user.getIdToken();
      if (idToken == null) return null;
      final response = await client
          .post(
            Uri.parse('${AppConfig.pushWorkerUrl}/ai/read'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode({
              'kind': kind.name,
              'mimeType': 'image/jpeg',
              'imageBase64': base64Encode(jpeg),
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        // 503 ai_unavailable: no key on the Worker — expected, not an error.
        debugPrint('AI read unavailable (${response.statusCode})');
        return null;
      }
      final body = json.decode(response.body);
      final result = body is Map ? body['result'] : null;
      return result is Map ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      debugPrint('AI read failed: $e');
      return null;
    }
  }

  /// [file] scaled so its longest side is at most [maxSide], as JPEG.
  ///
  /// Decoded by the engine (any format the phone can show — WebP, HEIC…),
  /// encoded off the UI thread.
  static Future<Uint8List?> shrinkToJpeg(File file) async {
    final bytes = await file.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0) return null;
      final scale = math.min(1.0, maxSide / math.max(w, h));
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (w * scale).round()),
        targetHeight: math.max(1, (h * scale).round()),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();
      if (raw == null) return null;
      return compute(_encodeJpeg, (
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
        width,
        height,
      ));
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

Uint8List _encodeJpeg((Uint8List, int, int) args) {
  final (rgba, width, height) = args;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: Uint8List.fromList(rgba).buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 82);
}
