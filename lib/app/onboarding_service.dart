import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import '../services/cloudinary_service.dart';
import 'profile_draft.dart';
import 'session_service.dart';

class OnboardingException implements Exception {
  final String message;
  const OnboardingException(this.message);

  @override
  String toString() => message;
}

/// Turns a filled-in [ProfileDraft] into the full set of Firestore documents a
/// role needs.
///
/// **This is the only place a profile is written.** Both the email/password
/// signup screen and the Google profile-completion screen call [provision], so
/// the two routes cannot produce different-quality accounts. Before this
/// existed, `AuthService.signUp()` persisted name/email/phone/role and threw
/// away the children, vehicle and pickup coordinates the form had just
/// collected.
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  /// Creates every document [draft] implies, then marks the profile complete.
  ///
  /// Order matters: file uploads run first, because a failed upload must leave
  /// nothing behind. Once uploads succeed, the Firestore writes go out in a
  /// single batch so a half-provisioned account is not possible.
  Future<AppUser> provision({
    required String uid,
    required ProfileDraft draft,
  }) async {
    final gaps = ProfileRequirements.missing(draft);
    if (gaps.isNotEmpty) {
      throw OnboardingException('Incomplete profile: ${gaps.join(', ')}');
    }

    // ── 1. Uploads, before anything is written ──────────────────────────────
    String? licenseUrl, licensePublicId;
    String? idCardUrl, idCardPublicId;

    if (draft.role == UserRole.driver) {
      final license = await _upload(draft.licensePhoto, uid, 'drivingLicense');
      licenseUrl = license?.secureUrl;
      licensePublicId = license?.publicId;

      final idCard = await _upload(draft.idCardPhoto, uid, 'idCard');
      idCardUrl = idCard?.secureUrl;
      idCardPublicId = idCard?.publicId;
    }

    // ── 2. One batch ────────────────────────────────────────────────────────
    final batch = Db.fs.batch();

    final profile = AppUser(
      uid: uid,
      role: draft.role,
      name: draft.name.trim(),
      email: draft.email.trim(),
      phone: draft.phone.trim(),
      photoUrl: draft.photoUrl,
      profileComplete: true,
    );
    batch.set(Db.users.doc(uid), profile, SetOptions(merge: true));

    switch (draft.role) {
      case UserRole.parent:
        for (final child in draft.realChildren) {
          final ref = Db.students.doc();
          batch.set(
            ref,
            Student(
              id: ref.id,
              name: child.name.trim(),
              parentId: uid,
              grade: child.grade.trim(),
              school: child.school.trim(),
              instituteType: child.grade.trim(),
              studentIdNumber: child.studentIdNumber.trim(),
              // Derived from the document id, so it inherits that id's
              // uniqueness rather than needing a collision check — which a
              // batched write could not perform anyway. This is what lets a
              // driver tell two children with the same name apart.
              publicCode: Student.publicCodeFor(ref.id),
              pickupLocation: child.pickupLocation,
            ),
          );
        }

      case UserRole.student:
        // Document id is the uid. `ownsStudent()` in firestore.rules already
        // accepts `studentId == uid()`, so this needs no rule change.
        batch.set(
          Db.students.doc(uid),
          Student(
            id: uid,
            name: draft.name.trim(),
            // A self-registering student has no parent account linked yet; an
            // admin or an invite flow fills this in later.
            parentId: '',
            grade: draft.instituteType.trim(),
            school: draft.school.trim(),
            instituteType: draft.instituteType.trim(),
            studentIdNumber: draft.studentIdNumber.trim(),
            publicCode: Student.publicCodeFor(uid),
            photoUrl: draft.photoUrl,
            pickupLocation: draft.pickupLocation,
            dropoffLocation: draft.dropoffLocation,
          ),
          SetOptions(merge: true),
        );

      case UserRole.driver:
        final busRef = Db.buses.doc();
        batch.set(
          busRef,
          Bus(
            id: busRef.id,
            busNumber: draft.vehicleNumber.trim(),
            plateNumber: draft.vehicleNumber.trim(),
            capacity: draft.seatCapacity,
            vehicleType: draft.vehicleType.trim(),
            driverId: uid,
          ),
        );

        batch.set(
          Db.drivers.doc(uid),
          Driver(
            id: uid,
            name: draft.name.trim(),
            phone: draft.phone.trim(),
            email: draft.email.trim(),
            licenseNumber: draft.licenseNumber.trim(),
            experienceYears: draft.experienceYears,
            photoUrl: draft.photoUrl,
            busId: busRef.id,
            // Self-signup never grants driving privileges. An admin flips this
            // in transit_admin after checking the licence and ID.
            status: DriverStatus.pendingVerification,
            serviceAreas: draft.serviceAreas,
            serviceRadiusKm: draft.serviceRadiusKm,
            baseLocation: draft.baseLocation,
            // Written with whatever `bookedSeats` the draft carries, which for a
            // new driver is zero on every round. `Driver.toMap()` also emits the
            // derived `serviceSchools` mirror, which is what parent-side search
            // actually queries.
            schedules: draft.schedules,
          ),
          SetOptions(merge: true),
        );

        if (licenseUrl != null) {
          final ref = Db.documents.doc();
          batch.set(
            ref,
            DriverDocument(
              id: ref.id,
              driverId: uid,
              type: DocumentType.drivingLicense,
              status: DocumentStatus.pending,
              fileUrl: licenseUrl,
              publicId: licensePublicId,
              uploadedAt: DateTime.now(),
            ),
          );
        }
        if (idCardUrl != null) {
          final ref = Db.documents.doc();
          batch.set(
            ref,
            DriverDocument(
              id: ref.id,
              driverId: uid,
              // No CNIC case in DocumentType; vehicleRegistration is the
              // closest existing slot and the admin app renders the file
              // regardless of which one it lands in.
              type: DocumentType.vehicleRegistration,
              status: DocumentStatus.pending,
              fileUrl: idCardUrl,
              publicId: idCardPublicId,
              uploadedAt: DateTime.now(),
            ),
          );
        }

      case UserRole.admin:
        throw const OnboardingException(
          'Admin accounts are created in the admin app, not here.',
        );
    }

    await batch.commit();

    // Timestamps are a separate write: FieldValue.serverTimestamp() cannot go
    // through withConverter, which serialises a typed model.
    await UserRepository.instance.touchCreated(uid, draft.role);

    await SessionService.instance.refresh();
    return profile;
  }

  Future<UploadResult?> _upload(File? file, String uid, String docType) async {
    if (file == null) return null;
    if (!CloudinaryService.instance.isConfigured) {
      throw const OnboardingException(
        'File upload is not configured, so documents cannot be saved. '
        'Contact support.',
      );
    }
    try {
      return await CloudinaryService.instance.uploadDriverDocument(
        file,
        uid,
        docType,
      );
    } on UploadException catch (e) {
      throw OnboardingException(e.message);
    } catch (e) {
      debugPrint('Onboarding upload failed: $e');
      throw const OnboardingException(
        'Could not upload your documents. Check your connection and try again.',
      );
    }
  }
}
