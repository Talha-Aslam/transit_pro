import 'package:flutter/foundation.dart';
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

  final studentInfo = ValueNotifier<StudentInfo>(StudentInfo());
  final guardianInfo = ValueNotifier<GuardianInfo>(GuardianInfo());

  /// Ride statistics, derived from completed trips on this student's route and
  /// their own attendance records.
  ///
  /// Zero until trips exist. The prototype's 42 / 96% / 38 were invented, and a
  /// brand-new student showing 42 completed rides is worse than showing none.
  final totalRides = ValueNotifier<int>(0);
  final onTimeRate = ValueNotifier<int>(0);
  final safeRides = ValueNotifier<int>(0);

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
      feesPaid.value = '';
      _statsForRouteId = null;
      _guardianForParentId = null;
      return;
    }

    if (user.role != UserRole.student) return;

    final bus = session.bus.value;
    final route = session.route.value;
    final driver = session.driverFor(bus?.driverId);

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
}
