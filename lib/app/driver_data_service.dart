import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import 'session_service.dart';

/// The driver's profile as the UI wants it: flat, pre-formatted strings.
///
/// Every field is now derived from Firestore. The class used to ship literal
/// defaults — `'Ahmed Raza'`, `'Bus #42'`, `'28 Students'` — which appeared on
/// screen for every driver who ever signed in. Empty now means genuinely
/// unassigned, and the UI shows a fallback rather than someone else's name.
class DriverInfo {
  String name;
  String email;
  String phone;
  String license;
  String experience;
  String busNumber;
  String route;

  /// Real in-app roster count — students/parents actually registered to this
  /// driver (`SessionService.roster`/`.routeStudents`, merged and
  /// de-duplicated the same way `driver_booked_students_screen.dart` does).
  int autoStudentCount;

  /// Riders the driver added by hand for kids who aren't in the app — see
  /// `Driver.manualStudentCount`.
  int manualStudentCount;

  int get totalStudentCount => autoStudentCount + manualStudentCount;

  DriverInfo({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.license = '',
    this.experience = '',
    this.busNumber = '',
    this.route = '',
    this.autoStudentCount = 0,
    this.manualStudentCount = 0,
  });

  DriverInfo copyWith({
    String? name,
    String? email,
    String? phone,
    String? license,
    String? experience,
    String? busNumber,
    String? route,
    int? autoStudentCount,
    int? manualStudentCount,
  }) => DriverInfo(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    license: license ?? this.license,
    experience: experience ?? this.experience,
    busNumber: busNumber ?? this.busNumber,
    route: route ?? this.route,
    autoStudentCount: autoStudentCount ?? this.autoStudentCount,
    manualStudentCount: manualStudentCount ?? this.manualStudentCount,
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

  /// `HH:mm` map for `drivers/{uid}.timingSlots`.
  ///
  /// 24-hour, zero-padded — never the `7:15 AM` display form, which does not
  /// sort and does not parse back reliably.
  Map<String, String> toMap() => {
    'morningPickup': _hhmm(morningPickupFromHome),
    'morningDropoff': _hhmm(morningDropoffAtSchool),
    'afternoonPickup': _hhmm(afternoonPickupFromSchool),
    'afternoonDropoff': _hhmm(afternoonDropoffAtHome),
  };

  /// Reads the stored map, keeping the sensible defaults for anything absent —
  /// a driver who has never opened the schedule screen still gets a workable
  /// timetable rather than midnight.
  factory DriverTimingSlots.fromMap(Map<String, String> m) {
    const fallback = DriverTimingSlots();
    return DriverTimingSlots(
      morningPickupFromHome:
          _parse(m['morningPickup']) ?? fallback.morningPickupFromHome,
      morningDropoffAtSchool:
          _parse(m['morningDropoff']) ?? fallback.morningDropoffAtSchool,
      afternoonPickupFromSchool:
          _parse(m['afternoonPickup']) ?? fallback.afternoonPickupFromSchool,
      afternoonDropoffAtHome:
          _parse(m['afternoonDropoff']) ?? fallback.afternoonDropoffAtHome,
    );
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }
}

String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Driver-facing view of the live session.
///
/// Keeps the `ValueNotifier` surface the driver screens already bind to and
/// swaps the source underneath for Firestore, exactly as the migration plan in
/// the README describes. Screens did not need to change.
class DriverDataService {
  DriverDataService._() {
    // Registering here means the first screen to touch this singleton gets the
    // current session immediately — both callbacks fire on registration — so it
    // does not matter whether this is constructed before or after sign-in.
    SessionService.instance.onUser((_) => _rebuild());
    SessionService.instance.onRoleData(_rebuild);
  }
  static final DriverDataService instance = DriverDataService._();

  /// Notifier for the driver's own profile info.
  final driverInfo = ValueNotifier<DriverInfo>(DriverInfo());

  /// Shared toggle for driver location sharing.
  final locationSharing = ValueNotifier<bool>(true);

  /// Shared pickup and drop-off slot timings.
  final timingSlots = ValueNotifier<DriverTimingSlots>(
    const DriverTimingSlots(),
  );

  // ── Live rebuild ──────────────────────────────────────────────────────────

  void _rebuild() {
    final session = SessionService.instance;
    final user = session.user.value;
    final driver = session.driver.value;
    final bus = session.bus.value;
    final route = session.route.value;

    if (user == null) {
      driverInfo.value = DriverInfo();
      locationSharing.value = true;
      timingSlots.value = const DriverTimingSlots();
      return;
    }

    // Merges the driver's own accepted-seat-request roster with any
    // admin-assigned route roster, de-duplicated by id — same rule
    // `driver_booked_students_screen.dart`'s `_roster` getter uses. Using
    // `routeStudents` alone (the old behaviour) undercounts a self-signup
    // driver with no admin route to zero even when they have real bookings.
    final merged = <String, Student>{};
    for (final s in session.roster.value) {
      merged[s.id] = s;
    }
    for (final s in session.routeStudents.value) {
      merged.putIfAbsent(s.id, () => s);
    }

    driverInfo.value = DriverInfo(
      name: user.name,
      email: user.email,
      phone: user.phone.isNotEmpty ? user.phone : (driver?.phone ?? ''),
      license: driver?.licenseNumber ?? '',
      experience: (driver?.experienceYears ?? 0) > 0
          ? '${driver!.experienceYears} Years'
          : '',
      busNumber: bus?.busNumber ?? '',
      route: route?.name ?? '',
      autoStudentCount: merged.length,
      manualStudentCount: driver?.manualStudentCount ?? 0,
    );

    if (driver != null) {
      locationSharing.value = driver.locationSharing;
      timingSlots.value = DriverTimingSlots.fromMap(driver.timingSlots);
    }
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Saves editable profile fields. Name, phone and email live on the user
  /// document; the driver document mirrors them so the admin app and parent
  /// screens can read a driver without a second lookup.
  Future<void> updateDriverInfo(DriverInfo info) async {
    final uid = SessionService.instance.uid;
    if (uid == null) return;

    // Optimistic: the Firestore snapshot will confirm within a frame or two,
    // and the field the user just typed should not visibly revert first.
    driverInfo.value = info;

    await UserRepository.instance.updateUser(uid, {
      'name': info.name,
      'phone': info.phone,
    });

    await UserRepository.instance.updateDriver(uid, {
      'name': info.name,
      'phone': info.phone,
      'licenseNumber': info.license,
      'experienceYears': _yearsFrom(info.experience),
    });
  }

  // ── Attendance-aware roster (illustrative) ──────────────────────────────
  //
  // Mirrors the parent-side `AttendanceService` mock (`app/attendance_service
  // .dart`) so a driver starting their route can tell who to actually pick up
  // today. Not wired into a screen yet — the real roster feed (`SessionService
  // .roster`/`.routeStudents`, merged in `_rebuild` above) has no attendance
  // filter applied anywhere today; this shows the shape that filter should
  // take once `AttendanceService` is real.

  /// Filters [fullRoster] down to students marked "attending" for [date]
  /// (today, by default).
  ///
  /// **Only ever fetch one day's worth of attendance here — never the whole
  /// week.** `students/{id}/attendance/{dateKey}` is one small document per
  /// day; querying every roster student's *entire* week when the route only
  /// needs today's date multiplies reads by ~5-7x for data that's either
  /// already in the past (irrelevant once the bus has left) or not yet
  /// decided (a parent can still change their mind about Thursday on
  /// Monday). Always scope the query to a single `dateKey`.
  Future<List<Student>> rosterAttendingOn(
    List<Student> fullRoster, {
    DateTime? date,
  }) async {
    final dateKey = Trip.dateKeyFor(date ?? DateTime.now());

    // TODO(backend): real version reads exactly one doc per roster student,
    // for this one dateKey, e.g.:
    //   final snaps = await Future.wait(fullRoster.map((s) => Db.fs
    //       .collection('students').doc(s.id)
    //       .collection('attendance').doc(dateKey).get()));
    //   return [
    //     for (var i = 0; i < fullRoster.length; i++)
    //       if ((snaps[i].data()?['isAttending'] as bool?) ?? true) fullRoster[i],
    //   ];
    // No document for a student == no notice was sent == still attending,
    // matching `AttendanceService`/the parent-side day selector's default.
    debugPrint(
      'rosterAttendingOn (mock): would query dateKey=$dateKey only, '
      'not the whole week',
    );
    return fullRoster;
  }

  /// The +/- offline-student control on the driver profile. Never negative —
  /// a driver un-clicking below zero would otherwise silently subtract from
  /// the real, auto-counted roster instead of just zeroing out their own
  /// manual add-on.
  Future<void> setManualStudentCount(int value) async {
    final uid = SessionService.instance.uid;
    final clamped = value < 0 ? 0 : value;
    driverInfo.value = driverInfo.value.copyWith(manualStudentCount: clamped);
    if (uid == null) return;
    await UserRepository.instance.updateDriver(uid, {
      'manualStudentCount': clamped,
    });
  }

  Future<void> setLocationSharing(bool value) async {
    final uid = SessionService.instance.uid;
    locationSharing.value = value;
    if (uid == null) return;
    await UserRepository.instance.setLocationSharing(uid, value);
  }

  Future<void> setTimingSlots(DriverTimingSlots slots) async {
    final uid = SessionService.instance.uid;
    timingSlots.value = slots;
    if (uid == null) return;
    await UserRepository.instance.updateDriver(uid, {
      'timingSlots': slots.toMap(),
    });
  }

  /// Pulls the number back out of a display string like `'8 Years'`.
  static int _yearsFrom(String display) =>
      int.tryParse(RegExp(r'\d+').stringMatch(display) ?? '') ?? 0;
}
