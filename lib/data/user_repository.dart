import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

import 'db.dart';

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

  Future<void> updateUser(String uid, Map<String, dynamic> fields) =>
      Db.fs.collection('users').doc(uid).update({...fields, 'updatedAt': Db.now});

  /// Stamps server timestamps on the documents onboarding just created.
  ///
  /// A separate write because `FieldValue.serverTimestamp()` cannot travel
  /// through `withConverter` — the converter serialises a typed model, and a
  /// sentinel is not a model field. Best-effort: a missing `createdAt` is
  /// cosmetic, and failing here must not undo a successful sign-up.
  Future<void> touchCreated(String uid, UserRole role) async {
    final stamps = {'createdAt': Db.now, 'updatedAt': Db.now};
    try {
      await Db.fs.collection('users').doc(uid).set(stamps, SetOptions(merge: true));
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
  Stream<List<Student>> watchChildren(String parentId) => Db.students
      .where('parentId', isEqualTo: parentId)
      .snapshots()
      .docsList;

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
  Stream<List<Student>> watchStudentsOnRoute(String routeId) => Db.students
      .where('routeId', isEqualTo: routeId)
      .snapshots()
      .docsList;

  Future<String> addStudent(Student student) async {
    final ref = await Db.students.add(student);
    await ref.update({'createdAt': Db.now, 'updatedAt': Db.now});
    return ref.id;
  }

  Future<void> updateStudent(String studentId, Map<String, dynamic> fields) =>
      Db.fs
          .collection('students')
          .doc(studentId)
          .update({...fields, 'updatedAt': Db.now});

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

  Future<void> updateDriver(String driverId, Map<String, dynamic> fields) =>
      Db.fs
          .collection('drivers')
          .doc(driverId)
          .update({...fields, 'updatedAt': Db.now});

  Future<void> setLocationSharing(String driverId, bool enabled) =>
      updateDriver(driverId, {'locationSharing': enabled});
}
