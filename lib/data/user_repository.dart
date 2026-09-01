import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

/// Reads and writes `users/{uid}`, `drivers/{uid}` and `students/{id}`.
class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<AppUser?> fetchUser(String uid) async {
    final snap = await Db.users.doc(uid).get();
    return snap.data();
  }

  Stream<AppUser?> watchUser(String uid) =>
      Db.users.doc(uid).snapshots().map((s) => s.data());

  /// Creates the profile document on sign-up.
  ///
  /// `role` is written here, once, and is thereafter enforced by security
  /// rules — the client can never change it.
  Future<void> createUser(AppUser user) async {
    await Db.users.doc(user.uid).set(user);
    await Db.fs.collection('users').doc(user.uid).update({
      'createdAt': Db.now,
      'updatedAt': Db.now,
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> fields) => Db.fs
      .collection('users')
      .doc(uid)
      .update({...fields, 'updatedAt': Db.now});

  /// Stamps server timestamps on the documents onboarding just created.
  ///
  /// A separate write because `FieldValue.serverTimestamp()` cannot travel
  /// through `withConverter` — the converter serialises a typed model, and a
  /// sentinel is not a model field. Best-effort: a missing `createdAt` is
  /// cosmetic, and failing here must not undo a successful sign-up.
  Future<void> touchCreated(String uid, UserRole role) async {
    final stamps = {'createdAt': Db.now, 'updatedAt': Db.now};
    try {
      await Db.fs
          .collection('users')
          .doc(uid)
          .set(stamps, SetOptions(merge: true));
      if (role == UserRole.driver) {
        await Db.fs
            .collection('drivers')
            .doc(uid)
            .set(stamps, SetOptions(merge: true));
      } else if (role == UserRole.student) {
        await Db.fs
            .collection('students')
            .doc(uid)
            .set(stamps, SetOptions(merge: true));
      }
    } catch (_) {
      // Cosmetic only — leave the account as created.
    }
  }

  /// Registers this device for push. Array union is idempotent, so repeated
  /// app launches don't grow the list.
  Future<void> addFcmToken(String uid, String token) =>
      Db.fs.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

  Future<void> removeFcmToken(String uid, String token) =>
      Db.fs.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

  // ── Students ──────────────────────────────────────────────────────────────

  /// Every child belonging to one parent. This is what the parent dashboard's
  /// child selector binds to.
  Stream<List<Student>> watchChildren(String parentId) =>
      Db.students.where('parentId', isEqualTo: parentId).snapshots().docsList;

  Future<List<Student>> fetchChildren(String parentId) async {
    final snap = await Db.students.where('parentId', isEqualTo: parentId).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Stream<Student?> watchStudent(String studentId) =>
      Db.students.doc(studentId).snapshots().map((s) => s.data());

  Future<Student?> fetchStudent(String studentId) async {
    final snap = await Db.students.doc(studentId).get();
    return snap.data();
  }

  /// The driver's manifest — everyone assigned to a route.
  Stream<List<Student>> watchStudentsOnRoute(String routeId) =>
      Db.students.where('routeId', isEqualTo: routeId).snapshots().docsList;

  Future<String> addStudent(Student student) async {
    final ref = await Db.students.add(student);
    await ref.update({'createdAt': Db.now, 'updatedAt': Db.now});
    return ref.id;
  }

  Future<void> updateStudent(String studentId, Map<String, dynamic> fields) =>
      Db.fs.collection('students').doc(studentId).update({
        ...fields,
        'updatedAt': Db.now,
      });

  Future<void> deleteStudent(String studentId) =>
      Db.students.doc(studentId).delete();

  // ── Drivers ───────────────────────────────────────────────────────────────

  Stream<Driver?> watchDriver(String driverId) =>
      Db.drivers.doc(driverId).snapshots().map((s) => s.data());

  Future<Driver?> fetchDriver(String driverId) async {
    final snap = await Db.drivers.doc(driverId).get();
    return snap.data();
  }

  Future<void> createDriver(Driver driver) async {
    await Db.drivers.doc(driver.id).set(driver);
    await Db.fs.collection('drivers').doc(driver.id).update({
      'createdAt': Db.now,
      'updatedAt': Db.now,
    });
  }

  Future<void> updateDriver(String driverId, Map<String, dynamic> fields) => Db
      .fs
      .collection('drivers')
      .doc(driverId)
      .update({...fields, 'updatedAt': Db.now});

  Future<void> setLocationSharing(String driverId, bool enabled) =>
      updateDriver(driverId, {'locationSharing': enabled});

  /// Replaces a driver's bookable rounds.
  ///
  /// `bookedSeats` travels with each round, so callers must pass rounds they
  /// read from the live driver document rather than rebuilding them from a form
  /// — otherwise editing a start time would reset every seat count to zero and
  /// silently un-book every family on it. The driver schedule editor reads,
  /// mutates and writes back for exactly this reason.
  Future<void> replaceSchedules(
    String driverId,
    List<DriverSchedule> schedules,
  ) => updateDriver(driverId, {
    'schedules': schedules.map((s) => s.toMap()).toList(),
  });

  /// Replaces a driver's service areas, keeping the query mirror in step.
  ///
  /// `serviceSchools` is the normalised list Firestore matches against; writing
  /// the display list without it would leave a driver invisible to search while
  /// looking correctly configured in their own profile — the worst kind of bug,
  /// because the driver has no way to see it. Derived here from the same input,
  /// in one write, so the two cannot diverge.
  Future<void> replaceServiceAreas(
    String driverId, {
    required List<ServiceArea> areas,
    double? radiusKm,
    GeoCoord? baseLocation,
    int? missedBusFarePaisa,
  }) => updateDriver(driverId, {
    'serviceAreas': areas.map((a) => a.toMap()).toList(),
    'serviceSchools': areas
        .map((a) => a.normalizedName)
        .where((n) => n.isNotEmpty)
        .toList(),
    'serviceRadiusKm': ?radiusKm,
    'baseLocation': ?baseLocation?.toMap(),
    'missedBusFarePaisa': ?missedBusFarePaisa,
  });

  /// A driver's compliance documents. Rules allow a driver to `create` a new
  /// attempt at any time but forbid them touching `status`/`verifiedBy` on an
  /// existing one — so a re-upload after rejection is a brand new document,
  /// not an edit of the old one, and this stream can hold several per
  /// [DocumentType] over time. Callers pick the latest by `uploadedAt`.
  Stream<List<DriverDocument>> watchDriverDocuments(String driverId) =>
      Db.documents.where('driverId', isEqualTo: driverId).snapshots().docsList;

  Future<void> submitDriverDocument(DriverDocument document) async {
    final ref = await Db.documents.add(document);
    await ref.update({'uploadedAt': Db.now});
  }

  /// A driver's own roster — everyone whose ride request they accepted.
  ///
  /// Separate from [watchStudentsOnRoute]: that answers "who is on this
  /// admin-assigned route", which is empty for a driver who signed themselves up
  /// and runs their own rounds. This is the roster that actually exists in the
  /// pilot.
  Stream<List<Student>> watchRoster(String driverId) =>
      Db.students.where('driverId', isEqualTo: driverId).snapshots().docsList;

  // ── Driver discovery ──────────────────────────────────────────────────────

  /// Every driver who says they serve [school].
  ///
  /// One `arrayContains` on the normalised name — served by Firestore's
  /// automatic single-field index, so this needs no composite index and cannot
  /// break the way the `payments` queries did. Everything else worth filtering
  /// on (seats free, distance, not suspended) is applied by
  /// [rankDriversForStudent] in memory, because each of those would otherwise
  /// cost another composite index, and `serviceRadiusKm` is not expressible as a
  /// Firestore filter at all without a geohash scheme this pilot does not need.
  Stream<List<Driver>> watchDriversServing(String school) {
    final key = ServiceArea.normalize(school);
    if (key.isEmpty) return Stream.value(const []);
    return Db.drivers
        .where('serviceSchools', arrayContains: key)
        .snapshots()
        .docsList;
  }

  Future<List<Driver>> fetchDriversServing(String school) async {
    final key = ServiceArea.normalize(school);
    if (key.isEmpty) return const [];
    final snap = await Db.drivers
        .where('serviceSchools', arrayContains: key)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Turns raw candidates into ranked, explained matches for one child.
  ///
  /// Pure and synchronous so the ranking can be reasoned about (and changed)
  /// without touching Firestore. Drops nobody for being full — a driver who
  /// serves the school but has no seat today is still the most useful thing on
  /// the screen next week, and hiding them makes the list look emptier than the
  /// city really is. [DriverMatch.hasOpenSeats] lets the UI grey them out
  /// instead.
  ///
  /// Suspended drivers *are* dropped: that is an admin decision about safety,
  /// not a preference for the parent to weigh.
  List<DriverMatch> rankDriversForStudent({
    required List<Driver> candidates,
    required Student student,
  }) {
    final matches = <DriverMatch>[];
    final from = student.pickupLocation;

    for (final d in candidates) {
      if (d.status == DriverStatus.suspended) continue;
      if (!d.coversLocation(from)) continue;

      final matched = d.serviceAreas
          .where(
            (a) => a.normalizedName == ServiceArea.normalize(student.school),
          )
          .toList();

      matches.add(
        DriverMatch(
          driver: d,
          distanceKm: d.distanceKmFrom(from),
          matchedAreas: matched,
          openSchedules: d.orderedSchedules.where((s) => s.hasSpace).toList(),
        ),
      );
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }
}
