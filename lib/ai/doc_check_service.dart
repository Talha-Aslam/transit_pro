import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import 'ai_reader_client.dart';
import 'doc_matcher.dart';
import 'doc_parser.dart';
import 'ocr_service.dart';

/// The AI check of a driver's licence or registration-card photo. Advisory:
/// the admin still verifies every document.
class DocCheckService {
  DocCheckService._();
  static final DocCheckService instance = DocCheckService._();

  /// Only these two are read; other documents upload as before.
  static bool supports(DocumentType type) =>
      type == DocumentType.drivingLicense ||
      type == DocumentType.vehicleRegistration;

  static bool _isImage(String path) {
    final p = path.toLowerCase();
    return !p.endsWith('.pdf');
  }

  /// The check of [file] as a [type] document, or null when this document
  /// or file type is not checked. Never throws.
  Future<DocCheck?> check(
    File file,
    DocumentType type,
    DocExpectation expectation,
  ) async {
    if (!supports(type) || !_isImage(file.path)) return null;
    final license = type == DocumentType.drivingLicense;
    var reading = DocReading(docType: type.name);
    try {
      final ocr = await OcrService.instance.read(file.path);
      if (!ocr.isEmpty) {
        DocReading parse(List<String> lines) => license
            ? DocParser.parseLicense(lines)
            : DocParser.parseRegistration(lines);
        reading = parse(
          ocr.blockLines,
        ).mergedWith(parse(ocr.rows), fromAi: false);
      }
    } catch (e) {
      debugPrint('document OCR failed: $e');
    }
    if (reading.needsAi) {
      final ai = await AiReaderClient.instance.read(
        kind: license ? AiReadKind.license : AiReadKind.registration,
        file: file,
      );
      if (ai != null) {
        try {
          reading = reading.mergedWith(DocReading.fromAi(type.name, ai));
        } catch (e) {
          debugPrint('document AI answer unusable: $e');
        }
      }
    }
    return evaluateDoc(reading, expectation);
  }
}
