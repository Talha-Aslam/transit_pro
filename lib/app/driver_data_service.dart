import 'package:flutter/foundation.dart';

/// Mutable model for the driver's profile information.
class DriverInfo {
  String name;
  String email;
  String phone;
  String license;
  String experience;
  String busNumber;
  String route;
  String totalStudents;

  DriverInfo({
    this.name = 'Ahmed Raza',
    this.email = 'ahmed.raza@transit.pk',
    this.phone = '+92 300 5554321',
    this.license = 'DL-2018-LHR-8821',
    this.experience = '8 Years',
    this.busNumber = 'Bus #42',
    this.route = 'Route A — Morning',
    this.totalStudents = '28 Students',
  });

  DriverInfo copyWith({
    String? name,
    String? email,
    String? phone,
    String? license,
    String? experience,
    String? busNumber,
    String? route,
    String? totalStudents,
  }) => DriverInfo(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    license: license ?? this.license,
    experience: experience ?? this.experience,
    busNumber: busNumber ?? this.busNumber,
    route: route ?? this.route,
    totalStudents: totalStudents ?? this.totalStudents,
  );
}

/// Singleton that holds the driver's profile data and notifies listeners
/// whenever the data changes.
class DriverDataService {
  DriverDataService._();
  static final DriverDataService instance = DriverDataService._();

  /// Notifier for the driver's own profile info.
  final driverInfo = ValueNotifier<DriverInfo>(DriverInfo());

  void updateDriverInfo(DriverInfo info) {
    driverInfo.value = info;
  }
}
