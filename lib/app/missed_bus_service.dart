import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart' as core;
import '../data/missed_bus_repository.dart';
import '../models/missed_bus_request.dart';
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
  }

  void _stopWatchingMyBid() {
    _myBidSub?.cancel();
    _myBidSub = null;
    _watchingDriverId = null;
    driverActiveBid.value = null;
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
    await _repo.raiseRequest(
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
  }

  Future<void> cancelRequest() async {
    final req = studentActiveRequest.value;
    if (req == null) return;
    await _repo.cancelRequest(req.id);
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
  }

  /// Step 2: the viewing driver sends a fare offer.
  Future<void> sendBid({required String requestId, required int farePaisa}) =>
      _repo.sendBid(requestId: requestId, farePaisa: farePaisa);

  /// A driver backs out of a request they're viewing or have bid on, before
  /// the requester has decided — same Firestore effect as the requester
  /// rejecting it: the request reopens for other drivers.
  Future<void> withdrawBid() async {
    final req = driverActiveBid.value;
    if (req == null) return;
    await _repo.rejectOffer(req.id);
  }

  // ── Requester side: reviewing a bid ─────────────────────────────────────────

  Future<void> acceptOffer() async {
    final req = studentActiveRequest.value;
    if (req == null) return;
    await _repo.confirmOffer(req.id);
  }

  Future<void> rejectOffer() async {
    final req = studentActiveRequest.value;
    if (req == null) return;
    await _repo.rejectOffer(req.id);
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
  };
}
