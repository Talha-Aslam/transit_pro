import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/fee_billing_service.dart';
import 'package:transit_pro/data/payment_repository.dart';

String read(String p) => File(p).readAsStringSync();

void main() {
  group('the fee on a seat request', () {
    test('travels on the request and is agreed only once accepted', () {
      const asked = RideRequest(
        id: 'd_s',
        requesterId: 'p',
        studentId: 's',
        driverId: 'd',
        scheduleId: 'r',
        feePaisa: 400000,
        feeStatus: FeeStatus.proposed,
        feeDriverNote: 'Includes AC',
      );
      final back = RideRequest.fromMap('d_s', asked.toMap());
      expect(back.feePaisa, 400000);
      expect(back.feeStatus, FeeStatus.proposed);
      expect(back.feeDriverNote, 'Includes AC');
      expect(back.hasAgreedFee, isFalse);
      final agreed = RideRequest.fromMap('d_s', {
        ...asked.toMap(),
        'feeStatus': 'accepted',
      });
      expect(agreed.hasAgreedFee, isTrue);
    });

    test('a request without a fee says nothing about one', () {
      const plain = RideRequest(
        id: 'd_s',
        requesterId: 'p',
        studentId: 's',
        driverId: 'd',
        scheduleId: 'r',
      );
      expect(plain.toMap().containsKey('feeStatus'), isFalse);
      expect(plain.toMap().containsKey('feePaisa'), isFalse);
    });
  });

  group('30-day bills', () {
    test('one period per 30 days begun since the seat was accepted', () {
      final start = DateTime(2026, 11, 1);
      expect(
        [for (final p in FeeBillingService.periodsBegun(start, start)) p.$1],
        [0],
      );
      final later = FeeBillingService.periodsBegun(
        start,
        DateTime(2026, 12, 15),
      );
      expect([for (final p in later) p.$1], [0, 1]);
      expect(later[1].$2, start.add(const Duration(days: 30)));
    });

    test('a bill is due at the end of its 30 days, and has a fixed id', () {
      expect(
        PaymentRepository.billId('d', 's', 2),
        PaymentRepository.billId('d', 's', 2),
      );
      final bill = Payment(
        id: 'b',
        studentId: 's',
        parentId: 'p',
        monthKey: '2026-11',
        amountPaisa: 1,
        periodStart: DateTime(2026, 11, 1),
        dueDate: DateTime(2026, 12, 1),
      );
      expect(bill.isBill, isTrue);
      expect(bill.isOutstanding, isTrue);
      final back = Payment.fromMap('b', bill.toMap());
      expect(back.periodStart, DateTime(2026, 11, 1));
      expect(back.copyWith(status: PaymentStatus.paid).isBill, isTrue);
    });

    test('the agreed fee lives on the student record', () {
      final s = Student(
        id: 's',
        name: 'S',
        parentId: 'p',
        monthlyFeePaisa: 350000,
        feeStartedAt: DateTime(2026, 11, 1),
      );
      final back = Student.fromMap('s', s.toMap());
      expect(back.monthlyFeePaisa, 350000);
      expect(back.feeStartedAt, DateTime(2026, 11, 1));
    });
  });

  group('wiring', () {
    test('the driver can ask a fee, and accept waits for the answer', () {
      final screen = read(
        'lib/screens/driver/driver_ride_requests_screen.dart',
      );
      expect(screen, contains("? 'Fees'"));
      expect(screen, contains('_acceptBlocker'));
      final repo = read('lib/data/ride_request_repository.dart');
      expect(repo, contains('The family has not answered your fee yet.'));
    });

    test('the family answers the fee with a reason', () {
      final screen = read('lib/screens/parent/find_drivers_screen.dart');
      expect(screen, contains('class _FeeAnswer'));
      expect(screen, contains('RideMatchService.instance.answerFee('));
    });

    test('rules let each side do exactly its part', () {
      final rules = read('firestore.rules');
      expect(rules, contains("request.resource.data.feeStatus == 'proposed'"));
      expect(rules, contains("'monthlyFeePaisa', 'feeStartedAt'"));
      expect(
        rules,
        contains('hasAcceptedRequestFor(request.resource.data.studentId)'),
      );
      expect(rules, contains("request.resource.data.status == 'submitted'"));
    });

    test('bills are issued, reminded and paid against', () {
      expect(
        read('lib/app/session_service.dart'),
        contains('FeeBillingService.instance.bindToDriver()'),
      );
      expect(
        read('lib/screens/payments/family_payment_screen.dart'),
        contains('submitProofOnBill('),
      );
      expect(
        read('lib/screens/driver/driver_payment_history_screen.dart'),
        contains('FeeBillingService.instance.remind(payment)'),
      );
    });

    test('no profile shows the push test button', () {
      for (final p in [
        'lib/screens/driver/driver_profile.dart',
        'lib/screens/parent/parent_profile.dart',
        'lib/screens/student/student_profile.dart',
      ]) {
        expect(read(p), isNot(contains('runPushTest(context)')), reason: p);
      }
    });
  });
}
