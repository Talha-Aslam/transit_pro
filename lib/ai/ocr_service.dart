import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_layout.dart';

/// The text ML Kit found in one image, two ways round.
class OcrText {
  /// One visual row per line ("Amount Sent Rs. 1") — what receipts need.
  final List<String> rows;

  /// ML Kit's own block order (a label, then the value under it) — what
  /// cards laid out in columns need.
  final List<String> blockLines;

  const OcrText({this.rows = const [], this.blockLines = const []});

  static const empty = OcrText();

  bool get isEmpty => rows.isEmpty && blockLines.isEmpty;
}

/// On-device text recognition (Google ML Kit, Latin script). Nothing leaves
/// the phone here.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  /// ML Kit ships for Android and iOS only.
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Reads [path]. Returns [OcrText.empty] when OCR is unavailable or fails —
  /// the caller decides what to do without text.
  Future<OcrText> read(String path) async {
    if (!isSupported) return OcrText.empty;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final fragments = <OcrFragment>[];
      final blockLines = <String>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          blockLines.add(line.text);
          final r = line.boundingBox;
          fragments.add(
            OcrFragment(line.text, r.left, r.top, r.right, r.bottom),
          );
        }
      }
      return OcrText(rows: rowsOf(fragments), blockLines: blockLines);
    } catch (e) {
      debugPrint('OCR failed: $e');
      return OcrText.empty;
    } finally {
      await recognizer.close();
    }
  }
}
