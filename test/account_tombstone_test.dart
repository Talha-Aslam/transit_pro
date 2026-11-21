import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pro/app/auth_service.dart';

String read(String path) => File(path).readAsStringSync();

/// The body of the method that starts with [signature], up to the next
/// method at the same indentation.
String method(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'missing: $signature');
  final next = source.indexOf(
    RegExp(r'\n  (Future|static|bool|String|void|AppUser)'),
    start + 1,
  );
  return source.substring(start, next < 0 ? source.length : next);
}

void main() {
  group('tombstoned profiles at sign-in', () {
    test('only the user\'s own uid in deletedBy is a self-delete', () {
      expect(
        AuthService.isSelfDeletedTombstone('u1', {
          'isDeleted': true,
          'deletedBy': 'u1',
        }),
        isTrue,
      );
      // The old admin "Delete" wrote no deletedBy.
      expect(
        AuthService.isSelfDeletedTombstone('u1', {'isDeleted': true}),
        isFalse,
      );
      // A permanent admin delete writes 'admin' (and has no login left).
      expect(
        AuthService.isSelfDeletedTombstone('u1', {'deletedBy': 'admin'}),
        isFalse,
      );
      expect(AuthService.isSelfDeletedTombstone('u1', null), isFalse);
    });

    test('an admin archive reads as deactivated, not deleted', () {
      expect(
        AuthService.adminDeactivatedMessage,
        'This account has been deactivated by the administrator. Please '
        'contact support.',
      );
      expect(AuthService.selfDeletedMessage, 'This account has been deleted.');
    });

    final source = read('lib/app/auth_service.dart');

    test('email and Google sign-in both refuse a tombstone the same way', () {
      expect(
        method(source, 'Future<AppUser> signIn('),
        contains('if (profile.isDeleted) await _refuseTombstone(user);'),
      );
      expect(
        method(source, 'Future<GoogleOutcome> signInWithGoogle('),
        contains('if (profile.isDeleted) await _refuseTombstone(user);'),
      );
      // No path still calls every tombstone "deleted".
      expect(
        source,
        isNot(
          contains(
            "throw const AuthException('This account has been deleted.')",
          ),
        ),
      );
      final refuse = method(source, 'Future<Never> _refuseTombstone(');
      expect(refuse, contains('selfDeletedMessage'));
      expect(refuse, contains('adminDeactivatedMessage'));
    });

    test('sign-up never resumes into a tombstone', () {
      final resume = method(
        source,
        'Future<UserCredential?> _resumeUnfinishedSignUp(',
      );
      // Resumes only when there is no profile at all…
      expect(resume, contains('if (raw == null) return cred;'));
      // …replaces a self-deleted leftover login with a new one…
      expect(resume, contains('isSelfDeletedTombstone(user.uid, raw)'));
      expect(resume, contains('createUserWithEmailAndPassword'));
      // …and refuses an admin-archived one.
      expect(
        resume,
        contains('throw const AuthException(adminDeactivatedMessage)'),
      );
    });
  });

  test('nothing looks accounts up by email, so a re-used email gets a fresh '
      'account after a permanent delete', () {
    for (final path in [
      'lib/app/auth_service.dart',
      'lib/app/onboarding_service.dart',
      'lib/data/user_repository.dart',
    ]) {
      final src = read(path);
      expect(src, isNot(contains("where('email'")), reason: path);
      expect(src, isNot(contains('fetchSignInMethodsForEmail(')), reason: path);
    }
  });

  group('firestore rules', () {
    final rules = read('firestore.rules');

    test('a user cannot clear their own tombstone or the admin flags', () {
      final users = rules.substring(
        rules.indexOf('match /users/{userId} {'),
        rules.indexOf('match /users/{userId}/accessLog'),
      );
      expect(
        users,
        contains("request.resource.data.get('isDeleted', false) == true"),
      );
      expect(users, contains("'authDeleted'"));
      expect(users, contains("'deactivatedBy'"));
    });
  });
}
