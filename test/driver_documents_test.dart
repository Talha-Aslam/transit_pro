import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/driver_documents.dart';

DriverDocument doc(
  String id,
  DocumentType type, {
  DocumentStatus status = DocumentStatus.pending,
  DateTime? at,
}) => DriverDocument(
  id: id,
  driverId: 'd1',
  type: type,
  status: status,
  uploadedAt: at,
);

void main() {
  final signup = DateTime(2026, 11, 1, 10, 0, 0);

  test('CNIC is asked for first, insurance no longer', () {
    expect(kRequiredDriverDocuments.first, DocumentType.cnic);
    expect(
      kRequiredDriverDocuments,
      isNot(contains(DocumentType.insuranceCertificate)),
    );
  });

  test('sign-up asks for no document photos — Documents does, with the AI '
      'check', () {
    final onboarding = File(
      'lib/app/onboarding_service.dart',
    ).readAsStringSync();
    expect(onboarding, isNot(contains('DriverDocument(')));
    for (final screen in [
      'lib/screens/signup_screen.dart',
      'lib/screens/profile_completion_screen.dart',
    ]) {
      final src = File(screen).readAsStringSync();
      expect(src, isNot(contains('DocumentUploadTile(')), reason: screen);
      expect(src, isNot(contains('HOW FAR')), reason: screen);
    }
    final draft = File('lib/app/profile_draft.dart').readAsStringSync();
    expect(draft, isNot(contains('licensePhoto')));
    expect(draft, isNot(contains("gaps.add('ID card photo')")));
  });

  group('sign-up CNIC filed as vehicle registration', () {
    test('the registration saved with the license at sign-up is the CNIC', () {
      final docs = [
        doc('lic', DocumentType.drivingLicense, at: signup),
        doc(
          'reg',
          DocumentType.vehicleRegistration,
          at: signup.add(const Duration(milliseconds: 3)),
        ),
      ];
      expect(signupCnicMislabels(docs), ['reg']);
    });

    test('a registration uploaded later is a real registration', () {
      final docs = [
        doc('lic', DocumentType.drivingLicense, at: signup),
        doc(
          'reg',
          DocumentType.vehicleRegistration,
          at: signup.add(const Duration(days: 2)),
        ),
      ];
      expect(signupCnicMislabels(docs), isEmpty);
    });

    test('nothing is relabelled once a CNIC exists', () {
      final docs = [
        doc('lic', DocumentType.drivingLicense, at: signup),
        doc('reg', DocumentType.vehicleRegistration, at: signup),
        doc('id', DocumentType.cnic, at: signup),
      ];
      expect(signupCnicMislabels(docs), isEmpty);
    });
  });

  group('verify documents card', () {
    test('lists what is missing, in order', () {
      final docs = [doc('lic', DocumentType.drivingLicense, at: signup)];
      expect(documentsStillNeeded(docs), [
        DocumentType.cnic,
        DocumentType.vehicleRegistration,
        DocumentType.medicalFitness,
      ]);
    });

    test('a rejected document must be uploaded again', () {
      final docs = [
        for (final t in kRequiredDriverDocuments) doc(t.name, t, at: signup),
        doc(
          'lic2',
          DocumentType.drivingLicense,
          status: DocumentStatus.rejected,
          at: signup.add(const Duration(days: 1)),
        ),
      ];
      expect(documentsStillNeeded(docs), [DocumentType.drivingLicense]);
      expect(documentsRejected(docs), [DocumentType.drivingLicense]);
    });

    test('hidden once everything is submitted (pending or verified)', () {
      final docs = [
        for (final t in kRequiredDriverDocuments)
          doc(
            t.name,
            t,
            status: t == DocumentType.cnic
                ? DocumentStatus.verified
                : DocumentStatus.pending,
            at: signup,
          ),
      ];
      expect(documentsStillNeeded(docs), isEmpty);
    });
  });
}
