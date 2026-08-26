import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transit_core/transit_core.dart';

import '../data/payment_repository.dart';
import '../data/trip_repository.dart';
import '../data/user_repository.dart';
import 'session_service.dart';

/// The student's profile, flattened for the UI.
///
/// Previously seeded with `'Noorulain'`, `'STU-2042'`, `'Bus #42'` and
/// `'Ahmed Raza'`, which every student saw regardless of who they were. All of
/// it now comes from `users/{uid}`, `students/{uid}` and the bus, route and
/// driver those point at.
class StudentInfo {
  String name;
  String studentId;
  String grade;
  String school;
  String busNumber;
  String route;
  String stop;
  String driverName;
  String driverPhone;

  /// The driver's uid — not a display name, see [driverName] for that.
  /// Needed to query that driver's active trip (`TripRepository
  /// .watchActiveTripForDriver`); kept separate from the legacy
  /// `driverName`/`driverPhone` fields rather than overloading either.
  String driverId;

  StudentInfo({
    this.name = '',
    this.studentId = '',
    this.grade = '',
    this.school = '',
    this.busNumber = '',
    this.route = '',
    this.stop = '',
    this.driverName = '',
    this.driverPhone = '',
    this.driverId = '',
  });

  StudentInfo copyWith({
    String? name,
    String? studentId,
    String? grade,
    String? school,
    String? busNumber,
    String? route,
    String? stop,
    String? driverName,
    String? driverPhone,
    String? driverId,
  }) => StudentInfo(
    name: name ?? this.name,
    studentId: studentId ?? this.studentId,
    grade: grade ?? this.grade,
    school: school ?? this.school,
    busNumber: busNumber ?? this.busNumber,
    route: route ?? this.route,
    stop: stop ?? this.stop,
    driverName: driverName ?? this.driverName,
    driverPhone: driverPhone ?? this.driverPhone,
    driverId: driverId ?? this.driverId,
  );
}

/// The student's parent, read from the parent's own `users/{parentId}` doc.
class GuardianInfo {
  String name;
  String phone;
  String email;

  GuardianInfo({this.name = '', this.phone = '', this.email = ''});

  GuardianInfo copyWith({String? name, String? phone, String? email}) =>
      GuardianInfo(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
      );
}

/// Student-facing view of the live session.
class StudentDataService {
  StudentDataService._() {
    SessionService.instance.onUser((_) => _rebuild());
    SessionService.instance.onRoleData(_rebuild);
  }
  static final StudentDataService instance = StudentDataService._();

  /// Notification toggles stay device-local, same as
  /// `ParentDataService.paymentReminders` — this is a per-phone notification
  /// preference, not data any other account needs to read.
  static const _notificationPrefsKey = 'student_notification_prefs';

  final studentInfo = ValueNotifier<StudentInfo>(StudentInfo());
  final guardianInfo = ValueNotifier<GuardianInfo>(GuardianInfo());

  /// Keys: `'busAlerts'`, `'arrivalAlerts'`, `'delayAlerts'`. Missing keys
  /// default to whatever the caller passes as `fallback` in
  /// [notificationPref] — they were never toggled off, not necessarily off.
  final notificationPrefs = ValueNotifier<Map<String, bool>>({});

  /// Ride statistics, derived from completed trips on this student's route and
  /// their own attendance records.
  ///
  /// Zero until trips exist. The prototype's 42 / 96% / 38 were invented, and a
  /// brand-new student showing 42 completed rides is worse than showing none.
  final totalRides = ValueNotifier<int>(0);
  final onTimeRate = ValueNotifier<int>(0);
  final safeRides = ValueNotifier<int>(0);

  /// Boarded rides whose `markedAt` falls within the current calendar week
  /// (Monday 00:00 through now). Backs the "This Week" summary on
  /// `student_schedule.dart`, replacing what used to be a count derived from
  /// the mock `buildParentTripHistoryEntries` helper.
  final completedRidesThisWeek = ValueNotifier<int>(0);

  /// Total confirmed payments, in whole rupees, formatted for display.
  final feesPaid = ValueNotifier<String>('');

  String? _statsForRouteId;
  String? _guardianForParentId;

  // ── Live rebuild ──────────────────────────────────────────────────────────

  void _rebuild() {
    final session = SessionService.instance;
    final user = session.user.value;
    final student = session.student.value;

    if (user == null) {
      studentInfo.value = StudentInfo();
      guardianInfo.value = GuardianInfo();
      totalRides.value = 0;
      onTimeRate.value = 0;
      safeRides.value = 0;
      completedRidesThisWeek.value = 0;
      feesPaid.value = '';
      _statsForRouteId = null;
      _guardianForParentId = null;
      return;
    }

    if (user.role != UserRole.student) return;

    final bus = session.bus.value;
    final route = session.route.value;
    // Admin-assigned bus first, falling back to the student's own direct
    // `driverId` — the pilot path, where a self-signed-up driver accepted
    // this student's ride request without any `Bus` document existing.
    final driverId = bus?.driverId ?? student?.driverId ?? '';
    final driver = session.driverFor(driverId);

    studentInfo.value = StudentInfo(
      name: user.name,
      studentId: student?.studentIdNumber ?? '',
      grade: student?.grade ?? '',
      school: student?.school ?? '',
      busNumber: bus?.busNumber ?? '',
      route: route?.name ?? '',
      stop: student == null ? '' : (session.stopNameFor(student) ?? ''),
      driverName: driver?.name ?? '',
      driverPhone: driver?.phone ?? '',
      driverId: driverId,
    );

    _loadGuardian(student?.parentId);
    _loadStats(student);
  }

  /// The guardian is a different user document, so it needs its own read. Keyed
  /// on parentId so re-rendering does not re-fetch.
  Future<void> _loadGuardian(String? parentId) async {
    if (parentId == null || parentId.isEmpty) {
      guardianInfo.value = GuardianInfo();
      _guardianForParentId = null;
      return;
    }
    if (_guardianForParentId == parentId) return;
    _guardianForParentId = parentId;

    try {
      final parent = await UserRepository.instance.fetchUser(parentId);
      if (parent == null) return;
      guardianInfo.value = GuardianInfo(
        name: parent.name,
        phone: parent.phone,
        email: parent.email,
      );
    } catch (e) {
      debugPrint('guardian lookup failed: $e');
    }
  }

  /// Ride counts and the on-time percentage, computed from real trips.
  Future<void> _loadStats(Student? student) async {
    final routeId = student?.routeId;
    if (student == null || routeId == null || routeId.isEmpty) {
      totalRides.value = 0;
      onTimeRate.value = 0;
      safeRides.value = 0;
      completedRidesThisWeek.value = 0;
      _statsForRouteId = null;
      _updateFees(student?.id);
      return;
    }
    if (_statsForRouteId == routeId) return;
    _statsForRouteId = routeId;

    try {
      final records = await TripRepository.instance
          .fetchAttendanceForStudent(student.id);

      final boarded = records
          .where((r) => r.status == AttendanceStatus.boarded)
          .length;

      totalRides.value = boarded;
      // A ride with no incident recorded against it is a safe ride. Until the
      // Phase 3 safety layer writes incidents, these two are equal — which is
      // honest, rather than the prototype's unexplained 42 vs 38.
      safeRides.value = boarded;
      onTimeRate.value =
          records.isEmpty ? 0 : ((boarded / records.length) * 100).round();

      // Monday 00:00 of the current week through now. `markedAt` is null for
      // a record that was written but never actually marked (shouldn't
      // happen for a `boarded` status, but guarded anyway rather than
      // trusting it).
      final now = DateTime.now();
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      completedRidesThisWeek.value = records
          .where(
            (r) =>
                r.status == AttendanceStatus.boarded &&
                r.markedAt != null &&
                !r.markedAt!.isBefore(startOfWeek),
          )
          .length;
    } catch (e) {
      debugPrint('student stats failed: $e');
    }

    _updateFees(student.id);
  }

  Future<void> _updateFees(String? studentId) async {
    if (studentId == null || studentId.isEmpty) {
      feesPaid.value = '';
      return;
    }
    try {
      final payments = await PaymentRepository.instance
          .watchForStudent(studentId)
          .first;
      final paisa = payments
          .where((p) => p.status == PaymentStatus.paid)
          .fold<int>(0, (sum, p) => sum + p.amountPaisa);
      feesPaid.value = paisa == 0 ? '' : 'Rs.${(paisa / 100).round()}';
    } catch (e) {
      debugPrint('student fees failed: $e');
    }
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> updateStudentInfo(StudentInfo info) async {
    final uid = SessionService.instance.uid;
    if (uid == null) return;
    studentInfo.value = info;

    await UserRepository.instance.updateUser(uid, {'name': info.name});
    await UserRepository.instance.updateStudent(uid, {
      'name': info.name,
      'studentIdNumber': info.studentId,
      'grade': info.grade,
      'school': info.school,
    });
  }

  /// Guardian details belong to the parent's own account, so this only updates
  /// the local view. A student editing their parent's phone number here must
  /// not rewrite another user's document — the security rules would reject it
  /// anyway.
  void updateGuardianInfo(GuardianInfo info) {
    guardianInfo.value = info;
  }

  // ── Notification preferences (device-local) ────────────────────────────────

  Future<void> loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationPrefsKey);
    if (raw == null || raw.isEmpty) {
      notificationPrefs.value = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      notificationPrefs.value = decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      notificationPrefs.value = {};
    }
  }

  Future<void> setNotificationPref(String key, bool enabled) async {
    final updated = Map<String, bool>.from(notificationPrefs.value);
    updated[key] = enabled;
    notificationPrefs.value = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationPrefsKey, jsonEncode(updated));
  }

  bool notificationPref(String key, {bool fallback = true}) =>
      notificationPrefs.value[key] ?? fallback;
}
