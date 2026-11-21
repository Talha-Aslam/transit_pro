import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

/// The documents a driver must submit, in the order the app asks for them.
///
/// CNIC comes first: it is the identity everything else is checked against.
/// `insuranceCertificate`, `routePermit` and `schoolContract` stay in
/// [DocumentType] so older submissions still render in the admin app, but
/// none of them is asked for or counted any more.
const kRequiredDriverDocuments = <DocumentType>[
  DocumentType.cnic,
  DocumentType.drivingLicense,
  DocumentType.vehicleRegistration,
  DocumentType.medicalFitness,
];

/// The newest submission of each type. A driver re-uploads by creating a new
/// document, so an old rejected attempt must not shadow the latest one.
Map<DocumentType, DriverDocument> latestDocumentByType(
  Iterable<DriverDocument> docs,
) {
  final latest = <DocumentType, DriverDocument>{};
  for (final d in docs) {
    final best = latest[d.type];
    if (best == null ||
        (d.uploadedAt ?? DateTime(0)).isAfter(best.uploadedAt ?? DateTime(0))) {
      latest[d.type] = d;
    }
  }
  return latest;
}

/// Required documents not submitted yet — never uploaded, or the latest
/// upload was rejected and needs replacing. Pending and verified count as
/// submitted.
List<DocumentType> documentsStillNeeded(Iterable<DriverDocument> docs) {
  final latest = latestDocumentByType(docs);
  return [
    for (final t in kRequiredDriverDocuments)
      if (latest[t] == null || latest[t]!.status == DocumentStatus.rejected) t,
  ];
}

/// Required documents whose latest upload was rejected.
List<DocumentType> documentsRejected(Iterable<DriverDocument> docs) {
  final latest = latestDocumentByType(docs);
  return [
    for (final t in kRequiredDriverDocuments)
      if (latest[t]?.status == DocumentStatus.rejected) t,
  ];
}

/// Short display name for a document type.
String driverDocumentName(DocumentType type) => switch (type) {
  DocumentType.cnic => 'CNIC',
  DocumentType.drivingLicense => 'Driving License',
  DocumentType.vehicleRegistration => 'Vehicle Registration',
  DocumentType.medicalFitness => 'Medical Fitness',
  DocumentType.insuranceCertificate => 'Insurance Certificate',
  DocumentType.routePermit => 'Route Permit',
  DocumentType.schoolContract => 'School Contract',
};

/// Sign-up used to file the CNIC photo as `vehicleRegistration` (there was
/// no CNIC type). Those rows are recognisable: sign-up writes the license and
/// the CNIC in one batch, so the mislabelled row was stamped within a moment
/// of a driving-license row and never went through the documents screen's
/// AI check. Returns the ids of the rows that are really the CNIC.
@visibleForTesting
List<String> signupCnicMislabels(Iterable<DriverDocument> docs) {
  final list = docs.toList();
  if (list.any((d) => d.type == DocumentType.cnic)) return const [];
  final licenseTimes = [
    for (final d in list)
      if (d.type == DocumentType.drivingLicense && d.uploadedAt != null)
        d.uploadedAt!,
  ];
  return [
    for (final d in list)
      if (d.type == DocumentType.vehicleRegistration &&
          d.docCheck == null &&
          d.uploadedAt != null &&
          licenseTimes.any(
            (t) => t.difference(d.uploadedAt!).inSeconds.abs() <= 5,
          ))
        d.id,
  ];
}

/// Relabels sign-up CNIC photos that were filed as vehicle registration
/// (see [signupCnicMislabels]). Idempotent and best-effort: a driver may
/// edit their own document's type, never its status.
Future<void> fixSignupCnicMislabels(Iterable<DriverDocument> docs) async {
  for (final id in signupCnicMislabels(docs)) {
    try {
      await Db.fs.collection('documents').doc(id).update({
        'type': DocumentType.cnic.name,
      });
    } catch (e) {
      debugPrint('relabelling sign-up CNIC $id failed: $e');
    }
  }
}
