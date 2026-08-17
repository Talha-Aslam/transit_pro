import 'dart:io';

import 'package:transit_core/transit_core.dart';

/// One child on a parent's account, as typed into a form.
class ChildDraft {
  final String name;
  final String grade;
  final String school;

  const ChildDraft({this.name = '', this.grade = '', this.school = ''});

  bool get isBlank =>
      name.trim().isEmpty && grade.trim().isEmpty && school.trim().isEmpty;
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
