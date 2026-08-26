import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import '../theme/theme_provider.dart';
import 'onboarding_service.dart';
import 'profile_draft.dart';
import 'session_service.dart';

/// Thrown for every auth failure with a message safe to show a user.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// The three ways a Google sign-in can end.
///
/// The previous signature returned `AppUser?` and overloaded `null` to mean
/// "the user cancelled", while a first-time account *threw*. That made the two
/// call sites do opposite things with the same outcome, and there was no way to
/// express "authenticated, but we still need a role from them" — which is
/// exactly the case the onboarding screen exists to handle.
sealed class GoogleOutcome {
  const GoogleOutcome();
}

/// The user dismissed the Google account sheet. Not an error.
class GoogleCancelled extends GoogleOutcome {
  const GoogleCancelled();
}

/// Authenticated with Google; a `users/{uid}` profile exists but
/// `profileComplete` is false.
///
/// [profile] is never a guess. Google is only ever offered from a
/// role-specific `/login/:role` screen, so the role is already known the
/// moment sign-in starts — [AuthService.signInWithGoogle] writes it to
/// Firestore immediately (first time) or reads it back (an account resuming
/// onboarding it abandoned last session). Either way there is a real document
/// behind this by the time the caller sees it, which is what makes an
/// abandoned onboarding attempt recoverable after the app is killed: the next
/// launch reads the same `profileComplete: false` record back out, role
/// included, instead of having to remember anything client-side.
class GoogleNeedsProfile extends GoogleOutcome {
  final AppUser profile;
  const GoogleNeedsProfile(this.profile);
}

/// Signed in against an existing, complete profile.
class GoogleSignedIn extends GoogleOutcome {
  final AppUser user;
  const GoogleSignedIn(this.user);
}

/// Real Firebase authentication with server-enforced roles.
///
/// ## What changed, and why it matters
///
/// The prototype's login was `Future.delayed(1500ms)` followed by
/// `saveRole(roleFromUrl)`. Any email and any password logged you in **as any
/// role you asked for**, and the role lived only in SharedPreferences on the
/// user's own device.
///
/// Now: Firebase verifies the password, and [AppUser.role] is read from
/// `users/{uid}` in Firestore — written once at sign-up and enforced by
/// security rules. The client cannot choose or change it. SharedPreferences
/// keeps a copy purely so the splash screen can route without waiting on the
/// network; it is never the authority.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _roleKey = 'logged_in_role';
  static const _themeKey = 'theme_is_dark';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppUser? _currentUser;

  /// The signed-in user's profile, or null when signed out.
  AppUser? get currentUser => _currentUser;

  User? get firebaseUser => _auth.currentUser;

  String? get uid => _auth.currentUser?.uid;

  bool get isSignedIn => _auth.currentUser != null;

  /// Cached role for fast startup routing only. [currentUser] is authoritative.
  String? _cachedRole;
  String? get cachedRole => _cachedRole;

  /// Fires on sign-in and sign-out. `go_router` should redirect off this.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Startup ───────────────────────────────────────────────────────────────

  /// Called from `main()` before `runApp`. Restores the theme and, if a session
  /// is still valid, the user's profile.
  Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedRole = prefs.getString(_roleKey);

    final isDark = prefs.getBool(_themeKey);
    if (isDark != null) {
      ThemeProvider.instance.setMode(isDark ? ThemeMode.dark : ThemeMode.light);
    }

    final user = _auth.currentUser;
    if (user != null) {
      // Start the live session immediately so the router has real state to
      // guard on rather than a SharedPreferences guess.
      await SessionService.instance.start(user.uid);

      // Best-effort: offline start should not block the splash screen.
      try {
        _currentUser = await UserRepository.instance.fetchUser(user.uid);
        if (_currentUser != null) await _cacheRole(_currentUser!.role);
      } catch (_) {
        // Keep the cached role and carry on.
      }
    }
  }

  /// Re-reads the profile from Firestore. Call after a role or name change.
  Future<AppUser?> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    _currentUser = await UserRepository.instance.fetchUser(user.uid);
    if (_currentUser != null) await _cacheRole(_currentUser!.role);
    return _currentUser;
  }

  // ── Email + password ──────────────────────────────────────────────────────

  /// Creates an account and every document [draft] implies.
  ///
  /// The role in [draft] is honoured here — at sign-up — and never again from
  /// the client. Provisioning is delegated to [OnboardingService] so this path
  /// and the Google onboarding path write identical documents; the previous
  /// version wrote only name/email/phone/role and discarded the children,
  /// vehicle and pickup coordinates the form had collected.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required ProfileDraft draft,
  }) async {
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }

    final user = cred.user;
    if (user == null) throw const AuthException('Account creation failed.');

    // Held for the whole write. Without this, `SessionService.start` below
    // opens a listener on a document that does not exist yet, its first
    // snapshot reports `needsProfile`, and the router's guard reacts to that
    // by yanking this still-in-flight signup over to `/complete-profile`
    // before `provision()` below ever gets to write the real document —
    // exactly the protection `ProfileCompletionScreen` already gives its own
    // writes (see its `provisioning = true` before committing).
    SessionService.instance.provisioning = true;
    try {
      await user.updateDisplayName(draft.name.trim());
      await SessionService.instance.start(user.uid);

      final profile = await OnboardingService.instance.provision(
        uid: user.uid,
        draft: draft.copyWith(email: email.trim()),
      );

      _currentUser = profile;
      await _cacheRole(profile.role);
      return profile;
    } on OnboardingException catch (e) {
      // The auth account exists but has no usable profile. Signing out leaves
      // the user able to retry cleanly instead of being stranded in a session
      // with no documents behind it.
      await signOut();
      throw AuthException(e.message);
    } on FirebaseException catch (e) {
      await signOut();
      throw AuthException(_messageForFirestore(e));
    } catch (e) {
      await signOut();
      throw AuthException('Could not finish creating your account. Please try again.');
    } finally {
      SessionService.instance.provisioning = false;
    }
  }

  /// How long a single network round trip inside sign-in gets before this
  /// gives up and says so, rather than leaving the caller's loading spinner
  /// running against a Firestore retry cycle that may never surface an error.
  static const _authTimeout = Duration(seconds: 20);

  /// Signs in and returns the profile. The caller must route by
  /// [AppUser.role] — **not** by whichever role the login URL named.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(_authTimeout);

      final user = cred.user;
      if (user == null) throw const AuthException('Sign-in failed.');

      final profile = await UserRepository.instance
          .fetchUser(user.uid)
          .timeout(_authTimeout);
      if (profile == null) {
        // Full signOut(), not the raw `_auth.signOut()` this used to call —
        // that left `cachedRole` on disk untouched, so a stale role from an
        // earlier account on this device could still be read back by the
        // router's `auth.cachedRole ?? 'parent'` fallback on a later sign-in.
        await signOut();
        throw const AuthException(
          'This account has no profile. Please contact your administrator.',
        );
      }

      if (!profile.isActive) {
        await signOut();
        throw const AuthException(
          'This account has been deactivated. Please contact your administrator.',
        );
      }

      _currentUser = profile;
      await _cacheRole(profile.role);
      await SessionService.instance.start(user.uid);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    } on FirebaseException catch (e) {
      // The password was correct — Firebase Auth already succeeded — but
      // Firestore rejected the profile read that comes right after. Without
      // this clause the raw exception would propagate straight out of this
      // method uncaught, since only FirebaseAuthException is handled above,
      // and login_screen only knows how to catch AuthException.
      await signOut();
      throw AuthException(_messageForFirestore(e));
    } on TimeoutException {
      await signOut();
      throw const AuthException(
        'Taking too long to sign in — check your connection and try again.',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      // Anything else — a parsing error, a plugin exception out of
      // `SessionService.start`, anything not covered above — used to escape
      // this method uncaught. `login_screen._login()` only catches
      // `AuthException`, and nothing awaits its fire-and-forget call from the
      // button, so an uncaught throw here left `_loading` stuck `true`
      // forever: the button silently swaps its label for a spinner and never
      // swaps back, which reads as "the button disappeared".
      debugPrint('Sign-in failed: $e');
      await signOut();
      throw const AuthException('Sign-in failed. Please try again.');
    }
  }

  // ── Google ────────────────────────────────────────────────────────────────

  /// Signs in with Google and reports which of three situations resulted.
  ///
  /// [role] is the one the user is signing in as — Google is only ever offered
  /// from a specific `/login/:role` screen, so this is never a guess. On a
  /// brand-new account it is written to `users/{uid}` immediately, alongside
  /// `profileComplete: false`, before this method returns.
  ///
  /// That immediate write is the fix for the "lost track of your role" failure:
  /// the previous version deferred creating any document until the onboarding
  /// screen finished, and held the role only in memory (and briefly in
  /// SharedPreferences) in between. If that in-between state was ever cleared —
  /// an app kill hitting an unlucky moment, a second sign-in attempt, a bug in
  /// the recovery path — there was nowhere left to read the role back from. Now
  /// there always is: it lives in the one place that was already the source of
  /// truth for every other field, and reading it back is just the same
  /// `fetchUser` call every other flow already makes.
  Future<GoogleOutcome> signInWithGoogle({required UserRole role}) async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return const GoogleCancelled();

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred =
          await _auth.signInWithCredential(credential).timeout(_authTimeout);
      final user = cred.user;
      if (user == null) throw const AuthException('Google sign-in failed.');

      await SessionService.instance.start(user.uid);

      var profile = await UserRepository.instance
          .fetchUser(user.uid)
          .timeout(_authTimeout);

      if (profile == null) {
        // First Google sign-in for this account. Persist the base record now
        // — see the method doc for why this, not memory, is what makes an
        // abandoned onboarding attempt recoverable.
        profile = AppUser(
          uid: user.uid,
          role: role,
          name: user.displayName ?? googleUser.displayName ?? '',
          email: user.email ?? googleUser.email,
          photoUrl: user.photoURL ?? googleUser.photoUrl,
        );
        await UserRepository.instance.createUser(profile).timeout(_authTimeout);
      }

      if (!profile.profileComplete) {
        // Either just created above, or a returning user who closed the app
        // before finishing onboarding last time. Both resume from the same
        // stored record — never recreated, never re-asked which role they are.
        _currentUser = profile;
        await _cacheRole(profile.role);
        return GoogleNeedsProfile(profile);
      }

      // This account already has a committed role, and it isn't the one this
      // login screen is for — e.g. signing in on `/login/driver` with a
      // Google account that finished onboarding as a Student. Landing them in
      // the Student app anyway is "correct" by the stored role, but silent:
      // from their side they picked Driver and ended up somewhere else with
      // no explanation. Refuse plainly instead.
      if (profile.role != role) {
        await signOut();
        throw AuthException(
          'This Google account is registered as a ${profile.role.name}. '
          'Please use the ${profile.role.name} login instead.',
        );
      }

      if (!profile.isActive) {
        await signOut();
        throw const AuthException(
          'This account has been deactivated. Please contact your administrator.',
        );
      }

      _currentUser = profile;
      await _cacheRole(profile.role);
      return GoogleSignedIn(profile);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    } on PlatformException catch (e) {
      // The Google plugin throws this, not FirebaseAuthException — which is why
      // an unconfigured SHA-1 previously surfaced as an unhandled exception
      // with the spinner stuck on.
      throw AuthException(_messageForPlatform(e));
    } on FirebaseException catch (e) {
      // The Google OAuth handshake succeeded — Firestore rejected the profile
      // read/write straight after. Signing out matters here specifically:
      // leaving the Firebase Auth session alive with a Firestore session that
      // can never succeed is exactly what previously surfaced as "we lost
      // track of your role" — the router saw a signed-in user it could not
      // read a profile for and, wrongly, treated that the same as "hasn't
      // finished onboarding yet". Retrying the same broken request always
      // fails the same way, so say so plainly instead of looping the user
      // through onboarding.
      await signOut();
      throw AuthException(_messageForFirestore(e));
    } on TimeoutException {
      await signOut();
      throw const AuthException(
        'Taking too long to sign in — check your connection and try again.',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      throw const AuthException(
        'Google sign-in failed. Please try again.',
      );
    }
  }

  // ── Password management ───────────────────────────────────────────────────

  /// Really sends a reset email. The prototype's version sent nothing.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Whether this account signs in with a password at all.
  ///
  /// A Google-only account has no password to change. Without this check the
  /// screen would run an `EmailAuthProvider` reauth that cannot succeed and
  /// report "Incorrect email or password" for a password that never existed.
  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  /// Changes the password, verifying the current one first.
  ///
  /// The prototype never checked the old password and never called Firebase —
  /// it showed "Password changed" after a 1-second delay.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('You are not signed in.');
    }

    if (!hasPasswordProvider) {
      throw const AuthException(
        'You sign in with Google, so there is no password to change. '
        'Manage your password in your Google account settings.',
      );
    }

    try {
      // Firebase requires a recent login before a password change.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  /// Ends the session for real.
  ///
  /// The UI used to call `clearRole()` instead, which only removed a
  /// SharedPreferences key — the Firebase session survived, `isSignedIn` stayed
  /// true, and the router guard bounced the user straight back in. Every step
  /// below matters: cancel the Firestore listeners, drop the Google grant, end
  /// the Firebase session, and only then clear the cached role.
  Future<void> signOut() async {
    final currentUid = uid;

    // Stop the streams first. Cancelling after signOut() races the security
    // rules and logs a burst of permission-denied errors as each listener
    // re-evaluates against a null auth context.
    await SessionService.instance.stop();

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Not signed in with Google — ignore.
    }

    await _auth.signOut();
    _currentUser = null;
    await clearRole();

    if (currentUid != null) {
      // FCM token cleanup is best-effort; a stale token simply stops resolving.
      debugPrint('Signed out $currentUid');
    }
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  Future<void> _cacheRole(UserRole role) async {
    _cachedRole = role.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
  }

  Future<void> clearRole() async {
    _cachedRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<void> saveTheme({required bool isDark}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey);
    if (isDark != null) {
      ThemeProvider.instance.setMode(isDark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  /// Kept only so existing screens keep compiling during the migration.
  ///
  /// It no longer decides anything: the role written here is overwritten by the
  /// value read from Firestore on the next sign-in or [refreshProfile].
  @Deprecated('Role now comes from Firestore. Remove calls as screens migrate.')
  Future<void> saveRole(String role) async {
    _cachedRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  // ── Routing ───────────────────────────────────────────────────────────────

  /// Admin is intentionally absent: it lives in the separate `transit_admin`
  /// app, which authenticates against the same Firebase project.
  static String routeForRole(String role) {
    switch (role) {
      case 'driver':
        return '/driver';
      case 'student':
        return '/student';
      default:
        return '/parent';
    }
  }

  static String routeForUserRole(UserRole role) => routeForRole(role.name);

  // ── Errors ────────────────────────────────────────────────────────────────

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // `firebase_auth` no longer exposes `fetchSignInMethodsForEmail`
        // (removed upstream for enumeration-protection reasons), so a
        // Google-only account failing here is indistinguishable at the SDK
        // level from a genuinely wrong password — both surface as
        // `invalid-credential`. The added hint costs nothing for a real typo
        // and answers the actual question for a Google-registered user.
        return 'Incorrect email or password. If you signed up with Google, '
            "use the 'Continue with Google' button below instead.";
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Choose a stronger password — at least 6 characters.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your password.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled for this project.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Messages for failures raised by the `google_sign_in` plugin.
  ///
  /// `sign_in_failed` carrying `ApiException: 10` is `DEVELOPER_ERROR`: Play
  /// Services could not match the APK's signing certificate to an OAuth client.
  /// In practice that always means this machine's SHA-1 is absent from
  /// `google-services.json`. It is a build-configuration fault, not something
  /// the user did, so say so plainly rather than blaming their credentials.
  String _messageForPlatform(PlatformException e) {
    final detail = '${e.code} ${e.message ?? ''}';

    if (detail.contains('10') && e.code == 'sign_in_failed') {
      return 'Google sign-in is not configured for this build. '
          "The app's signing certificate is not registered in Firebase.";
    }

    switch (e.code) {
      case 'network_error':
        return 'No internet connection. Please try again.';
      case 'sign_in_canceled':
      case 'sign_in_cancelled':
        return 'Sign-in was cancelled.';
      case 'sign_in_required':
        return 'Please choose a Google account to continue.';
      default:
        debugPrint('Google PlatformException: $detail');
        return 'Google sign-in failed. Please try again.';
    }
  }

  /// Messages for failures raised by `cloud_firestore` itself — distinct from
  /// [_messageFor], which only covers `firebase_auth`.
  ///
  /// `permission-denied` here means Firebase Auth already succeeded (the
  /// credential was accepted) and the *next* step, reading or writing the
  /// user's own profile, was rejected outright. In this project that has one
  /// realistic cause: the security rules in `firestore.rules` exist in the
  /// repo but have never been deployed to the live project (see
  /// IMPLEMENTATION.md's "Deploy the rules" item), so Firestore is still
  /// running on the deny-everything default a database gets when created in
  /// production mode. No amount of retrying, picking a different role, or
  /// filling in the onboarding form changes that — only deploying the rules
  /// does — so this message says as much rather than implying the user did
  /// something wrong.
  String _messageForFirestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return "Couldn't verify your account — the server rejected the "
            'request. This usually means the app is still being set up. '
            'Please try again shortly, or contact support if it continues.';
      case 'unavailable':
        return 'No connection to the server. Please check your internet and '
            'try again.';
      default:
        debugPrint('Firestore error during auth: ${e.code} ${e.message}');
        return 'Something went wrong talking to the server. Please try again.';
    }
  }
}
