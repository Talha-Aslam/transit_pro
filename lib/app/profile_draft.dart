import 'dart:io';

import 'package:transit_core/transit_core.dart';

/// One child on a parent's account, as typed into a form.
class ChildDraft {
  final String name;
  final String grade;
  final String school;

  /// The school's own roll number, if the family has one. Optional — a parent
  /// registering a five-year-old usually does not, and demanding it would block
  /// them. Uniqueness never depends on it: see [Student.publicCode].
  final String studentIdNumber;

  /// Where the child is collected from. Optional at sign-up, but without it
  /// driver matchmaking can only rank by name, not proximity.
  final GeoCoord? pickupLocation;

  const ChildDraft({
    this.name = '',
    this.grade = '',
    this.school = '',
    this.studentIdNumber = '',
    this.pickupLocation,
  });

  bool get isBlank =>
      name.trim().isEmpty && grade.trim().isEmpty && school.trim().isEmpty;

  /// Name reduced for duplicate detection — case and inner spacing folded, so
  /// `"Jack  Jones"` and `"jack jones"` are recognised as the same child.
  String get comparableName =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  ChildDraft copyWith({
    String? name,
    String? grade,
    String? school,
    String? studentIdNumber,
    GeoCoord? pickupLocation,
  }) =>
      ChildDraft(
        name: name ?? this.name,
        grade: grade ?? this.grade,
        school: school ?? this.school,
        studentIdNumber: studentIdNumber ?? this.studentIdNumber,
        pickupLocation: pickupLocation ?? this.pickupLocation,
      );
}

/// Everything a sign-up form can collect, for any role.
///
/// Both the email/password signup screen and the Google profile-completion
/// screen build one of these and hand it to `OnboardingService.provision()`.
/// Having a single payload type is what stops the two flows from drifting —
/// previously signup collected children, a vehicle and pickup coordinates and
/// then silently dropped all of them on the way to Firestore.
class ProfileDraft {
  final UserRole role;

  // Shared
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;

  // Parent
  final List<ChildDraft> children;

  // Student
  final String studentIdNumber;
  final String instituteType;
  final String school;
  final GeoCoord? pickupLocation;
  final GeoCoord? dropoffLocation;

  // Driver
  final String licenseNumber;
  final int experienceYears;
  final String vehicleNumber;
  final String vehicleType;
  final int seatCapacity;

  /// The institutions this driver runs to. Without at least one, no parent can
  /// ever find them — which is why it is a required field rather than something
  /// to fill in later from the profile screen.
  final List<ServiceArea> serviceAreas;

  /// How far the driver will travel to collect a student, from [baseLocation].
  final double serviceRadiusKm;
  final GeoCoord? baseLocation;

  /// The bookable rounds. Reuses the domain type rather than a parallel draft
  /// class: a brand-new driver's rounds have `bookedSeats: 0`, which is exactly
  /// what [DriverSchedule] already represents, and a second near-identical type
  /// would just be somewhere for the two to drift apart.
  final List<DriverSchedule> schedules;

  /// Local files, uploaded to Cloudinary during provisioning. Null when the
  /// driver has already uploaded that document.
  final File? licensePhoto;
  final File? idCardPhoto;

  const ProfileDraft({
    required this.role,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.photoUrl,
    this.children = const [],
    this.studentIdNumber = '',
    this.instituteType = '',
    this.school = '',
    this.pickupLocation,
    this.dropoffLocation,
    this.licenseNumber = '',
    this.experienceYears = 0,
    this.vehicleNumber = '',
    this.vehicleType = '',
    this.seatCapacity = 0,
    this.serviceAreas = const [],
    this.serviceRadiusKm = 0,
    this.baseLocation,
    this.schedules = const [],
    this.licensePhoto,
    this.idCardPhoto,
  });

  /// Children with something actually typed into them. A parent adding a second
  /// child card and leaving it empty should not create a blank student record.
  List<ChildDraft> get realChildren =>
      children.where((c) => !c.isBlank).toList();

  ProfileDraft copyWith({
    UserRole? role,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    List<ChildDraft>? children,
    String? studentIdNumber,
    String? instituteType,
    String? school,
    GeoCoord? pickupLocation,
    GeoCoord? dropoffLocation,
    String? licenseNumber,
    int? experienceYears,
    String? vehicleNumber,
    String? vehicleType,
    int? seatCapacity,
    List<ServiceArea>? serviceAreas,
    double? serviceRadiusKm,
    GeoCoord? baseLocation,
    List<DriverSchedule>? schedules,
    File? licensePhoto,
    File? idCardPhoto,
  }) =>
      ProfileDraft(
        role: role ?? this.role,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        children: children ?? this.children,
        studentIdNumber: studentIdNumber ?? this.studentIdNumber,
        instituteType: instituteType ?? this.instituteType,
        school: school ?? this.school,
        pickupLocation: pickupLocation ?? this.pickupLocation,
        dropoffLocation: dropoffLocation ?? this.dropoffLocation,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        experienceYears: experienceYears ?? this.experienceYears,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        vehicleType: vehicleType ?? this.vehicleType,
        seatCapacity: seatCapacity ?? this.seatCapacity,
        serviceAreas: serviceAreas ?? this.serviceAreas,
        serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
        baseLocation: baseLocation ?? this.baseLocation,
        schedules: schedules ?? this.schedules,
        licensePhoto: licensePhoto ?? this.licensePhoto,
        idCardPhoto: idCardPhoto ?? this.idCardPhoto,
      );
}

/// The single definition of "what does this role still owe us?".
///
/// The completion form renders exactly the fields this reports missing, and the
/// submit button validates against the same call — so the asterisks on screen
/// and the rules being enforced can never disagree. The old signup screen had
/// precisely that bug: pickup and dropoff were marked required with a red
/// asterisk, but `_missingStudentField()` only ever checked name and school.
class ProfileRequirements {
  ProfileRequirements._();

  /// Human-readable labels for everything still missing. Empty means complete.
  static List<String> missing(ProfileDraft d) {
    final gaps = <String>[];

    if (d.name.trim().isEmpty) gaps.add('Full name');
    if (d.phone.trim().isEmpty) gaps.add('Phone number');

    switch (d.role) {
      case UserRole.parent:
        final kids = d.realChildren;
        if (kids.isEmpty) {
          gaps.add('At least one child');
        } else {
          for (var i = 0; i < kids.length; i++) {
            final label = 'Child ${i + 1}';
            if (kids[i].name.trim().isEmpty) gaps.add('$label — name');
            if (kids[i].grade.trim().isEmpty) gaps.add('$label — grade');
            if (kids[i].school.trim().isEmpty) gaps.add('$label — school');
          }

          // Two children on the same account with the same name is almost always
          // a double-tap on "Add child", not twins. Catching it here matters
          // because the two records are then indistinguishable on a driver's
          // roster, and the parent has no way to tell which one they attached to
          // a driver. Twins with genuinely identical names are the rare case, and
          // the fix — a middle name or an initial — is one the parent can apply
          // themselves.
          final seen = <String>{};
          for (final kid in kids) {
            final key = kid.comparableName;
            if (key.isEmpty) continue;
            if (!seen.add(key)) {
              gaps.add(
                'Two children named "${kid.name.trim()}" — give them '
                'distinguishable names',
              );
            }
          }
        }

      case UserRole.student:
        if (d.studentIdNumber.trim().isEmpty) gaps.add('Student ID');
        if (d.instituteType.trim().isEmpty) gaps.add('Grade level');
        if (d.school.trim().isEmpty) gaps.add('School / institution');
        if (d.pickupLocation == null) gaps.add('Pickup location');
        if (d.dropoffLocation == null) gaps.add('Dropoff location');

      case UserRole.driver:
        if (d.licenseNumber.trim().isEmpty) gaps.add('Licence number');
        if (d.vehicleNumber.trim().isEmpty) gaps.add('Vehicle number');
        if (d.vehicleType.trim().isEmpty) gaps.add('Vehicle type');
        if (d.seatCapacity <= 0) gaps.add('Seat capacity');
        if (d.experienceYears <= 0) gaps.add('Years of experience');
        if (d.licensePhoto == null) gaps.add('Licence photo');
        if (d.idCardPhoto == null) gaps.add('ID card photo');

        // Both of these are required rather than optional-with-a-nudge-later,
        // because a driver missing either is invisible to every parent in the
        // city while their own profile looks finished. Silent invisibility is
        // the worst failure mode this flow has: the driver waits for requests
        // that can never arrive and has nothing on screen telling them why.
        if (d.serviceAreas.isEmpty) {
          gaps.add('At least one school, college or university you serve');
        }

        final rounds = d.schedules;
        if (rounds.isEmpty) {
          gaps.add('At least one pickup or drop-off round');
        } else {
          for (var i = 0; i < rounds.length; i++) {
            final label = rounds[i].label.trim().isEmpty
                ? 'Round ${i + 1}'
                : rounds[i].label.trim();
            if (rounds[i].startTime.trim().isEmpty) {
              gaps.add('$label — start time');
            }
            if (rounds[i].totalSeats <= 0) gaps.add('$label — seats');
          }

          if (rounds.every((r) => r.totalSeats <= 0)) {
            gaps.add('Seats on at least one round');
          }
        }

      case UserRole.admin:
        break;
    }

    return gaps;
  }

  static bool isComplete(ProfileDraft d) => missing(d).isEmpty;

  /// The first gap, phrased as a sentence for a snackbar.
  static String? firstGapMessage(ProfileDraft d) {
    final gaps = missing(d);
    if (gaps.isEmpty) return null;
    if (gaps.length == 1) return 'Please provide: ${gaps.first}';
    return 'Please provide: ${gaps.first} (and ${gaps.length - 1} more)';
  }
}
