import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/fleet_repository.dart';
import '../data/payment_repository.dart';
import '../data/ride_request_repository.dart';
import '../data/user_repository.dart';
import 'notification_service.dart';

/// Where the signed-in user stands, from the router's point of view.
enum SessionState {
  /// No Firebase session.
  signedOut,

  /// Signed in, but the profile has not arrived yet. **The router must not
  /// redirect in this state.** Without it, every cold start would see a null
  /// profile for a few frames and bounce a fully-onboarded user into
  /// onboarding.
  loading,

  /// Signed in, and the `users/{uid}` document was read successfully — it
  /// either doesn't exist yet, or exists with `profileComplete: false`. The
  /// onboarding screen is mandatory here.
  needsProfile,

  /// Signed in with a complete profile.
  ready,

  /// Signed in, but the profile document could not even be *read* —
  /// typically Firestore rejecting the request outright (permission-denied),
  /// not "no profile exists yet". These are not the same failure and must not
  /// be treated alike: the former is a backend/configuration problem no
  /// amount of filling in a form will fix, and routing it into onboarding
  /// anyway just traps the user in a loop that looks like a role-selection
  /// bug but is actually the server refusing every request.
  error,
}

/// The one place any screen can ask "who is signed in, and what do they have?"
///
/// Everything here is fed by Firestore `snapshots()`, so a change made in the
/// admin app — or in the Firebase console — reaches the UI without a restart.
///
/// ## Why this exists
///
/// Screens used to read `ParentDataService.parentInfo`, which was seeded with
/// the literal string `'Sarah Johnson'`. There was no way to ask for the real
/// user because nothing held one. This does, and it also **backfills** those
/// legacy notifiers (see [_backfillLegacyNotifiers]) so the ~9 screens still
/// reading them show live data without being rewritten.
class SessionService extends ChangeNotifier {
  SessionService._();
  static final SessionService instance = SessionService._();

  // ── Public state ──────────────────────────────────────────────────────────

  final state = ValueNotifier<SessionState>(SessionState.signedOut);

  /// `users/{uid}`. Null while loading, or when the account has no profile yet.
  final user = ValueNotifier<AppUser?>(null);

  /// Parent role — every child under this account.
  final children = ValueNotifier<List<Student>>([]);

  /// Student role — this user's own `students/{uid}` record.
  final student = ValueNotifier<Student?>(null);

  /// Driver role — `drivers/{uid}`.
  final driver = ValueNotifier<Driver?>(null);

  /// The vehicle belonging to the signed-in driver, or carrying the selected
  /// child. Null until one is assigned.
  final bus = ValueNotifier<Bus?>(null);

  /// The route the above bus runs. Null until an admin assigns one.
  final route = ValueNotifier<BusRoute?>(null);

  /// Which child the parent is currently looking at. Clamped to the real list
  /// so deleting a child can never leave this pointing past the end.
  final selectedChildIndex = ValueNotifier<int>(0);

  /// Driver role — everyone assigned to the route this driver runs. Backs the
  /// passenger roster and the "N students" figure on the dashboard.
  final routeStudents = ValueNotifier<List<Student>>([]);

  /// Driver role — everyone whose ride request this driver accepted.
  ///
  /// Kept separate from [routeStudents]: that list comes from an admin-assigned
  /// route, which a self-signed-up driver running their own rounds does not
  /// have. In the pilot this is the roster that actually has people in it.
  final roster = ValueNotifier<List<Student>>([]);

  /// Seat requests involving the signed-in user — incoming for a driver,
  /// outgoing for a parent or student. One notifier for both because a given
  /// account is only ever on one side of it.
  final rideRequests = ValueNotifier<List<RideRequest>>([]);

  /// Fee records for whichever side of the transaction this account is on: a
  /// parent's bills, a student's own bills, or a driver's receipts. Newest month
  /// first.
  final payments = ValueNotifier<List<Payment>>([]);

  /// One child's fees, for a parent looking at a specific child. A parent's
  /// `payments` list spans every child, and a fee screen showing another child's
  /// bill under the selected child's name is worse than showing nothing.
  List<Payment> paymentsForStudent(String studentId) =>
      payments.value.where((p) => p.studentId == studentId).toList();

  /// Requests still waiting on the driver. The badge count on their dashboard.
  List<RideRequest> get pendingRideRequests =>
      rideRequests.value.where((r) => r.isPending).toList();

  List<RideRequest> get acceptedRideRequests =>
      rideRequests.value.where((r) => r.isAccepted).toList();

  /// The live request for one child, whatever its state — so the parent's
  /// search results can show "Awaiting reply" on a driver they already asked
  /// instead of offering the button again.
  RideRequest? requestFor({required String studentId, required String driverId}) {
    final id = RideRequest.idFor(driverId: driverId, studentId: studentId);
    for (final r in rideRequests.value) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// The rounds the signed-in driver offers, in reading order. Empty for any
  /// other role.
  List<DriverSchedule> get mySchedules => driver.value?.orderedSchedules ?? const [];

  /// Lookup caches for documents referenced by id.
  ///
  /// A parent with three children can be pointing at three different buses,
  /// routes and drivers. Opening a live stream per reference would be a dozen
  /// listeners for data that changes maybe once a term, so these are fetched
  /// once and cached. The vehicle the user is *actively watching* still gets a
  /// real stream via [bus] and [route].
  final busesById = ValueNotifier<Map<String, Bus>>({});
  final routesById = ValueNotifier<Map<String, BusRoute>>({});
  final driversById = ValueNotifier<Map<String, Driver>>({});

  // ── Derived getters ───────────────────────────────────────────────────────

  String? get uid => _uid;
  UserRole? get role => user.value?.role;
  bool get isReady => state.value == SessionState.ready;
  bool get needsProfile => state.value == SessionState.needsProfile;
  bool get isLoading => state.value == SessionState.loading;
  bool get hasError => state.value == SessionState.error;

  /// Set alongside [SessionState.error] so the UI can say something more
  /// useful than "something went wrong".
  Object? lastError;

  /// The child the parent has selected, or null when they have none.
  Student? get selectedChild {
    final list = children.value;
    if (list.isEmpty) return null;
    return list[selectedChildIndex.value.clamp(0, list.length - 1)];
  }

  Bus? busFor(String? id) => id == null ? null : busesById.value[id];
  BusRoute? routeFor(String? id) => id == null ? null : routesById.value[id];
  Driver? driverFor(String? id) => id == null ? null : driversById.value[id];

  /// Name of the stop a student boards at, resolved through their route.
  String? stopNameFor(Student s) {
    final r = routeFor(s.routeId);
    if (r == null || s.stopId == null) return null;
    return r.stopById(s.stopId!)?.name;
  }

  /// The display name to greet the user with, preferring the Firestore profile
  /// and falling back to whatever Google gave us.
  String get displayName => user.value?.name ?? '';

  String? get photoUrl => user.value?.photoUrl;

  // ── Internals ─────────────────────────────────────────────────────────────

  String? _uid;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Cancelled and re-created whenever the assigned bus or route id changes,
  /// so we never keep a stream open on a vehicle the user no longer rides.
  StreamSubscription<Bus?>? _busSub;
  StreamSubscription<BusRoute?>? _routeSub;
  StreamSubscription<List<Student>>? _routeStudentsSub;
  String? _busId;
  String? _routeId;

  /// Set by the onboarding screen while it is mid-write, so the router does not
  /// yank the user out of the form the instant `profileComplete` flips true
  /// but before the success screen has been shown.
  bool _provisioning = false;
  bool get isProvisioning => _provisioning;
  set provisioning(bool value) {
    if (_provisioning == value) return;
    _provisioning = value;
    notifyListeners();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Begins watching everything belonging to [uid].
  ///
  /// Safe to call repeatedly with the same uid while it's already working — a
  /// no-op. It always re-subscribes after [SessionState.error], though: a
  /// Firestore listener that has errored out is dead and will never emit
  /// again, so treating a same-uid retry as a no-op there would leave the app
  /// silently stuck on a listener that can never recover, even after whatever
  /// caused the error (e.g. undeployed security rules) is fixed.
  Future<void> start(String uid) async {
    final alreadyRunning =
        _uid == uid && state.value != SessionState.signedOut && !hasError;
    if (alreadyRunning) return;

    await stop(notify: false);
    _uid = uid;
    _setState(SessionState.loading);

    // Hooked here rather than at each of the four `start()` call sites in
    // AuthService, so a new sign-in path cannot forget it and leave the user with
    // an empty notification list.
    NotificationService.instance.bindToUser(uid);

    _subs.add(
      UserRepository.instance.watchUser(uid).listen(
        _onUser,
        onError: (Object e) {
          debugPrint('SessionService: user stream failed — $e');
          // This is the listener *erroring* — permission-denied, a backend
          // outage — not a successful read that simply found no document. A
          // missing document comes through _onUser(null) below and correctly
          // means "needs onboarding"; this means "we don't actually know",
          // and must never be reported as the former. Conflating the two is
          // what used to send a user hitting a Firestore rules problem into
          // an onboarding loop with no way out, since retrying the exact same
          // broken request always fails identically.
          lastError = e;
          _setState(SessionState.error);
        },
      ),
    );
  }

  /// Tears the session down. Called on sign-out.
  Future<void> stop({bool notify = true}) async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _busSub?.cancel();
    await _routeSub?.cancel();
    await _routeStudentsSub?.cancel();
    _busSub = null;
    _routeSub = null;
    _routeStudentsSub = null;
    _busId = null;
    _routeId = null;
    _uid = null;
    _provisioning = false;
    lastError = null;

    selectedChildIndex.removeListener(_onSelectedChildChanged);
    _subscribedRole = null;

    // Notifications are per-account. Leaving them would show one family's alerts
    // to the next person signing in on a shared phone.
    NotificationService.instance.unbind();

    user.value = null;
    children.value = [];
    student.value = null;
    driver.value = null;
    bus.value = null;
    route.value = null;
    routeStudents.value = [];
    roster.value = [];
    rideRequests.value = [];
    payments.value = [];
    selectedChildIndex.value = 0;

    // Caches are per-account. Keeping them would leak one family's bus and
    // driver names into the next account signed in on this device.
    busesById.value = {};
    routesById.value = {};
    driversById.value = {};

    // Push the cleared state out so the legacy notifiers empty too, rather
    // than keeping the previous user's name on screen behind the login form.
    _backfillForRole();

    if (notify) {
      _setState(SessionState.signedOut);
    } else {
      state.value = SessionState.signedOut;
    }
  }

  /// Forces a re-read. Rarely needed — the streams handle it — but useful right
  /// after onboarding writes, when the caller wants to be certain before it
  /// navigates.
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    final fresh = await UserRepository.instance.fetchUser(uid);
    if (fresh != null) _onUser(fresh);
  }

  // ── Stream handlers ───────────────────────────────────────────────────────

  void _onUser(AppUser? next) {
    // A successful emission after a prior error (the listener was replaced by
    // a fresh `start()` call) means whatever was wrong no longer is.
    lastError = null;
    user.value = next;

    if (next == null) {
      // A successful read that simply found nothing. `AuthService` normally
      // writes the `users/{uid}` document before this stream can even observe
      // its absence, so this mostly covers the brief window right after that
      // write lands, or a genuinely unreachable stale account. Either way,
      // onboarding is the correct destination.
      _setState(SessionState.needsProfile);
      return;
    }

    _subscribeRoleData(next);
    _backfillLegacyNotifiers(next);

    _setState(
      next.profileComplete ? SessionState.ready : SessionState.needsProfile,
    );
  }

  /// Attaches the streams that only matter for one role. Runs once per role —
  /// re-entering with the same role does not re-subscribe.
  UserRole? _subscribedRole;

  void _subscribeRoleData(AppUser u) {
    if (_subscribedRole == u.role) return;
    _subscribedRole = u.role;
    final uid = u.uid;

    switch (u.role) {
      case UserRole.parent:
        _subs.add(
          UserRepository.instance.watchChildren(uid).listen((list) {
            children.value = list;
            if (selectedChildIndex.value >= list.length) {
              selectedChildIndex.value = list.isEmpty ? 0 : list.length - 1;
            }
            _followVehicle(selectedChild?.busId, selectedChild?.routeId);
            _backfillForRole();
            _resolveReferences();
          }, onError: (Object e) => debugPrint('children stream: $e')),
        );
        selectedChildIndex.addListener(_onSelectedChildChanged);
        _watchOutgoingRequests(uid);
        _watchPayments(PaymentRepository.instance.watchForParent(uid));

      case UserRole.student:
        _subs.add(
          UserRepository.instance.watchStudent(uid).listen((s) {
            student.value = s;
            _followVehicle(s?.busId, s?.routeId);
            _backfillForRole();
            _resolveReferences();
          }, onError: (Object e) => debugPrint('student stream: $e')),
        );
        _watchOutgoingRequests(uid);
        _watchPayments(PaymentRepository.instance.watchForStudent(uid));

      case UserRole.driver:
        _subs.add(
          UserRepository.instance.watchDriver(uid).listen((d) {
            driver.value = d;
            // A driver's route usually comes from their bus, not their own
            // record — the admin app assigns the bus to a route.
            _followVehicle(d?.busId, d?.routeId ?? bus.value?.routeId);
            _backfillForRole();
            // Seat counts live inside the driver document, so every accept or
            // release arrives on this stream. Republishing the request list here
            // is what makes "2 seats left" on a parent's screen and the driver's
            // own roster move at the same time.
            notifyListeners();
          }, onError: (Object e) => debugPrint('driver stream: $e')),
        );

        // The inbox. All statuses, not just pending — see
        // RideRequestRepository.watchForDriver.
        _subs.add(
          RideRequestRepository.instance.watchForDriver(uid).listen((list) {
            rideRequests.value = list;
            _backfillForRole();
            notifyListeners();
          }, onError: (Object e) => debugPrint('driver requests stream: $e')),
        );

        _subs.add(
          UserRepository.instance.watchRoster(uid).listen((list) {
            roster.value = list;
            _backfillForRole();
          }, onError: (Object e) => debugPrint('roster stream: $e')),
        );

        _watchPayments(PaymentRepository.instance.watchForDriver(uid));

      case UserRole.admin:
        // The admin surface is the separate transit_admin app; nothing to
        // subscribe to here.
        break;
    }
  }

  /// Family side of [rideRequests] — everything this account has asked for.
  ///
  /// A driver's seat counts are read straight off their own document, so a
  /// parent watching an accepted request also needs the driver record it points
  /// at; [_resolveReferences] picks those up from `student.driverId`.
  void _watchOutgoingRequests(String uid) {
    _subs.add(
      RideRequestRepository.instance.watchForRequester(uid).listen((list) {
        rideRequests.value = list;
        _backfillForRole();
        notifyListeners();
      }, onError: (Object e) => debugPrint('ride requests stream: $e')),
    );
  }

  /// Fee records, from whichever query suits the role.
  ///
  /// The stream is passed in rather than the role, because the three
  /// `PaymentRepository` methods differ only in which field they filter on and
  /// this handler is identical for all of them. A `paymentsError` is not tracked
  /// separately: an unreadable fee list is a per-screen problem, and the fee
  /// screens render their own error state from the notifier staying empty rather
  /// than the whole session going into [SessionState.error].
  void _watchPayments(Stream<List<Payment>> stream) {
    _subs.add(
      stream.listen((list) {
        payments.value = list;
        _backfillForRole();
        notifyListeners();
      }, onError: (Object e) => debugPrint('payments stream: $e')),
    );
  }

  void _onSelectedChildChanged() {
    _followVehicle(selectedChild?.busId, selectedChild?.routeId);
    _backfillForRole();
  }

  /// Points the [bus] and [route] notifiers at new ids, tearing down the
  /// previous subscriptions. A null id clears the notifier rather than leaving
  /// a stale vehicle on screen.
  void _followVehicle(String? busId, String? routeId) {
    if (busId != _busId) {
      _busId = busId;
      _busSub?.cancel();
      _busSub = null;
      bus.value = null;
      if (busId != null && busId.isNotEmpty) {
        _busSub = FleetRepository.instance.watchBus(busId).listen(
              (b) {
                bus.value = b;
                _backfillForRole();
              },
              onError: (Object e) => debugPrint('bus stream: $e'),
            );
      }
    }

    if (routeId != _routeId) {
      _routeId = routeId;
      _routeSub?.cancel();
      _routeSub = null;
      route.value = null;
      if (routeId != null && routeId.isNotEmpty) {
        _routeSub = FleetRepository.instance.watchRoute(routeId).listen(
              (r) {
                route.value = r;
                _backfillForRole();
              },
              onError: (Object e) => debugPrint('route stream: $e'),
            );
      }

      // A driver's passenger list is whoever shares their route.
      _routeStudentsSub?.cancel();
      _routeStudentsSub = null;
      routeStudents.value = [];
      if (role == UserRole.driver && routeId != null && routeId.isNotEmpty) {
        _routeStudentsSub =
            UserRepository.instance.watchStudentsOnRoute(routeId).listen(
                  (list) {
                    routeStudents.value = list;
                    _backfillForRole();
                  },
                  onError: (Object e) =>
                      debugPrint('route students stream: $e'),
                );
      }
    }
  }

  /// Fetches any bus, route or driver referenced by the current records that we
  /// have not already cached, then republishes so dependent UI rebuilds.
  ///
  /// One-shot reads, not streams — see [busesById] for why. Failures are
  /// swallowed per id: an unreadable route should leave one child showing
  /// "Not assigned", not blank the whole dashboard.
  Future<void> _resolveReferences() async {
    final busIds = <String>{};
    final routeIds = <String>{};
    final driverIds = <String>{};

    void collect(String? busId, String? routeId, String? driverId) {
      if (busId != null && busId.isNotEmpty) busIds.add(busId);
      if (routeId != null && routeId.isNotEmpty) routeIds.add(routeId);
      // The direct driver link, set when a ride request is accepted. Before
      // this existed a driver was only reachable through their bus, so a family
      // matched to a self-signed-up driver with no admin-assigned route saw
      // "No driver" on every screen even though the booking was live.
      if (driverId != null && driverId.isNotEmpty) driverIds.add(driverId);
    }

    for (final c in children.value) {
      collect(c.busId, c.routeId, c.driverId);
    }
    final s = student.value;
    if (s != null) collect(s.busId, s.routeId, s.driverId);

    final pendingBuses = busIds.difference(busesById.value.keys.toSet());
    final pendingRoutes = routeIds.difference(routesById.value.keys.toSet());

    if (pendingBuses.isNotEmpty) {
      final fetched = <String, Bus>{...busesById.value};
      for (final id in pendingBuses) {
        try {
          final b = await FleetRepository.instance.fetchBus(id);
          if (b != null) fetched[id] = b;
        } catch (e) {
          debugPrint('resolve bus $id: $e');
        }
      }
      busesById.value = fetched;
    }

    if (pendingRoutes.isNotEmpty) {
      final fetched = <String, BusRoute>{...routesById.value};
      for (final id in pendingRoutes) {
        try {
          final r = await FleetRepository.instance.fetchRoute(id);
          if (r != null) fetched[id] = r;
        } catch (e) {
          debugPrint('resolve route $id: $e');
        }
      }
      routesById.value = fetched;
    }

    // Drivers are reachable only once their bus is known.
    for (final id in busIds) {
      final d = busesById.value[id]?.driverId;
      if (d != null && d.isNotEmpty) driverIds.add(d);
    }
    final pendingDrivers = driverIds.difference(driversById.value.keys.toSet());
    if (pendingDrivers.isNotEmpty) {
      final fetched = <String, Driver>{...driversById.value};
      for (final id in pendingDrivers) {
        try {
          final d = await UserRepository.instance.fetchDriver(id);
          if (d != null) fetched[id] = d;
        } catch (e) {
          debugPrint('resolve driver $id: $e');
        }
      }
      driversById.value = fetched;
    }

    if (pendingBuses.isNotEmpty ||
        pendingRoutes.isNotEmpty ||
        pendingDrivers.isNotEmpty) {
      _backfillForRole();
    }
  }

  void _setState(SessionState next) {
    if (state.value == next) return;
    state.value = next;
    notifyListeners();
  }

  // ── Legacy notifier backfill ──────────────────────────────────────────────
  //
  // The three data services predate this class and are read by ~9 screens.
  // Rather than rewrite all of them, we push the live values into the notifiers
  // they already watch. Those services no longer carry hardcoded defaults, so
  // until a stream fires the UI shows an honest empty state.
  //
  // Implemented as callbacks the data services register at construction, so
  // this file does not import them and create a cycle.

  final List<void Function(AppUser)> _userSinks = [];
  final List<VoidCallback> _roleSinks = [];

  /// Registered by each data service so it can mirror the live profile into its
  /// own notifiers.
  void onUser(void Function(AppUser) sink) {
    _userSinks.add(sink);
    final current = user.value;
    if (current != null) sink(current);
  }

  /// Registered by each data service to rebuild role-specific derived values
  /// whenever the child list, driver record, bus or route changes.
  void onRoleData(VoidCallback sink) {
    _roleSinks.add(sink);
    sink();
  }

  void _backfillLegacyNotifiers(AppUser u) {
    for (final sink in _userSinks) {
      sink(u);
    }
    _backfillForRole();
  }

  void _backfillForRole() {
    for (final sink in _roleSinks) {
      sink();
    }
  }

}
