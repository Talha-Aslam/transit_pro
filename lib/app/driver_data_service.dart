import 'package:flutter/material.dart';

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

/// Shared pickup/drop-off timing slots used by driver and student screens.
class DriverTimingSlots {
  final TimeOfDay morningPickupFromHome;
  final TimeOfDay morningDropoffAtSchool;
  final TimeOfDay afternoonPickupFromSchool;
  final TimeOfDay afternoonDropoffAtHome;

  const DriverTimingSlots({
    this.morningPickupFromHome = const TimeOfDay(hour: 7, minute: 15),
    this.morningDropoffAtSchool = const TimeOfDay(hour: 8, minute: 0),
    this.afternoonPickupFromSchool = const TimeOfDay(hour: 14, minute: 30),
    this.afternoonDropoffAtHome = const TimeOfDay(hour: 15, minute: 15),
  });

  DriverTimingSlots copyWith({
    TimeOfDay? morningPickupFromHome,
    TimeOfDay? morningDropoffAtSchool,
    TimeOfDay? afternoonPickupFromSchool,
    TimeOfDay? afternoonDropoffAtHome,
  }) => DriverTimingSlots(
    morningPickupFromHome: morningPickupFromHome ?? this.morningPickupFromHome,
    morningDropoffAtSchool:
        morningDropoffAtSchool ?? this.morningDropoffAtSchool,
    afternoonPickupFromSchool:
        afternoonPickupFromSchool ?? this.afternoonPickupFromSchool,
    afternoonDropoffAtHome:
        afternoonDropoffAtHome ?? this.afternoonDropoffAtHome,
  );
}

String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Singleton that holds the driver's profile data and notifies listeners
/// whenever the data changes.
class DriverDataService {
  DriverDataService._();
  static final DriverDataService instance = DriverDataService._();

  /// Notifier for the driver's own profile info.
  final driverInfo = ValueNotifier<DriverInfo>(DriverInfo());

  /// Shared toggle for driver location sharing.
  final locationSharing = ValueNotifier<bool>(true);

  /// Shared pickup and drop-off slot timings.
  final timingSlots = ValueNotifier<DriverTimingSlots>(
    const DriverTimingSlots(),
  );

  void updateDriverInfo(DriverInfo info) {
    driverInfo.value = info;
  }

  void setLocationSharing(bool value) {
    locationSharing.value = value;
  }

  void setTimingSlots(DriverTimingSlots slots) {
    timingSlots.value = slots;
  }
}
