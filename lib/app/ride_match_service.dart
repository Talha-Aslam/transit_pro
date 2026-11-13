import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/fleet_repository.dart';
import '../data/payment_repository.dart';
import '../data/ride_request_repository.dart';
import '../data/user_repository.dart';
import 'push_sender.dart';
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
/// `notifications/{recipientUid}/items`, which the recipient's inbox streams,
/// and then asks the push Worker to deliver it over FCM — so a seat request
/// reaches a driver whose phone is in their pocket, not only one who happens
/// to have the app open. See [PushSender]; the Worker reads the document back
/// and delivers what is stored, so nothing here can put arbitrary words on
/// someone's lock screen.
class RideMatchService {
  RideMatchService._();
  static final RideMatchService instance = RideMatchService._();

  final _requests = RideRequestRepository.instance;

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
    return UserRepository.instance
        .watchDriversServing(student.school)
        .map(
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
        body:
            '${student.name} (${student.displayCode}) asked for a seat on '
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
        body:
            '${request.studentName} no longer needs the seat on '
            '${request.scheduleLabel}.',
        data: {'requestId': request.id, 'route': '/driver/ride-requests'},
      ),
    );
  }

  /// The family giving up a seat they already hold, with no approval step.
  ///
  /// A parent whose child has changed institute, or who has found a driver
  /// whose timings fit better, should not have to wait for the old driver to
  /// press a button before they can go looking. The driver is told, and their
  /// seat count comes back on its own (see `SeatReconciler`).
  Future<void> giveUpSeat(RideRequest request) async {
    final uid = SessionService.instance.uid;
    if (uid == null || uid != request.requesterId) {
      throw const RideRequestException('That booking is not yours to change.');
    }

    await _requests.releaseByFamily(
      requestId: request.id,
      studentId: request.studentId,
    );

    await _notify(
      request.driverId,
      UserNotification(
        id: '',
        type: NotificationType.rideRequestAnswered,
        title: 'A seat is free again',
        body:
            '${request.studentName} has left ${request.scheduleLabel}. '
            'The seat is back in your count.',
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

    final fee = request.hasAgreedFee ? request.feePaisa : 0;
    await _requests.linkStudentToDriver(
      studentId: request.studentId,
      driverId: driverId,
      scheduleId: request.scheduleId,
      busId: SessionService.instance.driver.value?.busId,
      monthlyFeePaisa: fee,
    );
    // The first 30 days start today, so their bill is issued now — the
    // family sees the agreed fee as due straight away.
    if (fee > 0) {
      try {
        await PaymentRepository.instance.createBill(
          driverId: driverId,
          studentId: request.studentId,
          payerId: request.requesterId,
          amountPaisa: fee,
          periodStart: DateTime.now(),
          period: 0,
        );
      } catch (e) {
        // The billing run on this phone issues it later.
        debugPrint('first bill not issued yet: $e');
      }
    }

    await _notify(
      request.requesterId,
      UserNotification(
        id: '',
        type: NotificationType.pickupAssigned,
        title: 'Seat confirmed',
        body:
            '${request.driverName} accepted ${request.studentName} for '
            '${request.scheduleLabel}.',
        data: {
          'requestId': request.id,
          'studentId': request.studentId,
          'driverId': driverId,
          'route': '/parent/driver-details',
        },
      ),
    );
  }

  /// Where a notification about [request] should open for the family: the
  /// student's own screens when they asked for themselves.
  static String _familyRoute(RideRequest request, String path) =>
      request.requesterId == request.studentId
      ? '/student/$path'
      : '/parent/$path';

  /// The driver names a monthly fee for [request] — or a new one after the
  /// family turned the last down — and the family is told.
  Future<void> proposeFee(
    RideRequest request, {
    required int feePaisa,
    String? note,
  }) async {
    final driverId = SessionService.instance.uid;
    if (driverId == null || driverId != request.driverId) {
      throw const RideRequestException('That request is not yours to answer.');
    }
    if (feePaisa <= 0) {
      throw const RideRequestException('Enter the fee you want per month.');
    }
    await _requests.proposeFee(
      requestId: request.id,
      feePaisa: feePaisa,
      note: note,
    );
    final rupees = (feePaisa / 100).round();
    await _notify(
      request.requesterId,
      UserNotification(
        id: '',
        type: NotificationType.rideRequestAnswered,
        title: 'Fee for ${request.studentName}: Rs.$rupees a month',
        body:
            '${request.driverName} asks Rs.$rupees a month for '
            '${request.scheduleLabel}'
            '${(note ?? '').trim().isEmpty ? '' : ' — "${note!.trim()}"'}. '
            'Tap to accept or reject.',
        data: {
          'requestId': request.id,
          'studentId': request.studentId,
          'route': _familyRoute(request, 'find-drivers'),
        },
      ),
    );
  }

  /// The family's answer to the driver's fee, and the driver is told — with
  /// the family's reason when they say no.
  Future<void> answerFee(
    RideRequest request, {
    required bool accept,
    String? note,
  }) async {
    await _requests.answerFee(
      requestId: request.id,
      accept: accept,
      note: note,
    );
    final rupees = (request.feePaisa / 100).round();
    final reason = (note ?? '').trim();
    await _notify(
      request.driverId,
      UserNotification(
        id: '',
        type: NotificationType.rideRequest,
        title: accept
            ? 'Fee accepted for ${request.studentName}'
            : 'Fee turned down for ${request.studentName}',
        body: accept
            ? 'Rs.$rupees a month is agreed. Accept the seat to book it.'
            : 'They said no to Rs.$rupees a month'
                  '${reason.isEmpty ? '' : ': "$reason"'}. '
                  'Send a new fee, or decline.',
        data: {
          'requestId': request.id,
          'studentId': request.studentId,
          'route': '/driver/ride-requests',
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
        data: {'requestId': request.id, 'studentId': request.studentId},
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
        body:
            '${request.driverName} has removed ${request.studentName} from '
            '${request.scheduleLabel}. You can request another driver.',
        data: {'requestId': request.id, 'studentId': request.studentId},
      ),
    );
  }

  // ── Driver schedule & service-area editing ────────────────────────────────

  /// Saves everything on the driver's My Service screen — schools, starting
  /// point, radius, fare and rounds — as one write.
  ///
  /// Every check runs before anything is written (see [mergeRounds]), so a
  /// refused save stores nothing rather than half an edit.
  ///
  /// Returns false when the write is still waiting for a connection:
  /// Firestore keeps it on the phone and sends it when the network is back,
  /// and the driver's own screens already show it, but the families'
  /// screens will not until then.
  Future<bool> saveService({
    required List<ServiceArea> areas,
    required List<DriverSchedule> rounds,
    int? vehicleCapacity,
    double? radiusKm,
    GeoCoord? baseLocation,
    int? missedBusFarePaisa,
  }) async {
    final driverId = SessionService.instance.uid;
    final live = SessionService.instance.driver.value;
    if (driverId == null || live == null) {
      throw const RideRequestException(
        'Your driver profile is not loaded yet.',
      );
    }
    final merged = mergeRounds(live.schedules, rounds);
    final write = UserRepository.instance.replaceService(
      driverId,
      areas: areas,
      schedules: merged,
      vehicleCapacity: vehicleCapacity,
      radiusKm: radiusKm,
      baseLocation: baseLocation,
      missedBusFarePaisa: missedBusFarePaisa,
    );
    // The bus document carries the same number for screens that read the
    // vehicle; best-effort, the driver's own figure is the one that counts.
    final busId = live.busId ?? '';
    if (vehicleCapacity != null && vehicleCapacity > 0 && busId.isNotEmpty) {
      unawaited(
        FleetRepository.instance
            .updateBus(busId, {'capacity': vehicleCapacity})
            .catchError((Object e) => debugPrint('bus capacity: $e')),
      );
    }
    try {
      await write.timeout(serviceSaveTimeout);
      return true;
    } on TimeoutException {
      // Not lost: queued on the phone. Errors that arrive later still
      // surface in the log rather than vanishing.
      unawaited(
        write.catchError((Object e) => debugPrint('service save failed: $e')),
      );
      return false;
    }
  }

  /// How long a save waits for the server before it is reported as queued.
  static const serviceSaveTimeout = Duration(seconds: 12);

  /// The rounds as they should be stored: the driver's edits, with each
  /// round's `bookedSeats` taken from the *live* document by round id —
  /// never from the form, which has no business knowing how many families
  /// are on a round. Letting it write that field would un-book everyone the
  /// moment a driver corrected a typo in a start time.
  ///
  /// Throws [RideRequestException] instead of shrinking a round below what
  /// is booked, or deleting a round that still has families on it — those
  /// families' records point at the round's id, and their seat would
  /// silently vanish from the count.
  static List<DriverSchedule> mergeRounds(
    List<DriverSchedule> live,
    List<DriverSchedule> edited,
  ) {
    final bookedById = {for (final s in live) s.id: s.bookedSeats};

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

    final removedWithBookings = live.where(
      (s) => s.bookedSeats > 0 && !edited.any((e) => e.id == s.id),
    );
    if (removedWithBookings.isNotEmpty) {
      final names = removedWithBookings.map((s) => '"${s.label}"').join(', ');
      throw RideRequestException(
        'Remove the students on $names before deleting '
        '${removedWithBookings.length == 1 ? 'it' : 'them'}.',
      );
    }
    return merged;
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
      // Was a bare inbox write, which only ever surfaced on a device that
      // happened to have the app open. A driver whose phone was in their
      // pocket learned about a seat request when they next looked at the
      // app — which, for a request that needs answering before tomorrow
      // morning, could be never.
      await PushSender.instance.notifyOne(uid, notification);
    } on FirebaseException catch (e) {
      debugPrint('RideMatchService: notify $uid failed — ${e.code}');
    } catch (e) {
      debugPrint('RideMatchService: notify $uid failed — $e');
    }
  }
}
