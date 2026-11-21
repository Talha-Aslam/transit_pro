import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/ai/doc_matcher.dart';
import 'package:transit_pro/ai/doc_parser.dart';
import 'package:transit_pro/ai/slip_parser.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────
//
// In ML Kit block order — each label followed by the value printed under
// it — which is how a card laid out in columns comes back.

/// images/12.png — Punjab e-registration card, front. The registration
/// number is blacked out (in the header and in the MRZ line).
const registrationFront = [
  'Date Of Reg.',
  '15-JAN-2018',
  'Import/Purchase Date',
  'Make',
  'CG 125',
  'Maker Name',
  'HONDA',
  'Type of Body',
  'MOTOR CYCLE/SCO',
  'Colour',
  'BLACK',
  'Seating Capacity',
  '2',
  'Horse Power/CC',
  '125',
  'Year Of Mig',
  '2018',
  'M/V Tax Paid Upto',
  'Lifetime',
  'Laden Weight',
  '100',
  'C<ETD<<<<<<<<<<<<<<',
  '<<<<<<<<<101218<PAK<<<<<<<<<<<<<',
  'PUNJAB E- REGISTRATION CARD',
];

/// images/13.jpg — the back (Form-G), every personal field blacked out.
const registrationBack = [
  'EXCISE & TAXATION DEPARTMENT',
  'GOVERNMENT OF THE PUNJAB',
  'Form-G',
  "Owner's Name",
  'Owner CNIC',
  'Father/Husband Name',
  'Owner Cell No',
  'Chasis No',
  'Prv Reg. No/Vanity No. (if any)',
  'Engine No',
  'Address',
  'Reg No',
];

/// A van's card, front with the plate visible in the MRZ line.
const vanFront = [
  'Date Of Reg.',
  '02-MAR-2019',
  'Make',
  'HIACE',
  'Maker Name',
  'TOYOTA',
  'Type of Body',
  'VAN',
  'Colour',
  'WHITE',
  'Seating Capacity',
  '15',
  'Year Of Mfg',
  '2018',
  'C<ETD<<<<<<<<<<<<<<LEA-18-1234<<<<<<',
];

/// Synthetic Punjab driving licence (no real sample yet), with OCR noise.
const licence = [
  'GOVERNMENT OF THE PUNJAB',
  'DRIVING LICENCE',
  'Name',
  'TALHA ASLAM',
  'Father Name',
  'MUHAMMAD ASLAM',
  'CNIC No.',
  '35202-1234567-1',
  'Licence No.',
  '35202-1234567-1',
  'Issue Date',
  '12-03-2020',
  'Valid Upto',
  '11-03-2025',
  'Allowed Vehicles',
  'M/CYCLE, M/CAR',
  'Date of Birth',
  '01-01-2000',
];

final now = DateTime(2026, 11, 20, 10);

void main() {
  group('vehicle registration', () {
    test('front: a 2-seat motorcycle', () {
      final r = DocParser.parseRegistration(registrationFront);
      expect(r.looksRight, isTrue);
      expect(r.fields['make'], 'CG 125');
      expect(r.fields['makerName'], 'HONDA');
      expect(r.fields['bodyType'], 'MOTOR CYCLE/SCO');
      expect(r.fields['colour'], 'BLACK');
      expect(r.fields['seatingCapacity'], '2');
      expect(r.fields['yearOfManufacture'], '2018');
      expect(
        r.fields['registrationNumber'],
        isNull,
        reason: '"15-JAN-2018" is a date, not a plate',
      );
      expect(r.needsAi, isFalse);

      final c = evaluateDoc(
        r,
        const DocExpectation(driverName: 'Talha Aslam', listedCapacity: 12),
        now: now,
      );
      expect(c.issues, contains(DocCheck.notPassengerVehicle));
      expect(c.issues, contains(DocCheck.seatingMismatch));
      expect(c.fields['listedCapacity'], '12');
      expect(c.messages().join(' '), contains('2 seats'));
    });

    test('back: everything personal blacked out', () {
      final r = DocParser.parseRegistration(registrationBack);
      expect(r.looksRight, isTrue);
      expect(r.fields['ownerName'], isNull);
      expect(r.needsAi, isTrue, reason: 'no key field could be read');
      final c = evaluateDoc(
        r,
        const DocExpectation(driverName: 'Talha'),
        now: now,
      );
      expect(c.issues, isEmpty);
    });

    test('back with an owner who is not the driver is only a note', () {
      final r = DocParser.parseRegistration([
        ...registrationBack.take(3),
        "Owner's Name",
        'ALI RAZA KHAN',
        ...registrationBack.skip(4),
      ]);
      expect(r.fields['ownerName'], 'Ali Raza Khan');
      final c = evaluateDoc(
        r,
        const DocExpectation(driverName: 'Talha Aslam'),
        now: now,
      );
      expect(c.issues, isEmpty);
      expect(c.notes, [DocCheck.ownerDifferent]);
    });

    test(
      'a van matching its listing passes; the plate is read from the MRZ',
      () {
        final r = DocParser.parseRegistration(vanFront);
        expect(r.fields['registrationNumber'], 'LEA-18-1234');
        expect(r.fields['seatingCapacity'], '15');
        final ok = evaluateDoc(
          r,
          const DocExpectation(listedCapacity: 14, listedPlate: 'LEA 1234'),
          now: now,
        );
        expect(ok.issues, isEmpty, reason: 'the card counts the driver seat');
        final wrongPlate = evaluateDoc(
          r,
          const DocExpectation(listedCapacity: 15, listedPlate: 'LEB-5678'),
          now: now,
        );
        expect(wrongPlate.issues, [DocCheck.plateMismatch]);
        final wrongSeats = evaluateDoc(
          r,
          const DocExpectation(listedCapacity: 20),
          now: now,
        );
        expect(wrongSeats.issues, [DocCheck.seatingMismatch]);
      },
    );

    test('a payment screenshot is the wrong document', () {
      final r = DocParser.parseRegistration(const [
        'Transaction Successful',
        'Rs. 1',
        'TID 446804416088',
      ]);
      expect(r.looksRight, isFalse);
      expect(evaluateDoc(r, const DocExpectation(), now: now).issues, [
        DocCheck.wrongDocument,
      ]);
    });

    test('Gemini fills what OCR could not read', () {
      final ocr = DocParser.parseRegistration(registrationBack);
      final ai = DocReading.fromAi(docTypeRegistration, {
        'isVehicleRegistration': true,
        'registrationNumber': 'LEA 18 1234',
        'ownerName': 'Talha Aslam',
        'seatingCapacity': 12,
      });
      final merged = ocr.mergedWith(ai);
      expect(merged.engine, 'ocr+gemini');
      expect(merged.fields['seatingCapacity'], '12');
      expect(merged.fields['registrationNumber'], 'LEA-18-1234');
      final c = evaluateDoc(
        merged,
        const DocExpectation(driverName: 'Talha Aslam', listedCapacity: 12),
        now: now,
      );
      expect(c.issues, isEmpty);
      expect(c.notes, isEmpty);
    });
  });

  group('driving licence', () {
    test('reads a Punjab card', () {
      final r = DocParser.parseLicense(licence);
      expect(r.looksRight, isTrue);
      expect(r.fields['name'], 'Talha Aslam');
      expect(r.fields['fatherName'], 'Muhammad Aslam');
      expect(r.fields['cnicLast4'], '5671');
      expect(
        r.fields['licenseNumber'],
        '•••• 5671',
        reason: 'a CNIC-based licence number keeps only its last four',
      );
      expect(r.issueDate, DateTime(2020, 3, 12));
      expect(r.expiryDate, DateTime(2025, 3, 11));
      expect(r.categories, ['M/CYCLE', 'M/CAR']);
      expect(r.needsAi, isFalse);
    });

    test('expired, private-only licence; the name matches the profile', () {
      final c = evaluateDoc(
        DocParser.parseLicense(licence),
        const DocExpectation(driverName: 'Talha Aslam'),
        now: now,
      );
      expect(c.nameMatchPercent, 100);
      expect(c.issues, contains(DocCheck.expired));
      expect(c.issues, contains(DocCheck.noCommercialCategory));
      expect(c.issues, isNot(contains(DocCheck.nameMismatch)));
      expect(c.expiryDate, DateTime(2025, 3, 11));
      // The full CNIC is never kept.
      expect(c.toMap().toString(), isNot(contains('1234567')));
    });

    test('expiring within 30 days, with LTV', () {
      final soon = [
        for (final l in licence)
          l == '11-03-2025'
              ? '10-12-2026'
              : (l == 'M/CYCLE, M/CAR' ? 'M/CAR, LTV' : l),
      ];
      final c = evaluateDoc(
        DocParser.parseLicense(soon),
        const DocExpectation(driverName: 'Talha Aslam'),
        now: now,
      );
      expect(c.issues, [DocCheck.expiringSoon]);
    });

    test('someone else\'s licence: name match percentage is low', () {
      final c = evaluateDoc(
        DocParser.parseLicense(licence),
        const DocExpectation(driverName: 'Bilal Ahmed'),
        now: now,
      );
      expect(c.nameMatchPercent, lessThan(40));
      expect(c.issues, contains(DocCheck.nameMismatch));
    });

    test('a profile with fewer names is not a mismatch', () {
      final c = evaluateDoc(
        DocParser.parseLicense(licence),
        const DocExpectation(driverName: 'Talha'),
        now: now,
      );
      expect(c.nameMatchPercent, 50);
      expect(c.issues, isNot(contains(DocCheck.nameMismatch)));
    });

    test('no "Valid Upto" label: the latest date is the expiry', () {
      final r = DocParser.parseLicense(const [
        'DRIVING LICENCE',
        'Name TALHA ASLAM',
        'D.O.B 01-01-2000',
        'Issued 12-03-2022',
        '11-03-2027',
        'LTV',
      ]);
      expect(r.expiryDate, DateTime(2027, 3, 11));
    });

    test('a registration card uploaded as a licence is the wrong document', () {
      final c = evaluateDoc(
        DocParser.parseLicense(registrationFront),
        const DocExpectation(driverName: 'Talha Aslam'),
        now: now,
      );
      expect(c.issues, contains(DocCheck.wrongDocument));
    });

    test('blank photo is unreadable', () {
      final c = evaluateDoc(
        DocParser.parseLicense(const []),
        const DocExpectation(),
        now: now,
      );
      expect(c.issues, [DocCheck.unreadable]);
    });
  });

  group('DocCheck model', () {
    test('round-trips through a map and onto a DriverDocument', () {
      final c = evaluateDoc(
        DocParser.parseRegistration(registrationFront),
        const DocExpectation(listedCapacity: 12),
        now: now,
      );
      final doc = DriverDocument.fromMap('d1', {
        'driverId': 'drv',
        'type': 'vehicleRegistration',
        'status': 'pending',
        'docCheck': c.toMap(),
      });
      expect(doc.docCheck?.issues, c.issues);
      expect(doc.docCheck?.fields['bodyType'], 'MOTOR CYCLE/SCO');
      expect(doc.toMap()['docCheck'], isA<Map<String, dynamic>>());
      expect(
        doc.docCheck!.displayFields.map((e) => e.key),
        containsAll(['Body type', 'Seating', 'Listed seats']),
      );
    });
  });

  group('slip parser — block order', () {
    test('NayaPay read label-then-value still finds the total', () {
      final r = SlipParser.parse(const [
        'Amount Sent',
        'Service Fee (Incl. Tax)',
        'Total Amount',
        'Rs. 1',
        'Rs. 0',
        'Rs. 1',
        'Transaction ID',
        '6aff5db31783980fb91ca...',
        'Sent with NayaPay',
      ]);
      expect(r.amountPaisa, 100);
      expect(r.transactionId, '6aff5db31783980fb91ca');
    });
  });
}
