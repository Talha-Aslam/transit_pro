import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import 'auth_service.dart';

/// Thrown for every account-management failure with a message safe to show a
/// user.
class AccountException implements Exception {
  final String message;
  const AccountException(this.message);

  @override
  String toString() => message;
}

/// Deactivating (soft delete) and deleting (hard delete) one's own account.
///
/// Both actions sign the user out on success — the caller navigates away the
/// same way [confirmAndSignOut] does, before awaiting the teardown, so the
/// screen underneath doesn't have to survive being disposed mid-request.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  // ── Deactivate (soft delete) ────────────────────────────────────────────

  /// Pauses the account: `users/{uid}.isActive` becomes `false`, then signs
  /// out. Every piece of the account's data is untouched — an admin (or a
  /// future "reactivate" flow) can flip it back.
  ///
  /// `isActive` is deliberately **not** writable by the client in general
  /// (see [AppUser]'s class doc and the `users` update rule) — an account
  /// could otherwise silently un-suspend itself. The rule only permits this
  /// one direction, true → false, from the owning user; only an admin can
  /// flip it back. [AuthService.signIn] already refuses sign-in for
  /// `isActive == false` accounts, so this alone is a real, working pause —
  /// nothing else needs to check this flag for deactivation to take effect.
  Future<void> deactivate() async {
    final uid = AuthService.instance.uid;
    if (uid == null) throw const AccountException('You are not signed in.');

    try {
      await Db.fs.collection('users').doc(uid).update({
        'isActive': false,
        'updatedAt': Db.now,
      });
    } on FirebaseException catch (e) {
      debugPrint('deactivate failed — Firebase ${e.code}: ${e.message}');
      throw const AccountException(
        'Could not deactivate your account. Please try again.',
      );
    }

    await AuthService.instance.signOut();
  }

  // ── Delete (hard delete) ────────────────────────────────────────────────

  /// Permanently deletes the account: this account's own Firestore
  /// documents, then the Firebase Auth account itself, then signs out
  /// (`user.delete()` already ends the session, but this also clears the
  /// cached role and Firestore listeners the same way every other sign-out
  /// does).
  ///
  /// ## What this does *not* delete
  ///
  /// Only documents this account owns outright: `users/{uid}`, and
  /// `drivers/{uid}` or `students/{uid}` for a driver or a self-registered
  /// student. It does **not** cascade into data that merely *references*
  /// this uid — a parent's children (a parent has no document of their own
  /// beyond `users/{uid}`; their children are real, independent student
  /// records that outlive the parent account on purpose, the same way a
  /// child isn't deleted when a family changes their contact email), past
  /// `ride_requests`, `ratings`, or trip history naming this driver/student.
  /// Firestore's security model has no notion of "delete everything that
  /// points at me" — that requires a trusted identity that can act across
  /// collections, which in practice means a Cloud Function running with the
  /// Admin SDK. This project has no server component yet (see
  /// `RideMatchService`'s class doc for the same constraint on
  /// notifications). TODO(backend): once that function exists, call it here
  /// instead of deleting documents directly from the client.
  ///
  /// ## Why Firestore is deleted before the Auth account, not after
  ///
  /// `user.delete()` ends the Firebase session immediately on success, and a
  /// Firestore write after that point runs unauthenticated and is denied by
  /// every rule in this file. Deleting Firestore data first, while the
  /// session is still live, is the only ordering where both steps can
  /// actually succeed.
  ///
  /// The unavoidable tradeoff: if `user.delete()` then fails with
  /// `requires-recent-login` (Firebase requires a *recent* sign-in for this
  /// specific operation, regardless of whether the Firestore writes above
  /// just succeeded with the same session), this account is left with no
  /// Firestore profile but a still-existing Auth account. That state is
  /// already a handled, understood one in this app: [AuthService.signIn]
  /// treats a missing profile as "contact your administrator" rather than
  /// silently onboarding them again. The caller should catch
  /// [AccountException] here and tell the user to sign in again and retry
  /// *before* that happens — re-running this method from a fresh session
  /// completes the deletion cleanly, since the Firestore documents are
  /// idempotently gone already.
  Future<void> delete({required UserRole role}) async {
    final user = AuthService.instance.firebaseUser;
    if (user == null) throw const AccountException('You are not signed in.');
    final uid = user.uid;

    try {
      switch (role) {
        case UserRole.driver:
          await Db.fs.collection('drivers').doc(uid).delete();
          break;
        case UserRole.student:
          await Db.fs.collection('students').doc(uid).delete();
          break;
        case UserRole.parent:
        case UserRole.admin:
          break;
      }
      await Db.fs.collection('users').doc(uid).delete();
    } on FirebaseException catch (e) {
      debugPrint('delete (Firestore step) failed — ${e.code}: ${e.message}');
      throw const AccountException(
        'Could not delete your account data. Please try again.',
      );
    }

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      debugPrint('delete (Auth step) failed — ${e.code}: ${e.message}');
      if (e.code == 'requires-recent-login') {
        throw const AccountException(
          'For your security, please sign out, sign in again, and retry '
          'deleting your account.',
        );
      }
      throw const AccountException(
        'Could not delete your account. Please try again.',
      );
    }

    await AuthService.instance.signOut();
  }
}
