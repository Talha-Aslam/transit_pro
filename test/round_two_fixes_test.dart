import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group("seats are the vehicle's, not the sum of its rounds", () {
    const twelveSeater = Driver(
      id: 'd',
      name: 'D',
      schedules: [
        DriverSchedule(
          id: 'a',
          label: 'Round 1',
          pickupStart: '06:30',
          totalSeats: 12,
          bookedSeats: 4,
        ),
        DriverSchedule(
          id: 'b',
          label: 'Round 2',
          pickupStart: '10:00',
          totalSeats: 12,
          bookedSeats: 1,
        ),
      ],
    );

    test('a 12-seater running two rounds has twelve seats', () {
      // The reported bug exactly: the old figure was 24.
      expect(twelveSeater.vehicleSeats, 12);
    });

    test('free seats are the best single round, not a sum', () {
      // 8 free on one and 11 on the other is not "19 seats available":
      // a family of three could not have taken three of those.
      expect(twelveSeater.bestAvailableSeats, 11);
      expect(twelveSeater.totalAvailableSeats, 19);
    });

    test('a driver with no rounds claims nothing', () {
      const empty = Driver(id: 'd', name: 'D');
      expect(empty.vehicleSeats, 0);
      expect(empty.bestAvailableSeats, 0);
    });

    test('no screen still prints the summed figure', () {
      for (final path in [
        'lib/screens/driver/driver_dashboard.dart',
        'lib/screens/driver/driver_profile.dart',
        'lib/screens/driver/driver_booked_students_screen.dart',
        'lib/screens/parent/driver_details_screen.dart',
        'lib/screens/parent/parent_profile.dart',
      ]) {
        expect(
          read(path).contains('totalSeatsOffered'),
          isFalse,
          reason: '$path still sums seats across rounds',
        );
      }
    });
  });

  group('presence is derived, not a field nobody writes', () {
    test('a driver nobody has heard from is offline', () {
      // `status` says online, but no app has ever checked in.
      const stale = Driver(id: 'd', name: 'D', status: DriverStatus.online);
      expect(stale.isLiveNow, isFalse);
      expect(stale.presenceLabel, 'Offline');
    });

    test('a recent check-in is online', () {
      final live = Driver(
        id: 'd',
        name: 'D',
        status: DriverStatus.online,
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      expect(live.isLiveNow, isTrue);
      expect(live.presenceLabel, 'Online');
    });

    test('an old check-in expires on its own', () {
      // The app the OS killed never got to write `offline`.
      final old = Driver(
        id: 'd',
        name: 'D',
        status: DriverStatus.online,
        lastSeenAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(old.isLiveNow, isFalse);
    });

    test('a running trip says so', () {
      final driving = Driver(
        id: 'd',
        name: 'D',
        status: DriverStatus.onTrip,
        lastSeenAt: DateTime.now(),
      );
      expect(driving.presenceLabel, 'On a trip');
    });

    test('suspension outranks any heartbeat', () {
      final suspended = Driver(
        id: 'd',
        name: 'D',
        status: DriverStatus.suspended,
        lastSeenAt: DateTime.now(),
      );
      expect(suspended.isLiveNow, isFalse);
      expect(suspended.presenceLabel, 'Suspended');
    });

    test('the driver app actually writes it', () {
      expect(read('lib/data/user_repository.dart'), contains('touchPresence'));
      expect(
        read('lib/app/session_service.dart'),
        contains('_touchDriverPresence'),
      );
      expect(
        read('lib/app/trip_session.dart'),
        contains('DriverStatus.onTrip'),
      );
    });

    test('an app can never clear its own pending verification', () {
      // That flag is the admin's; an app that overwrote it would be
      // approving itself.
      expect(
        read('lib/app/session_service.dart'),
        contains('DriverStatus.pendingVerification'),
      );
    });
  });

  group('a soft-deleted record stays deleted', () {
    test('the flag survives a write and a read', () {
      final driver = Driver(
        id: 'd',
        name: 'D',
        isDeleted: true,
        deletedAt: DateTime(2026, 11, 3),
      );
      expect(Driver.fromMap('d', driver.toMap()).isDeleted, isTrue);

      const student = Student(
        id: 's',
        parentId: 'p',
        name: 'S',
        isDeleted: true,
      );
      expect(Student.fromMap('s', student.toMap()).isDeleted, isTrue);
    });

    test('the app hides archived drivers and children', () {
      final repo = read('lib/data/user_repository.dart');
      expect(repo, contains('if (d.isDeleted) continue;'));
      expect(repo, contains('!s.isDeleted'));
    });
  });

  group('missed bus', () {
    test('the rule tolerates a request with no driver field', () {
      // `pruneNulls` means a fresh request has no `assignedDriverId` key at
      // all, and reading an absent field throws inside rule evaluation,
      // which Firestore reports as permission-denied. That was every
      // driver's experience of opening one.
      expect(
        read('firestore.rules'),
        contains("!('assignedDriverId' in resource.data)"),
      );
    });

    test('claiming one is a transaction, not an update', () {
      final repo = read('lib/data/missed_bus_repository.dart');
      expect(repo, contains('runTransaction'));
      expect(repo, contains('RequestAlreadyTakenException'));
    });

    test('raising one alerts the drivers who could take it', () {
      final svc = read('lib/app/missed_bus_service.dart');
      expect(svc, contains('_alertNearbyDrivers'));
      expect(svc, contains('PushSender.instance.notifyMany'));
    });
  });

  group('the map', () {
    test('the vehicle is an arrow', () {
      expect(read('lib/map/map_icons.dart'), contains('_drawArrow'));
      final view = read('lib/map/live_bus_map_view.dart');
      expect(view, contains('MapIcons.arrow'));
      expect(
        view.contains('MapIcons.bus'),
        isFalse,
        reason: 'the bus pictogram no longer marks the vehicle',
      );
    });

    test('the road ahead is drawn from the trip, not fetched per family', () {
      final view = read('lib/map/live_bus_map_view.dart');
      expect(view, contains('polylines: _polylines()'));
      expect(view, contains('route.legs'));
      // A family's map used to ask Google for its own route every 250 m.
      expect(view.contains('RouteService'), isFalse);
      expect(
        read('lib/app/live_bus_service.dart').contains('RouteService'),
        isFalse,
      );
    });

    test('turning Follow on recentres without waiting for a ping', () {
      final view = read('lib/map/live_bus_map_view.dart');
      expect(view, contains('didUpdateWidget'));
      expect(view, contains('_recentre'));
    });

    test('the driver round is ordered by the optimiser', () {
      expect(
        read('lib/app/route_optimization_service.dart'),
        contains("'optimizeWaypointOrder': true"),
      );
      expect(
        read('lib/app/trip_controller.dart'),
        contains('for (final id in result.order)'),
        reason: 'the stop list has to follow the line, or "next stop" lies',
      );
    });

    test('place results come back nearest first', () {
      expect(read('lib/app/route_service.dart'), contains('places.sort('));
      expect(
        read('lib/widgets/profile_form_fields.dart'),
        contains('LocationHint.instance.current()'),
      );
    });

    test('the driver map card no longer paints its own dark slab', () {
      final route = read('lib/screens/driver/driver_route.dart');
      expect(
        route.contains('0xCC05081E'),
        isFalse,
        reason: 'a hardcoded navy card was unreadable in light mode',
      );
      expect(
        route.contains('Live GPS'),
        isFalse,
        reason: 'the simulation toggle is gone from a driving screen',
      );
      expect(route, contains('/driver/track/map'));
    });
  });

  group('names, not ids', () {
    test('the parent track card shows the driver, not their uid', () {
      final track = read('lib/screens/parent/parent_tracking.dart');
      expect(
        track.contains('child?.driver ?? "N/A"'),
        isFalse,
        reason: 'that printed mm0PyLrmAuRvZev1DJ... as the driver name',
      );
      expect(track, contains('driverName'));
      expect(track, contains('_routeLabel(child, trip)'));
    });

    test('the institute location the family picked is kept', () {
      expect(
        read('lib/widgets/profile_form_fields.dart'),
        contains('data.instituteLocation = c'),
      );
      expect(
        read('lib/app/onboarding_service.dart'),
        contains('dropoffLocation: child.instituteLocation'),
      );
    });

    test('the child form asks in the order a family thinks in', () {
      final form = read('lib/widgets/profile_form_fields.dart');
      expect(form, contains("FieldLabel('CLASS / SEMESTER'"));
      expect(form, contains("FieldLabel('ROLL NUMBER'"));
      expect(
        form.contains('PICKUP POINT (OPTIONAL)'),
        isFalse,
        reason: 'it is the field that makes driver matching work',
      );
      // Institute type is asked before the class it qualifies.
      expect(
        form.indexOf("AppStrings.t('grade_level_lbl')"),
        lessThan(form.indexOf("FieldLabel('CLASS / SEMESTER'")),
      );
    });
  });
}
