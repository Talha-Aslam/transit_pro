import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/round_display.dart';

void main() {
  group('a round is a pair of legs', () {
    test('both legs survive a write and a read', () {
      const round = DriverSchedule(
        id: 'r1',
        label: 'Round 1',
        pickupStart: '06:30',
        pickupEnd: '07:30',
        dropoffStart: '13:30',
        dropoffEnd: '14:30',
        totalSeats: 12,
        bookedSeats: 3,
        institutes: ['UET', 'Govt College'],
      );
      final back = DriverSchedule.fromMap(round.toMap());
      expect(back.pickupStart, '06:30');
      expect(back.dropoffEnd, '14:30');
      expect(back.institutes, ['UET', 'Govt College']);
      expect(back.availableSeats, 9);
      expect(back.hasPickup, isTrue);
      expect(back.hasDropoff, isTrue);
    });

    test('an evening-only run has no morning leg', () {
      const academy = DriverSchedule(
        id: 'r2',
        label: 'Academy run',
        pickupStart: '17:00',
        pickupEnd: '17:40',
        dropoffStart: '21:00',
        dropoffEnd: '21:45',
      );
      expect(academy.startMinutes, 17 * 60);
      expect(academy.timeRange, '17:00 – 17:40 · 21:00 – 21:45');
    });

    test('a round that only brings children home sorts by that leg', () {
      const homeOnly = DriverSchedule(
        id: 'r3',
        label: 'Afternoon only',
        dropoffStart: '13:30',
      );
      expect(homeOnly.hasPickup, isFalse);
      expect(homeOnly.hasDropoff, isTrue);
      expect(homeOnly.startMinutes, 13 * 60 + 30);
      expect(homeOnly.timeRange, '13:30');
    });
  });

  group('rounds saved before a round was a pair', () {
    // Reading these as pickup-only would have quietly dropped every
    // afternoon run out of the app.
    test('an old pickup round becomes the morning leg', () {
      final s = DriverSchedule.fromMap({
        'id': 'old1',
        'label': 'Morning',
        'direction': 'pickup',
        'startTime': '06:30',
        'endTime': '07:00',
        'totalSeats': 10,
      });
      expect(s.pickupStart, '06:30');
      expect(s.pickupEnd, '07:00');
      expect(s.hasDropoff, isFalse);
    });

    test('an old drop-off round becomes the afternoon leg', () {
      final s = DriverSchedule.fromMap({
        'id': 'old2',
        'label': 'Afternoon',
        'direction': 'dropoff',
        'startTime': '13:30',
        'endTime': '14:15',
      });
      expect(s.hasPickup, isFalse);
      expect(s.dropoffStart, '13:30');
      expect(s.dropoffEnd, '14:15');
    });

    test('an old round with no institutes still matches everyone', () {
      final s = DriverSchedule.fromMap({'id': 'old3', 'label': 'R'});
      expect(s.serves('UET'), isTrue);
      expect(s.serves(''), isFalse);
    });
  });

  group('which round goes where', () {
    const toUni = DriverSchedule(
      id: 'a',
      label: 'Uni run',
      pickupStart: '06:30',
      institutes: ['UET', 'Govt College'],
    );

    test('a listed institute matches, whatever the casing', () {
      expect(toUni.serves('UET'), isTrue);
      expect(toUni.serves('  govt college '), isTrue);
    });

    test('an institute this round never passes does not match', () {
      // The case that mattered: offering a family every round let them book
      // a seat on a trip that never goes near their child's gate.
      expect(toUni.serves('City School'), isFalse);
    });
  });

  group('rounds in words a parent reads', () {
    test('a full round says when the child leaves and when they are back', () {
      const r = DriverSchedule(
        id: 'r',
        label: 'Round 1',
        pickupStart: '06:30',
        pickupEnd: '07:30',
        dropoffStart: '13:30',
        dropoffEnd: '14:30',
      );
      expect(roundSummary(r), 'Picks up 6:30 AM  ·  Home by 2:30 PM');
      final (morning, afternoon) = roundLegLines(r);
      expect(morning, 'Leaves home 6:30 AM, arrives 7:30 AM');
      expect(afternoon, 'Leaves institute 1:30 PM, arrives 2:30 PM');
    });

    test('a one-way round says only the half it runs', () {
      const r = DriverSchedule(id: 'r', label: 'R', pickupStart: '07:00');
      expect(roundSummary(r), 'Picks up 7:00 AM');
      expect(roundLegLines(r).$2, isEmpty);
    });

    test('midnight and noon do not read as 0 or 12 the wrong way', () {
      expect(clock12('00:05'), '12:05 AM');
      expect(clock12('12:00'), '12:00 PM');
      expect(clock12('nonsense'), isEmpty);
    });
  });

  group('ordering', () {
    test('rounds order by the hour they start, not by direction', () {
      // Sorting by direction first put every afternoon run after every
      // morning one, which stopped meaning anything once a round was both.
      final driver = Driver(
        id: 'd',
        name: 'D',
        schedules: const [
          DriverSchedule(id: 'late', label: 'Late', pickupStart: '10:00'),
          DriverSchedule(id: 'early', label: 'Early', pickupStart: '06:30'),
          DriverSchedule(id: 'eve', label: 'Academy', pickupStart: '17:00'),
        ],
      );
      expect(
        driver.orderedSchedules.map((s) => s.id).toList(),
        ['early', 'late', 'eve'],
      );
    });
  });
}
