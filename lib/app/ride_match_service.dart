import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/ride_request_repository.dart';
import '../data/user_repository.dart';
import 'session_service.dart';

/// The driver ↔ family matching flow, end to end.
///
/// Sits between the screens and [RideRequestRepository] so that each user action
/// is one call with one outcome, and so the notification that has to accompany
/// it cannot be forgotten at a call site. The repository stays purely about
/// Firestore; this is where "and tell the other person" lives.
///
/// ## On notifications
///
/// Every trigger point here writes a real document to
/// `notifications/{recipientUid}/items`, which the recipient's inbox streams.
/// That reaches their device.
///
/// It is **not** a push notification. Delivering FCM to another user requires a
/// trusted sender — a Cloud Function or a server holding the FCM server key —
/// and putting that key in the client would hand every installed APK the ability
/// to push to any user. This project has no server component yet, so the inbox
/// record is the real, honest mechanism available: it arrives, it persists, and
/// it is exactly the payload a Cloud Function would later forward. When one is
/// added, it should trigger on writes to this collection rather than duplicating
/// the logic.
class RideMatchService {
  RideMatchService._();
  static final RideMatchService instance = RideMatchService._();

  final _requests = RideRequestRepository.instance;
  final _messaging = MessagingRepository.instance;

  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Drivers who could take [student], best first.
  ///
  /// A live stream rather than a one-shot fetch: seat counts sit inside driver
  /// documents, so a round filling up while the parent is reading the list
  /// updates in place. Without that, the first thing a parent learns about a
  /// full round is the error after tapping Request.
  Stream<List<DriverMatch>> watchMatchesFor(Student student) {
    if (student.school.trim().isEmpty) {
      // No school on the child's record means matchmaking has nothing to match
      // on. An empty list with an explanation on screen beats a query that
      // returns every driver in the city.
      return Stream.value(const []);
    }
    return UserRepository.instance.watchDriversServing(student.school).map(
          (candidates) => UserRepository.instance.rankDriversForStudent(
            candidates: candidates,
            student: student,
          ),
        );
  }

  // ── Family actions ────────────────────────────────────────────────────────

  /// Asks [driver] for a seat on [schedule] for [student].
  ///
  /// Throws [RideRequestException] with a message worth showing the user when the
  /// round has filled, a request is already open, or the child is already booked.
  Future<RideRequest> requestSeat({
    required Student student,
    required Driver driver,
    required DriverSchedule schedule,
    String? note,
  }) async {
    final requesterId = SessionService.instance.uid;
    if (requesterId == null) {
      throw const RideRequestException('You are not signed in.');
    }

    final request = await _requests.send(
      requesterId: requesterId,
      student: student,
      driver: driver,
      schedule: schedule,
      note: note,
    );

    await _notify(
      driver.id,
      UserNotification(
        id: '',
        type: NotificationType.rideRequest,
        title: 'New seat request',
        body: '${student.name} (${student.displayCode}) asked for a seat on '
            '${schedule.label} · ${schedule.timeRange}.',
        data: {
          'requestId': request.id,
          'studentId': student.id,
          'route': '/driver/ride-requests',
        },
      ),
    );

    return request;
  }

  /// The family withdrawing a request the driver has not answered.
  Future<void> cancelRequest(RideRequest request) async {
    await _requests.cancel(request.id);
    await _notify(
      request.driverId,
      UserNotification(
        id: '',
        type: NotificationType.rideRequestAnswered,
        title: 'Request withdrawn',
        body: '${request.studentName} no longer needs the seat on '
            '${request.scheduleLabel}.',
        data: {'requestId': request.id, 'route': '/driver/ride-requests'},
      ),
    );
  }

  // ── Driver actions ────────────────────────────────────────────────────────

  /// Accepts a request: books the seat, then links the student to this driver.
  ///
  /// The two steps are separate on purpose — see
  /// [RideRequestRepository.linkStudentToDriver]. If the link fails after the
  /// seat is booked, this rethrows so the driver sees it, and tapping Accept
  /// again repairs the state without double-booking.
  Future<void> accept(RideRequest request) async {
    final driverId = SessionService.instance.uid;
    if (driverId == null || driverId != request.driverId) {
      throw const RideRequestException('That request is not yours to answer.');
    }
    if (SessionService.instance.driver.value?.isApproved != true) {
      throw const RideRequestException(
        'Your account is still awaiting admin verification — you cannot '
        'accept seat requests yet.',
      );
    }

    await _requests.accept(requestId: request.id, driverId: driverId);

    await _requests.linkStudentToDriver(
      studentId: request.studentId,
      driverId: driverId,
      scheduleId: request.scheduleId,
      busId: SessionService.instance.driver.value?.busId,
    );

    await _notify(
      request.requesterId,
      UserNotification(
        id: '',
        type: NotificationType.pickupAssigned,
        title: 'Seat confirmed',
        body: '${request.driverName} accepted ${request.studentName} for '
            '${request.scheduleLabel}.',
        data: {
          'requestId': request.id,
          'driverId': driverId,
          'route': '/parent/driver-details',
        },
      ),
    );
  }

  Future<void> reject(RideRequest request, {String? reason}) async {
    await _requests.reject(requestId: request.id, responseNote: reason);
    await _notify(
      request.requesterId,
      UserNotification(
        id: '',
        type: NotificationType.rideRequestAnswered,
        title: 'Request declined',
        body: reason == null || reason.trim().isEmpty
            ? '${request.driverName} could not take ${request.studentName} on '
                '${request.scheduleLabel}.'
            : '${request.driverName} declined: ${reason.trim()}',
        data: {'requestId': request.id},
      ),
    );
  }

  /// Removes an accepted student and returns their seat to the round.
  Future<void> release(RideRequest request) async {
    final driverId = SessionService.instance.uid;
    if (driverId == null || driverId != request.driverId) {
      throw const RideRequestException('That booking is not yours to change.');
    }

    await _requests.release(
      requestId: request.id,
      driverId: driverId,
      studentId: request.studentId,
    );

    await _notify(
      request.requesterId,
      UserNotification(
        id: '',
        type: NotificationType.rideRequestAnswered,
        title: 'Seat released',
        body: '${request.driverName} has removed ${request.studentName} from '
            '${request.scheduleLabel}. You can request another driver.',
        data: {'requestId': request.id},
      ),
    );
  }

  // ── Driver schedule & service-area editing ────────────────────────────────

  /// Saves a driver's rounds, preserving the seats already booked on each.
  ///
  /// [edited] carries the driver's intended labels, times and seat totals.
  /// `bookedSeats` is taken from the *live* document, matched by round id, never
  /// from the form — a form has no business knowing how many families are on a
  /// round, and letting it write that field would un-book everyone the moment a
  /// driver corrected a typo in a start time.
  ///
  /// Refuses to shrink a round below what is already booked, which would
  /// otherwise leave `availableSeats` clamped at 0 while the driver believes they
  /// have space and families keep being turned away with no explanation.
  Future<void> saveSchedules(List<DriverSchedule> edited) async {
    final driverId = SessionService.instance.uid;
    final live = SessionService.instance.driver.value;
    if (driverId == null || live == null) {
      throw const RideRequestException('Your driver profile is not loaded yet.');
    }

    final bookedById = {for (final s in live.schedules) s.id: s.bookedSeats};

    final merged = <DriverSchedule>[];
    for (final s in edited) {
      final booked = bookedById[s.id] ?? 0;
      if (s.totalSeats < booked) {
        throw RideRequestException(
          '"${s.label}" already has $booked seat${booked == 1 ? '' : 's'} '
          'booked, so it cannot be set to ${s.totalSeats}. Remove a student '
          'first.',
        );
      }
      merged.add(s.copyWith(bookedSeats: booked));
    }

    // A round the driver deleted still has families on it. Their student records
    // point at a scheduleId that would no longer exist, and their seat would
    // silently vanish from the count.
    final removedWithBookings = live.schedules.where(
      (s) => s.bookedSeats > 0 && !edited.any((e) => e.id == s.id),
    );
    if (removedWithBookings.isNotEmpty) {
      final names = removedWithBookings.map((s) => '"${s.label}"').join(', ');
      throw RideRequestException(
        'Remove the students on $names before deleting '
        '${removedWithBookings.length == 1 ? 'it' : 'them'}.',
      );
    }

    await UserRepository.instance.replaceSchedules(driverId, merged);
  }

  Future<void> saveServiceAreas({
    required List<ServiceArea> areas,
    double? radiusKm,
    GeoCoord? baseLocation,
    int? missedBusFarePaisa,
  }) async {
    final driverId = SessionService.instance.uid;
    if (driverId == null) {
      throw const RideRequestException('You are not signed in.');
    }
    await UserRepository.instance.replaceServiceAreas(
      driverId,
      areas: areas,
      radiusKm: radiusKm,
      baseLocation: baseLocation,
      missedBusFarePaisa: missedBusFarePaisa,
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Best-effort inbox write.
  ///
  /// Deliberately swallows its errors: the seat is already booked and the
  /// request already answered by the time this runs, and surfacing "could not
  /// notify" would make a successful action look like a failure. The state the
  /// user cares about is in Firestore either way, and both screens stream it.
  Future<void> _notify(String uid, UserNotification notification) async {
    if (uid.isEmpty) return;
    try {
      await _messaging.push(uid, notification);
    } on FirebaseException catch (e) {
      debugPrint('RideMatchService: notify $uid failed — ${e.code}');
    } catch (e) {
      debugPrint('RideMatchService: notify $uid failed — $e');
    }
  }
}
