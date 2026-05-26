import 'package:flutter/foundation.dart';

/// Mutable model for the student's profile information.
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
    this.name = 'Noorulain',
    this.studentId = 'STU-2042',
    this.grade = 'Grade 5',
    this.school = 'Lincoln Elementary School',
    this.busNumber = 'Bus #42',
    this.route = 'Route A',
    this.stop = 'Pine Road',
    this.driverName = 'Ahmed Raza',
    this.driverPhone = '+92 300 5554321',
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

/// Mutable model for the student's parent / guardian info.
class GuardianInfo {
  String name;
  String phone;
  String email;

  GuardianInfo({
    this.name = 'Sarah Johnson',
    this.phone = '+92 300 1234567',
    this.email = 'sarah.johnson@example.com',
  });

  GuardianInfo copyWith({String? name, String? phone, String? email}) =>
      GuardianInfo(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
      );
}

/// Singleton that holds the student's profile data and notifies listeners
/// whenever the data changes.
class StudentDataService {
  StudentDataService._();
  static final StudentDataService instance = StudentDataService._();

  /// Notifier for the student's own info.
  final studentInfo = ValueNotifier<StudentInfo>(StudentInfo());

  /// Notifier for the guardian's info.
  final guardianInfo = ValueNotifier<GuardianInfo>(GuardianInfo());

  /// Tracking statistics
  final totalRides = ValueNotifier<int>(42);
  final onTimeRate = ValueNotifier<int>(96);
  final safeRides = ValueNotifier<int>(38);
  final feesPaid = ValueNotifier<String>('Rs.2,500');

  void updateStudentInfo(StudentInfo info) {
    studentInfo.value = info;
  }

  void updateGuardianInfo(GuardianInfo info) {
    guardianInfo.value = info;
  }

  void completeRide() {
    totalRides.value++;
    safeRides.value++;
    // Potentially update onTimeRate or trigger a notification
  }
}
