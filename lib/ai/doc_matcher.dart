/// Compares a CNIC, licence or registration card with the driver's profile
/// and produces the [DocCheck] stored on the document.
library;

import 'package:transit_core/transit_core.dart';

import 'doc_parser.dart';
import 'text_utils.dart';

// ── Checks ──────────────────────────────────────────────────────────────────

/// What the driver's profile says, to compare a card against.
class DocExpectation {
  final String driverName;

  /// Seats the driver lists for their vehicle; 0 when unknown.
  final int listedCapacity;

  /// The bus's plate on record; empty when unknown.
  final String listedPlate;

  const DocExpectation({
    this.driverName = '',
    this.listedCapacity = 0,
    this.listedPlate = '',
  });
}

const licenceExpiringSoon = Duration(days: 30);

/// Licence categories that may carry paying passengers.
const commercialCategories = {'LTV', 'HTV', 'PSV'};

final _twoWheeler = RegExp(
  r'motor\s*cycle|motorcycle|m\s*/\s*cycle|scooter|scooty|\bbike\b|\bsco\b',
  caseSensitive: false,
);

DocCheck evaluateDoc(DocReading r, DocExpectation e, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final today = DateTime(at.year, at.month, at.day);
  final issues = <String>[];
  final notes = <String>[];
  final fields = {...r.fields};
  int? nameMatch;

  if (!r.hasText && !r.looksRight) {
    issues.add(DocCheck.unreadable);
  } else if (!r.looksRight) {
    issues.add(DocCheck.wrongDocument);
  }

  /// The holder's name against the profile name.
  void checkName() {
    final name = r.fields['name'];
    if (name == null || e.driverName.trim().isEmpty) return;
    nameMatch = nameMatchPercent(name, e.driverName);
    // A profile that gives fewer names than the card ("Talha" against
    // "Talha Aslam") is not a mismatch.
    if (nameMatch! < 60 && !namesMatch(name, e.driverName)) {
      issues.add(DocCheck.nameMismatch);
    }
  }

  void checkExpiry() {
    final expiry = r.expiryDate;
    if (expiry == null) return;
    if (expiry.isBefore(today)) {
      issues.add(DocCheck.expired);
    } else if (!expiry.isAfter(today.add(licenceExpiringSoon))) {
      issues.add(DocCheck.expiringSoon);
    }
  }

  if (r.isCnic) {
    checkName();
    checkExpiry();
    if (r.fields['side'] == 'back') notes.add(DocCheck.backSideOnly);
  } else if (r.isLicense) {
    checkName();
    checkExpiry();
    if (r.categories.isNotEmpty &&
        !r.categories.any(commercialCategories.contains)) {
      issues.add(DocCheck.noCommercialCategory);
    }
  } else {
    final seats = int.tryParse(r.fields['seatingCapacity'] ?? '');
    final body = r.fields['bodyType'] ?? '';
    if (e.listedCapacity > 0) fields['listedCapacity'] = '${e.listedCapacity}';
    if (e.listedPlate.trim().isNotEmpty) {
      fields['listedPlate'] = e.listedPlate.trim();
    }
    if (_twoWheeler.hasMatch(body) || (seats != null && seats <= 2)) {
      issues.add(DocCheck.notPassengerVehicle);
    }
    // The card counts the driver's seat; the app counts passenger seats —
    // so one more on the card is the same vehicle.
    if (seats != null &&
        e.listedCapacity > 0 &&
        seats != e.listedCapacity &&
        seats != e.listedCapacity + 1) {
      issues.add(DocCheck.seatingMismatch);
    }
    final plate = r.fields['registrationNumber'];
    if (plate != null &&
        e.listedPlate.trim().isNotEmpty &&
        !platesMatch(plate, e.listedPlate)) {
      issues.add(DocCheck.plateMismatch);
    }
    final owner = r.fields['ownerName'];
    if (owner != null &&
        e.driverName.trim().isNotEmpty &&
        !namesMatch(owner, e.driverName)) {
      notes.add(DocCheck.ownerDifferent);
    }
  }

  return DocCheck(
    docType: r.docType,
    fields: fields,
    nameMatchPercent: nameMatch,
    expiryDate: r.expiryDate,
    issues: issues,
    notes: notes,
    engine: r.engine,
    checkedAt: at,
  );
}
