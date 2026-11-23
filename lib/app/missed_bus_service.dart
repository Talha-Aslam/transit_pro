import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart' as core;
import '../data/missed_bus_repository.dart';
import '../models/missed_bus_request.dart';
import '../data/user_repository.dart';
import 'push_sender.dart';
import 'session_service.dart';

/// Bridges the UI's local [MissedBusRequest]/[RequestStatus] model onto the
/// real, Firestore-backed [MissedBusRepository].
///
/// The prototype kept all state in this singleton's RAM, which only ever
/// "worked" because every role ran inside the same process — a request
/// raised by a student never reached a driver on a separate phone. This now
/// writes to and streams from Firestore, translating to/from `transit_core`'s
/// [core.MissedBusRequest] at the boundary so none of the screens that
/// already consume this API had to change shape.
///
/// Subscriptions are driven entirely off [SessionService] (mirroring
/// `DriverDataService`/`StudentDataService`'s own `onUser`/`onRoleData`
/// pattern) rather than by each screen's `initState`/`dispose`. Two
/// independent screens can both read `driverIncomingRequests` — the
/// notifications badge and the pickup-requests list — and neither should be
/// able to kill the other's data by unmounting first.
class MissedBusService {
  MissedBusService._() {
    SessionService.instance.onUser((_) => _resync());
    SessionService.instance.onRoleData(_resync);
  }
  static final MissedBusService instance = MissedBusService._();

  final _repo = MissedBusRepository.instance;
  final _session = SessionService.instance;

  /// The requester's own active request. Null when idle, or when the current
  /// session has nobody to watch (no role, or a parent with no child yet).
  final studentActiveRequest = ValueNotifier<MissedBusRequest?>(null);

  /// The open queue any signed-in driver can see. Empty for any non-driver
  /// session.
  final driverIncomingRequests = ValueNotifier<List<MissedBusRequest>>([]);

  /// The request this driver is currently viewing or has a bid pending on.
  /// Null once the requester accepts/rejects it (or the driver withdraws).
  /// Mirrors [studentActiveRequest]'s "one active thing at a time" shape,
  /// on the driver's side of the same negotiation.
  final driverActiveBid = ValueNotifier<MissedBusRequest?>(null);

  /// The pickup a family accepted from this driver and that is not finished
  /// yet. The driver app opens the job map the moment this appears.
  final driverAcceptedJob = ValueNotifier<core.MissedBusRequest?>(null);

  /// The accepted job the driver app has already opened the map for, so it
  /// is opened automatically once rather than on every rebuild.
  String? openedJobId;
  StreamSubscription<core.MissedBusRequest?>? _jobSub;

  StreamSubscription<core.MissedBusRequest?>? _activeSub;
  String? _watchingStudentId;

  StreamSubscription<List<core.MissedBusRequest>>? _openSub;
  bool _watchingQueue = false;

  StreamSubscription<core.MissedBusRequest?>? _myBidSub;
  String? _watchingDriverId;

  // ── Stop list ──────────────────────────────────────────────────────────────

  /// Real stops on the current session's assigned route. Empty (not a fake
  /// fallback list) when no admin route is assigned yet — which is honest for
  /// a pilot family with no configured route, rather than showing stops that
  /// have nothing to do with this student's actual bus.
  static List<String> get routeStops =>
      SessionService.instance.route.value?.orderedStops
          .map((s) => s.name)
          .where((n) => n.isNotEmpty)
          .toList() ??
      const [];

  // ── Session-driven subscriptions ───────────────────────────────────────────

  void _resync() {
    final user = _session.user.value;
    if (user == null) {
      _stopWatchingActive();
      _stopWatchingQueue();
      _stopWatchingMyBid();
      return;
    }
    switch (user.role) {
      case core.UserRole.student:
        _stopWatchingQueue();
        _stopWatchingMyBid();
        _watchActiveFor(_session.student.value?.id ?? '');
      case core.UserRole.parent:
        _stopWatchingQueue();
        _stopWatchingMyBid();
        _watchActiveFor(_session.selectedChild?.id ?? '');
      case core.UserRole.driver:
        _stopWatchingActive();
        _startWatchingQueue();
        _watchMyBidFor(user.uid);
      case core.UserRole.admin:
        _stopWatchingActive();
        _stopWatchingQueue();
        _stopWatchingMyBid();
    }
  }

  void _watchActiveFor(String studentId) {
    if (studentId == _watchingStudentId) return;
    _activeSub?.cancel();
    _watchingStudentId = studentId;
    if (studentId.isEmpty) {
      _activeSub = null;
      studentActiveRequest.value = null;
      return;
    }
    _activeSub = _repo
        .watchActiveForStudent(studentId)
        .listen(
          (req) =>
              studentActiveRequest.value = req == null ? null : _toLocal(req),
          onError: (Object e) => debugPrint('missed bus watch failed: $e'),
        );
  }

  void _stopWatchingActive() {
    _activeSub?.cancel();
    _activeSub = null;
    _watchingStudentId = null;
    studentActiveRequest.value = null;
  }

  void _startWatchingQueue() {
    if (_watchingQueue) return;
    _watchingQueue = true;
    _openSub = _repo.watchOpenRequests().listen(
      (list) => driverIncomingRequests.value = list.map(_toLocal).toList(),
      onError: (Object e) => debugPrint('missed bus queue failed: $e'),
    );
  }

  void _stopWatchingQueue() {
    _watchingQueue = false;
    _openSub?.cancel();
    _openSub = null;
    driverIncomingRequests.value = [];
  }

  void _watchMyBidFor(String driverId) {
    if (driverId == _watchingDriverId) return;
    _myBidSub?.cancel();
    _watchingDriverId = driverId;
    if (driverId.isEmpty) {
      _myBidSub = null;
      driverActiveBid.value = null;
      return;
    }
    _myBidSub = _repo
        .watchMyActiveBid(driverId)
        .listen(
          (req) => driverActiveBid.value = req == null ? null : _toLocal(req),
          onError: (Object e) =>
              debugPrint('missed bus active bid watch failed: $e'),
        );
    _jobSub?.cancel();
    _jobSub = _repo
        .watchMyAcceptedJob(driverId)
        .listen(
          (req) => driverAcceptedJob.value = req,
          onError: (Object e) =>
              debugPrint('missed bus accepted job watch failed: $e'),
        );
  }

  void _stopWatchingMyBid() {
    _myBidSub?.cancel();
    _myBidSub = null;
    _jobSub?.cancel();
    _jobSub = null;
    _watchingDriverId = null;
    driverActiveBid.value = null;
    driverAcceptedJob.value = null;
  }

  // ── Push to the other side ────────────────────────────────────────────────
  //
  // Every step of the negotiation is pushed to the other party, so a family
  // that raised a request can lock their phone and still hear the moment a
  // driver answers — and the driver hears the family's answer the same way.

  String _familyRoute(core.MissedBusRequest r) => r.requestedBy == r.studentId
      ? '/student/missed-bus'
      : '/parent/missed-bus';

  Future<core.MissedBusRequest?> _fetch(String id) async {
    try {
      return await _repo.fetch(id);
    } catch (e) {
      debugPrint('missed-bus fetch $id failed: $e');
      return null;
    }
  }

  Future<void> _tellFamily(
    String requestId,
    String title,
    String Function(core.MissedBusRequest r) body,
  ) async {
    try {
      final r = await _fetch(requestId);
      if (r == null || r.requestedBy.isEmpty) return;
      await PushSender.instance.notifyOne(
        r.requestedBy,
        core.UserNotification(
          id: '',
          type: core.NotificationType.missedBus,
          title: title,
          body: body(r),
          data: {
            'requestId': requestId,
            'studentId': r.studentId,
            'route': _familyRoute(r),
          },
        ),
      );
    } catch (e) {
      debugPrint('missed-bus family alert failed: $e');
    }
  }

  Future<void> _tellDriver(
    core.MissedBusRequest r,
    String title,
    String body, {
    String route = '/driver/pickup-requests',
  }) async {
    final driverId = r.assignedDriverId ?? '';
    if (driverId.isEmpty) return;
    try {
      await PushSender.instance.notifyOne(
        driverId,
        core.UserNotification(
          id: '',
          type: core.NotificationType.missedBus,
          title: title,
          body: body,
          data: {'requestId': r.id, 'route': route},
        ),
      );
    } catch (e) {
      debugPrint('missed-bus driver alert failed: $e');
    }
  }

  String get _myName {
    final n = _session.driver.value?.name.trim() ?? '';
    return n.isEmpty ? 'A driver' : n;
  }

  // ── Requester side ─────────────────────────────────────────────────────────

  Future<void> raiseRequest({
    required String studentName,
    required String studentId,
    required String missedBusNumber,
    required String assignedRoute,
    required String currentStop,
    required String destination,
    core.GeoCoord? currentStopCoord,
    core.GeoCoord? destinationCoord,
  }) async {
    final requestedBy = _session.uid ?? '';
    final id = await _repo.raiseRequest(
      core.MissedBusRequest(
        id: '',
        studentId: studentId,
        studentName: studentName,
        requestedBy: requestedBy,
        missedBusNumber: missedBusNumber,
        assignedRouteName: assignedRoute,
        currentStopName: currentStop,
        destinationStopName: destination,
        currentStopCoord: currentStopCoord,
        destinationCoord: destinationCoord,
      ),
    );
    unawaited(
      _alertNearbyDrivers(
        requestId: id,
        studentName: studentName,
        studentId: studentId,
        currentStop: currentStop,
        destination: destination,
        from: currentStopCoord,
      ),
    );
  }

  /// Puts the request on the phone of every driver who could take it.
  ///
  /// Best-effort and deliberately not awaited by the caller: the request is
  /// already in Firestore, so a failure here means a driver finds out when
  /// they next open the queue — late, not lost. Without it, the only way
  /// anyone learned a child was stranded was by happening to have that
  /// screen open.
  Future<void> _alertNearbyDrivers({
    required String requestId,
    required String studentName,
    required String studentId,
    required String currentStop,
    required String destination,
    core.GeoCoord? from,
  }) async {
    try {
      final student =
          _session.children.value.where((c) => c.id == studentId).firstOrNull ??
          _session.student.value;
      final institute = student?.school ?? '';
      if (institute.trim().isEmpty) return;

      final candidates = await UserRepository.instance.fetchDriversServing(
        institute,
      );
      final recipients = <String>[
        for (final d in candidates)
          // The same tests the seat search applies, for the same reason: an
          // archived or suspended driver is not an option.
          if (!d.isDeleted && d.status != core.DriverStatus.suspended) d.id,
      ];
      if (recipients.isEmpty) return;

      await PushSender.instance.notifyMany(
        recipients,
        core.UserNotification(
          id: '',
          type: core.NotificationType.missedBus,
          title: 'Someone has missed their bus',
          body:
              '$studentName is waiting at $currentStop and needs to reach '
              '$destination. First driver to open it takes it.',
          data: {'requestId': requestId, 'route': '/driver/pickup-requests'},
        ),
      );
    } catch (e) {
      debugPrint('missed-bus alert failed: $e');
    }
  }

  Future<void> cancelRequest() async {
    final req = studentActiveRequest.value;
    if (req == null) return;
    final before = await _fetch(req.id);
    await _repo.cancelRequest(req.id);
    if (before != null) {
      unawaited(
        _tellDriver(
          before,
          'Pickup request cancelled',
          '${before.studentName} no longer needs the pickup.',
        ),
      );
    }
  }

  /// Dismisses a resolved (declined/no-drivers) request and returns to the
  /// empty form. Writes `cancelled` rather than just clearing the local
  /// value — [MissedBusRepository.watchActiveForStudent] deliberately keeps
  /// declined/no-drivers requests visible until the requester acts on them,
  /// so without this write the same request would reappear the next time
  /// this screen opens.
  Future<void> clearRequest() async {
    final req = studentActiveRequest.value;
    if (req == null) return;
    await _repo.cancelRequest(req.id);
  }

  // ── Driver side ────────────────────────────────────────────────────────────

  /// Guard shared by every driver-initiated step below. Throws [StateError]
  /// with a user-safe message if this driver has no bus assigned yet, or
  /// isn't approved — a pilot driver may have neither.
  void _requireDriverReady() {
    final driver = _session.driver.value;
    final bus = _session.bus.value;
    if (driver == null || bus == null) {
      throw StateError(
        'Your account has no bus assigned yet — ask your admin to assign '
        'one before accepting pickups.',
      );
    }
    if (!driver.isApproved) {
      throw StateError(
        'Your account is still awaiting admin verification — you cannot '
        'accept pickups yet.',
      );
    }
  }

  /// Step 1: a driver taps a request in the open queue to look at it.
  Future<void> startViewing(String requestId) async {
    _requireDriverReady();
    final driver = _session.driver.value!;
    final bus = _session.bus.value!;
    await _repo.markViewing(requestId: requestId, driver: driver, bus: bus);
    unawaited(
      _tellFamily(
        requestId,
        'A driver is looking at your request',
        (r) =>
            '$_myName is checking whether they can collect '
            '${r.studentName}. You will be told their fare next.',
      ),
    );
  }

  /// Step 2: the viewing driver sends a fare offer.
  Future<void> sendBid({
    required String requestId,
    required int farePaisa,
  }) async {
    await _repo.sendBid(requestId: requestId, farePaisa: farePaisa);
    final rupees = (farePaisa / 100).round();
    unawaited(
      _tellFamily(
        requestId,
        '$_myName offered Rs.$rupees',
        (r) =>
            '$_myName can collect ${r.studentName} from '
            '${r.currentStopName} for Rs.$rupees. Open the app to accept or '
            'reject the offer.',
      ),
    );
  }

  /// A driver backs out of a request they're viewing or have bid on, before
  /// the requester has decided — same Firestore effect as the requester
  /// rejecting it: the request reopens for other drivers.
  Future<void> withdrawBid() async {
    final req = driverActiveBid.value;
    if (req == null) return;
    await _repo.rejectOffer(req.id);
    unawaited(
      _tellFamily(
        req.id,
        'Still looking for a driver',
        (r) =>
            '$_myName could not take the pickup for ${r.studentName}. '
            'Other drivers can still answer.',
      ),
    );
  }

  /// The driver has the student on board.
  Future<void> markPickedUp(core.MissedBusRequest job) async {
    await _repo.markPickedUp(job.id);
    unawaited(
      _tellFamily(
        job.id,
        '${job.studentName} has been picked up',
        (r) =>
            '$_myName collected ${r.studentName} and is heading to '
            '${r.destinationStopName}.',
      ),
    );
  }

  /// The student is at the destination — the job is finished.
  Future<void> markCompleted(core.MissedBusRequest job) async {
    await _repo.markCompleted(job.id);
    unawaited(
      _tellFamily(
        job.id,
        '${job.studentName} has been dropped off',
        (r) =>
            '$_myName dropped ${r.studentName} at '
            '${r.destinationStopName}.',
      ),
    );
  }

  // ── Requester side: reviewing a bid ─────────────────────────────────────────

  Future<void> acceptOffer() async {
    final req = studentActiveRequest.value;
    if (req == null) return;
    await _repo.confirmOffer(req.id);
    final r = await _fetch(req.id);
    if (r != null) {
      unawaited(
        _tellDriver(
          r,
          'Offer accepted — go collect ${r.studentName}',
          '${r.studentName} is waiting at ${r.currentStopName}. Tap to open '
              'the route to the pickup and drop-off.',
          route: '/driver/missed-bus-job',
        ),
      );
    }
  }

  Future<void> rejectOffer() async {
    final req = studentActiveRequest.value;
    if (req == null) return;
    // Read before rejecting: rejecting clears the assigned driver.
    final r = await _fetch(req.id);
    await _repo.rejectOffer(req.id);
    if (r != null) {
      unawaited(
        _tellDriver(
          r,
          'Offer declined',
          'The family declined your fare for ${r.studentName}.',
        ),
      );
    }
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  MissedBusRequest _toLocal(core.MissedBusRequest r) => MissedBusRequest(
    id: r.id,
    studentName: r.studentName,
    studentId: r.studentId,
    missedBusNumber: r.missedBusNumber,
    assignedRoute: r.assignedRouteName,
    currentStop: r.currentStopName,
    destination: r.destinationStopName,
    timestamp: r.createdAt ?? DateTime.now(),
    status: _toLocalStatus(r.status),
    assignedDriverName: r.assignedDriverName,
    assignedBusNumber: r.assignedBusNumber,
    assignedDriverPhone: r.assignedDriverPhone,
    assignedDriverPhotoUrl: r.assignedDriverPhotoUrl,
    assignedETA: r.etaMinutes == null ? null : '~${r.etaMinutes} min',
    fareDisplay: r.displayFare,
  );

  RequestStatus _toLocalStatus(core.MissedBusStatus s) => switch (s) {
    core.MissedBusStatus.searching => RequestStatus.searching,
    core.MissedBusStatus.viewing => RequestStatus.viewing,
    core.MissedBusStatus.bidOffered => RequestStatus.bidOffered,
    core.MissedBusStatus.accepted => RequestStatus.accepted,
    core.MissedBusStatus.declined => RequestStatus.declined,
    core.MissedBusStatus.noDrivers => RequestStatus.noDrivers,
    core.MissedBusStatus.cancelled => RequestStatus.cancelled,
    // Never reaches the family's view (the watch excludes it); a finished
    // ride reads as the accepted one it was.
    core.MissedBusStatus.completed => RequestStatus.accepted,
  };
}
