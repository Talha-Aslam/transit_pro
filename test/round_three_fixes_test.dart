import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/weekly_times.dart';
import 'package:transit_pro/screens/driver/driver_service_screen.dart';
import 'package:transit_pro/widgets/payment_presentation.dart';

String read(String p) => File(p).readAsStringSync();

DriverSchedule round(String id, {int seats = 10, int booked = 0}) =>
    DriverSchedule(
      id: id,
      label: id,
      pickupStart: '07:00',
      totalSeats: seats,
      bookedSeats: booked,
    );

void main() {
  group('seats never exceed the vehicle', () {
    test('a round claiming more than the vehicle holds is capped', () {
      final d = Driver(
        id: 'd',
        name: 'D',
        vehicleCapacity: 4,
        schedules: [round('r1', seats: 11, booked: 1), round('r2', seats: 3)],
      );
      expect(d.seatsFreeOn(d.schedules[0]), 3);
      expect(d.seatsFreeOn(d.schedules[1]), 3);
      expect(d.vehicleSeats, 4);
      expect(d.bestAvailableSeats, 3);
      expect(d.roundHasSpace(round('full', seats: 9, booked: 4)), isFalse);
    });

    test('without a capacity the rounds speak for themselves', () {
      final d = Driver(id: 'd', name: 'D', schedules: [round('r1')]);
      expect(d.seatsFreeOn(d.schedules.single), 10);
      expect(d.vehicleSeats, 10);
    });

    test('My Service refuses a round larger than the vehicle', () {
      expect(roundProblem(round('r1', seats: 5), capacity: 4), contains('4'));
      expect(roundProblem(round('r1', seats: 4), capacity: 4), isNull);
    });

    test('the capacity and payout survive a save and reload', () {
      const d = Driver(
        id: 'd',
        name: 'D',
        vehicleCapacity: 7,
        payout: PayoutDetails(
          bankName: 'Meezan',
          accountTitle: 'D',
          accountNumber: 'PK00',
          wallets: [
            WalletAccount(provider: 'JazzCash', name: 'D', number: '0300'),
          ],
        ),
      );
      final back = Driver.fromMap('d', d.toMap());
      expect(back.vehicleCapacity, 7);
      expect(back.payout.accountNumber, 'PK00');
      expect(back.payout.wallets.single.provider, 'JazzCash');
    });
  });

  group("a child's own week", () {
    test("today's school hours come from the family's schedule", () {
      const s = Student(
        id: 's',
        name: 'S',
        parentId: 'p',
        requestedSchedule: {
          'monday': {
            WeeklyTimes.schoolStart: '08:00',
            WeeklyTimes.schoolEnd: '13:30',
            WeeklyTimes.pickup: '07:15',
          },
        },
      );
      final monday = DateTime(2026, 11, 9);
      final t = WeeklyTimes.on(s, monday);
      expect(t.schoolStartAt, '08:00');
      expect(t.schoolEndAt, '13:30');
      expect(t.pickupAt, '07:15');
      expect(WeeklyTimes.on(s, DateTime(2026, 11, 15)).isEmpty, isTrue);
    });

    test('emergency contacts travel on the student record', () {
      const s = Student(
        id: 's',
        name: 'S',
        parentId: 'p',
        guardianName: 'Parent',
        guardianPhone: '0300',
        emergencyContacts: [
          EmergencyContact(name: 'Uncle', relation: 'Uncle', phone: '0311'),
        ],
      );
      final back = Student.fromMap('s', s.toMap());
      expect(back.guardianPhone, '0300');
      expect(back.emergencyContacts.single.phone, '0311');
      expect(back.copyWith(name: 'T').emergencyContacts, hasLength(1));
    });
  });

  group('payments: sent, then checked by the driver', () {
    Payment pay(PaymentStatus s) => Payment(
      id: 'x',
      studentId: 's',
      parentId: 'p',
      monthKey: '2026-11',
      amountPaisa: 500000,
      status: s,
    );

    test('a proof waiting for the driver is neither owed nor paid', () {
      final totals = PaymentTotals.of([
        pay(PaymentStatus.submitted),
        pay(PaymentStatus.rejected),
        pay(PaymentStatus.paid),
      ]);
      expect(totals.paid, 500000);
      expect(totals.outstanding, 0);
      expect(paymentStatusLabel(PaymentStatus.rejected), 'Not received');
    });

    test('how they paid and what the driver said are kept', () {
      const p = Payment(
        id: 'x',
        studentId: 's',
        parentId: 'p',
        monthKey: '2026-11',
        amountPaisa: 1,
        methodName: 'NayaPay',
        driverNote: 'Not in my account',
      );
      final back = Payment.fromMap('x', p.toMap());
      expect(back.methodName, 'NayaPay');
      expect(back.driverNote, 'Not in my account');
    });

    test('card payment is gone from every role', () {
      expect(
        File('lib/screens/parent/payment_screens.dart').existsSync(),
        isFalse,
      );
      final router = read('lib/app/router.dart');
      expect(router, isNot(contains('/parent/payment/card')));
      expect(router, contains('FamilyPaymentScreen'));
      expect(router, contains('/driver/payout'));
    });
  });

  group('wiring', () {
    test('removing a child clears every link to the driver', () {
      final repo = read('lib/data/ride_request_repository.dart');
      expect(
        RegExp(r"'busId': FieldValue\.delete\(\)").allMatches(repo).length,
        2,
      );
    });

    test(
      'switching child, or a child record changing, reaches the screens',
      () {
        final session = read('lib/app/session_service.dart');
        final handler = session.substring(
          session.indexOf('void _onSelectedChildChanged()'),
        );
        expect(
          handler.substring(0, handler.indexOf('}')),
          contains('notifyListeners()'),
        );
      },
    );

    test('dismissing a request sheet no longer disposes a live field', () {
      for (final p in [
        'lib/screens/parent/find_drivers_screen.dart',
        'lib/screens/driver/driver_ride_requests_screen.dart',
      ]) {
        final src = read(p);
        expect(src, contains('TextControllerScope('), reason: p);
        expect(src, isNot(contains('whenComplete(')), reason: p);
      }
    });

    test('picking a driver for a new child really sends the request', () {
      final sheet = read('lib/screens/parent/parent_profile.dart');
      expect(sheet, contains('RideMatchService.instance.requestSeat('));
      expect(sheet, isNot(contains("'Request Sent'")));
      final svc = read('lib/app/parent_data_service.dart');
      expect(svc, isNot(contains("'scheduleId': ?child.scheduleId")));
    });

    test('closed-app pushes have a high-importance channel', () {
      expect(
        read('lib/app/notification_service.dart'),
        contains('createNotificationChannel('),
      );
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        contains('default_notification_channel_id'),
      );
    });

    test('a ride that ended in a drop-off counts as present', () {
      for (final p in [
        'lib/screens/parent/trip_history_screen.dart',
        'lib/screens/student/student_trip_history_screen.dart',
      ]) {
        expect(
          read(p),
          contains('r.status == AttendanceStatus.droppedOff'),
          reason: p,
        );
      }
      expect(
        read('lib/screens/parent/trip_history_screen.dart'),
        isNot(contains("AppStrings.t('on_time')")),
      );
    });

    test('the family map shows each child their own institute', () {
      final map = read('lib/map/live_bus_map_view.dart');
      expect(map, contains('instituteStopFor(id)'));
      expect(map, isNot(contains('destinationStop?.location ??')));
    });

    test('the student schedule has no QR check-out', () {
      final src = read('lib/screens/student/student_schedule.dart');
      expect(src, isNot(contains('qr_checkout')));
      expect(src, contains('/student/weekly-schedule'));
    });
  });
}
