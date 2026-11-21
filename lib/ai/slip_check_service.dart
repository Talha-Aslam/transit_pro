import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import 'ai_reader_client.dart';
import 'ocr_service.dart';
import 'slip_matcher.dart';
import 'slip_parser.dart';

/// The AI check of a family's payment screenshot: read it (on-device OCR,
/// Gemini only when OCR fell short), compare it with the bill and the
/// driver, and keep a registry of transaction ids so one screenshot cannot
/// pay two bills.
///
/// Advisory only — nothing here blocks a payment from being sent.
class SlipCheckService {
  SlipCheckService._();
  static final SlipCheckService instance = SlipCheckService._();

  /// `slip_tids/{provider_TID}` → `{paymentId, parentId, driverId, createdAt}`.
  static CollectionReference<Map<String, dynamic>> get _registry =>
      Db.fs.collection('slip_tids');

  /// Reads [file]. Never throws; an unreadable image gives an empty reading.
  Future<SlipReading> read(File file) async {
    var reading = SlipReading.empty;
    try {
      final ocr = await OcrService.instance.read(file.path);
      if (!ocr.isEmpty) {
        // Row order suits "label …… value" receipts; block order catches a
        // value ML Kit kept under its label. Each field from whichever pass
        // read it more confidently.
        reading = SlipParser.parse(
          ocr.rows,
        ).bestOf(SlipParser.parse(ocr.blockLines));
      }
    } catch (e) {
      debugPrint('slip OCR failed: $e');
    }
    if (reading.needsAi) {
      final ai = await AiReaderClient.instance.read(
        kind: AiReadKind.slip,
        file: file,
      );
      if (ai != null) {
        try {
          reading = reading.mergedWith(SlipReading.fromAi(ai));
        } catch (e) {
          debugPrint('slip AI answer unusable: $e');
        }
      }
    }
    return reading;
  }

  /// Whether [reading]'s transaction id is already registered against a
  /// payment other than [paymentId]. False when it cannot be told.
  Future<bool> isDuplicate(SlipReading reading, String paymentId) async {
    final key = reading.registryKey;
    if (key == null) return false;
    try {
      final snap = await _registry.doc(key).get();
      if (!snap.exists) return false;
      return (snap.data()?['paymentId'] ?? '') != paymentId;
    } catch (e) {
      debugPrint('slip registry read failed: $e');
      return false;
    }
  }

  /// Records [reading]'s transaction id against [paymentId]. Returns true
  /// when it turns out to belong to another payment already (two families
  /// racing, or a check that ran offline). Never throws.
  Future<bool> register({
    required SlipReading reading,
    required String paymentId,
    required String parentId,
    required String? driverId,
  }) async {
    final key = reading.registryKey;
    if (key == null) return false;
    try {
      // Create-only by rule: writing over an existing id is an update, and
      // updates are refused — so a refusal means the id is taken.
      await _registry.doc(key).set({
        'paymentId': paymentId,
        'parentId': parentId,
        'driverId': ?driverId,
        'createdAt': Db.now,
      });
      return false;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return isDuplicate(reading, paymentId);
      }
      debugPrint('slip registry write failed: $e');
      return false;
    } catch (e) {
      debugPrint('slip registry write failed: $e');
      return false;
    }
  }

  /// The expectation for paying [payment] (or [amountPaisa] for [monthKey]
  /// when there is no bill) to [driver].
  static SlipExpectation expectationFor({
    required Driver driver,
    required int amountPaisa,
    DateTime? periodStart,
    String? monthKey,
  }) {
    var start = periodStart;
    if (start == null && monthKey != null) {
      final parts = monthKey.split('-');
      if (parts.length == 2) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y != null && m != null) start = DateTime(y, m);
      }
    }
    return SlipExpectation.forDriver(
      amountPaisa: amountPaisa,
      periodStart: start,
      driverName: driver.name,
      payout: driver.payout,
    );
  }
}
