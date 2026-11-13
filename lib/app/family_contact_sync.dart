import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import 'session_service.dart';

/// Keeps a family's emergency contacts, name and phone on each of their
/// children's student records.
///
/// They live on the family's own `users/{uid}`, which only that family can
/// read — so a driver opening a child's details had no way to reach anyone
/// when the child did not answer. A driver may read the student record, so
/// the same details are written there too, whenever they differ.
class FamilyContactSync {
  FamilyContactSync._();

  /// Brings every child record of the signed-in family up to date. Cheap to
  /// call often: a record that already matches is not written.
  static Future<void> push({List<EmergencyContact>? contacts}) async {
    final session = SessionService.instance;
    final user = session.user.value;
    if (user == null) return;
    final wanted = contacts ?? user.emergencyContacts;
    final students = switch (user.role) {
      UserRole.parent => session.children.value,
      UserRole.student => [?session.student.value],
      _ => const <Student>[],
    };
    for (final s in students) {
      if (_matches(s, wanted, user.name, user.phone)) continue;
      try {
        await UserRepository.instance.updateStudent(s.id, {
          'emergencyContacts': [for (final c in wanted) c.toMap()],
          'guardianName': user.name,
          'guardianPhone': user.phone,
        });
      } catch (e) {
        debugPrint('contact sync for ${s.id} failed: $e');
      }
    }
  }

  static bool _matches(
    Student s,
    List<EmergencyContact> contacts,
    String name,
    String phone,
  ) {
    if (s.guardianName != name || s.guardianPhone != phone) return false;
    if (s.emergencyContacts.length != contacts.length) return false;
    for (var i = 0; i < contacts.length; i++) {
      final a = s.emergencyContacts[i];
      final b = contacts[i];
      if (a.name != b.name || a.relation != b.relation || a.phone != b.phone) {
        return false;
      }
    }
    return true;
  }
}
