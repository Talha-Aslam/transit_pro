import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';
import 'session_service.dart';
import '../screens/welcome_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/profile_completion_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/parent/parent_layout.dart';
import '../screens/parent/language_screen.dart';
import '../screens/parent/help_support_screen.dart';
import '../screens/parent/live_chat_screen.dart';
import '../screens/parent/driver_details_screen.dart';
import '../screens/parent/driver_chat_screen.dart';
import '../screens/parent/trip_history_screen.dart';
import '../screens/parent/subscription_screen.dart';
import '../screens/parent/emergency_contacts_screen.dart';
import '../screens/parent/change_password_screen.dart';
import '../screens/parent/rate_app_screen.dart';
import '../screens/driver/driver_layout.dart';
import '../screens/driver/driver_trip_history_screen.dart';
import '../screens/driver/driver_performance_screen.dart';
import '../screens/driver/driver_documents_screen.dart';
import '../screens/driver/driver_payment_history_screen.dart';
import '../screens/student/student_layout.dart';
import '../screens/student/missed_bus_screen.dart';
import '../screens/student/student_trip_history_screen.dart';
import '../screens/student/terms_screen.dart';
import '../screens/student/student_notifications.dart';
import '../screens/driver/driver_pickup_requests_screen.dart';
import '../screens/driver/driver_ride_requests_screen.dart';
import '../screens/driver/driver_service_screen.dart';
import '../screens/parent/find_drivers_screen.dart';
import '../screens/live_map_screen.dart';
import '../screens/driver/subscription.dart';
import '../screens/parent/parent_missed_bus_screen.dart';
import '../screens/parent/payment_screens.dart';
import '../theme/app_theme.dart';

/// Routes reachable while signed out.
///
/// Everything else — `/parent`, `/driver`, `/student` and their children —
/// requires a session. Without this, deep-linking `/parent` rendered the whole
/// shell with empty data instead of sending the user to sign in.
const _publicRoutes = <String>{
  '/splash',
  '/',
  '/role-select',
  '/signup',
  '/forgot-password',
};

bool _isPublic(String location) {
  if (_publicRoutes.contains(location)) return true;
  // '/login/:role' — any role segment.
  return location.startsWith('/login/');
}

/// Bridges `authStateChanges` to a [Listenable] so `go_router` re-evaluates
/// [_guard] the moment a user signs in or out, instead of only on navigation.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

const _onboardingRoute = '/complete-profile';

String? _guard(BuildContext context, GoRouterState state) {
  final auth = AuthService.instance;
  final session = SessionService.instance;
  final location = state.matchedLocation;

  // The splash screen decides for itself where to go once its animation
  // finishes, and it must render while signed out. Never redirect it.
  if (location == '/splash') return null;

  final signedIn = auth.isSignedIn;

  // Signed out and asking for a protected screen → go choose a role and log in.
  if (!signedIn && !_isPublic(location)) {
    return '/role-select';
  }

  if (!signedIn) return null;

  // Signed in, but the profile has not arrived yet. Redirecting now would
  // bounce a perfectly onboarded user into onboarding for the few frames before
  // the first Firestore snapshot lands. Sit still instead.
  if (session.isLoading) return null;

  // Mid-write: the onboarding screen is committing documents and will navigate
  // itself once it is done. Yanking it away here would interrupt the write.
  if (session.isProvisioning) return null;

  // The profile couldn't even be read — almost always Firestore rejecting the
  // request outright, not "no profile yet" (see SessionState.error). Whoever
  // triggered this is already responsible for recovering: AuthService signs
  // out and surfaces a message when a sign-in attempt hits it,
  // welcome_screen does the same on a cold start. The guard's job here is
  // just to not make it worse — never route this into onboarding, and never
  // treat it as good enough to bounce off a login screen (see the isReady
  // check below).
  if (session.hasError) return null;

  // The gate. A user with no profile document, or one still missing
  // role-specific fields, has exactly one destination.
  if (session.needsProfile) {
    return location == _onboardingRoute ? null : _onboardingRoute;
  }

  // Onboarding is finished — nobody should be able to walk back into it. Not
  // `session.needsProfile` above means the profile is loaded and complete, so
  // `session.user.value` is the authoritative source here — `auth.cachedRole`
  // is only a same-device SharedPreferences guess that can go stale (e.g. it
  // survives a failed sign-in on a *different* account until the next
  // successful one overwrites it) and is now just the last-resort fallback
  // for the sliver of a frame before that value has arrived.
  if (location == _onboardingRoute) {
    return AuthService.routeForRole(
      session.user.value?.role.name ?? auth.cachedRole ?? 'parent',
    );
  }

  // Already signed in with a working session but sitting on an auth screen →
  // jump to their own home. The role comes from the live Firestore profile,
  // so a parent can never be routed into the driver app by editing the URL —
  // see the comment above for why that source is preferred over
  // `auth.cachedRole` here too.
  //
  // Requiring `isReady` (not just "signedIn is true") matters:
  // `AuthService.signOut` tears down the Firestore session *before* ending the
  // Firebase Auth one, so there is a brief window where `isSignedIn` is still
  // true but the session has already reset to `signedOut`/`error`. A failed
  // Google sign-in attempt on `/login/:role` triggers exactly that sequence —
  // without this check, this branch would catch that window and bounce the
  // user straight into a dashboard they have no working session for, instead
  // of leaving them on the login screen to see why it failed.
  if (session.isReady &&
      (location.startsWith('/login/') || location == '/signup')) {
    return AuthService.routeForRole(
      session.user.value?.role.name ?? auth.cachedRole ?? 'parent',
    );
  }

  return null;
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: _guard,
  // Two sources, because two different things change the answer: the Firebase
  // session starting or ending, and the Firestore profile arriving or becoming
  // complete. Listening only to auth would leave the guard stale for the whole
  // window between sign-in and the first snapshot.
  refreshListenable: Listenable.merge([
    _AuthRefresh(AuthService.instance.authStateChanges),
    SessionService.instance,
  ]),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
    GoRoute(
      path: '/role-select',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/login/:role',
      builder: (context, state) {
        final role = state.pathParameters['role'] ?? 'parent';
        return LoginScreen(role: role);
      },
    ),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    // The role reaches this screen through the `users/{uid}` document itself —
    // `AuthService.signInWithGoogle` writes it the moment a first-time Google
    // account is detected, using the role its caller (always a role-specific
    // `/login/:role` screen) already knew. `/role-select` only ever asks once.
    // See `ProfileCompletionScreen._resolveRole` for how it is read back.
    GoRoute(
      path: _onboardingRoute,
      builder: (context, state) => const ProfileCompletionScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(path: '/parent', builder: (context, state) => const ParentLayout()),
    GoRoute(
      path: '/parent/language',
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/parent/help-support',
      builder: (context, state) => const HelpSupportScreen(),
    ),
    GoRoute(
      path: '/parent/live-chat',
      builder: (context, state) => const LiveChatScreen(),
    ),
    GoRoute(
      path: '/parent/driver-details',
      builder: (context, state) => const DriverDetailsScreen(),
    ),
    GoRoute(
      path: '/parent/find-drivers',
      builder: (context, state) => const FindDriversScreen(),
    ),
    // The same screen, themed for the student shell. Students book their own
    // seat exactly as a parent books their child's, so duplicating the screen
    // per role would mean maintaining the matchmaking UI twice.
    GoRoute(
      path: '/student/find-drivers',
      builder: (context, state) =>
          const FindDriversScreen(accent: AppTheme.studentAmber),
    ),
    GoRoute(
      path: '/parent/driver-chat',
      builder: (context, state) => const DriverChatScreen(),
    ),
    GoRoute(
      path: '/parent/trips',
      builder: (context, state) => const TripHistoryScreen(),
    ),
    GoRoute(
      path: '/parent/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/parent/emergency-contacts',
      builder: (context, state) => const EmergencyContactsScreen(),
    ),
    GoRoute(
      path: '/parent/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/parent/rate-app',
      builder: (context, state) =>
          const RateAppScreen(accentColor: AppTheme.parentPurple),
    ),
    GoRoute(
      path: '/parent/terms',
      builder: (context, state) =>
          const TermsScreen(accentColor: AppTheme.parentPurple),
    ),
    GoRoute(
      path: '/parent/payment',
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return PaymentMethodScreen(
          amount: extra['amount'] as String? ?? 'Rs.0',
          month: extra['month'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/parent/payment/cash',
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return CashPaymentScreen(
          amount: extra['amount'] as String? ?? 'Rs.0',
          month: extra['month'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/parent/payment/online',
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        final rawChildren = extra['children'] as List<dynamic>? ?? [];
        final children = rawChildren
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
        return OnlinePaymentScreen(
          amount: extra['amount'] as String? ?? 'Rs.0',
          month: extra['month'] as String? ?? '',
          children: children,
        );
      },
    ),
    GoRoute(
      path: '/parent/payment/card',
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return CardPaymentScreen(
          amount: extra['amount'] as String? ?? 'Rs.0',
          month: extra['month'] as String? ?? '',
        );
      },
    ),
    GoRoute(path: '/driver', builder: (context, state) => const DriverLayout()),
    GoRoute(
      path: '/driver/trips',
      builder: (context, state) => const DriverTripHistoryScreen(),
    ),
    GoRoute(
      path: '/driver/performance',
      builder: (context, state) => const DriverPerformanceScreen(),
    ),
    GoRoute(
      path: '/driver/documents',
      builder: (context, state) => const DriverDocumentsScreen(),
    ),
    GoRoute(
      path: '/driver/subscription',
      builder: (context, state) => const DriverSubscriptionScreen(),
    ),
    GoRoute(
      path: '/driver/payment-history',
      builder: (context, state) => const DriverPaymentHistoryScreen(),
    ),
    GoRoute(
      path: '/driver/language',
      builder: (context, state) =>
          const LanguageScreen(accentColor: AppTheme.driverCyan),
    ),
    GoRoute(
      path: '/driver/change-password',
      builder: (context, state) =>
          const ChangePasswordScreen(accentColor: AppTheme.driverCyan),
    ),
    GoRoute(
      path: '/driver/emergency-contacts',
      builder: (context, state) =>
          const EmergencyContactsScreen(accentColor: AppTheme.driverCyan),
    ),
    GoRoute(
      path: '/driver/help-support',
      builder: (context, state) =>
          const HelpSupportScreen(accentColor: AppTheme.driverCyan),
    ),
    GoRoute(
      path: '/driver/terms',
      builder: (context, state) =>
          const TermsScreen(accentColor: AppTheme.driverCyan),
    ),
    GoRoute(
      path: '/driver/rate-app',
      builder: (context, state) =>
          const RateAppScreen(accentColor: AppTheme.driverCyan),
    ),
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentLayout(),
    ),
    GoRoute(
      path: '/student/language',
      builder: (context, state) =>
          const LanguageScreen(accentColor: AppTheme.studentAmber),
    ),
    GoRoute(
      path: '/student/change-password',
      builder: (context, state) =>
          const ChangePasswordScreen(accentColor: AppTheme.studentAmber),
    ),
    GoRoute(
      path: '/student/emergency-contacts',
      builder: (context, state) =>
          const EmergencyContactsScreen(accentColor: AppTheme.studentAmber),
    ),
    GoRoute(
      path: '/student/help-support',
      builder: (context, state) =>
          const HelpSupportScreen(accentColor: AppTheme.studentAmber),
    ),
    GoRoute(
      path: '/student/rate-app',
      builder: (context, state) =>
          const RateAppScreen(accentColor: AppTheme.studentAmber),
    ),
    GoRoute(
      path: '/student/missed-bus',
      builder: (context, state) => const MissedBusScreen(),
    ),
    GoRoute(
      path: '/student/trips',
      builder: (context, state) => const StudentTripHistoryScreen(),
    ),
    GoRoute(
      path: '/student/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/student/terms',
      builder: (context, state) => const TermsScreen(),
    ),
    GoRoute(
      path: '/student/notifications',
      builder: (context, state) => const StudentNotifications(),
    ),
    // One-off missed-bus pickups, distinct from the ongoing seat arrangement
    // below — the two look similar on screen but are different commitments.
    GoRoute(
      path: '/driver/pickup-requests',
      builder: (context, state) => const DriverPickupRequestsScreen(),
    ),
    GoRoute(
      path: '/driver/ride-requests',
      builder: (context, state) => const DriverRideRequestsScreen(),
    ),
    GoRoute(
      path: '/driver/service',
      builder: (context, state) => const DriverServiceScreen(),
    ),
    GoRoute(
      path: '/parent/missed-bus',
      builder: (context, state) => const ParentMissedBusScreen(),
    ),
    // Fullscreen, interactive live-tracking map — a bigger window onto
    // whichever tracking session is already running, opened from the
    // parent/student Track tab's inline (non-interactive) map preview.
    GoRoute(
      path: '/parent/track/map',
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return LiveMapScreen(
          accentColor: AppTheme.parentPurple,
          highlightedStopName: extra['highlightedStopName'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/student/track/map',
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return LiveMapScreen(
          accentColor: AppTheme.studentAmber,
          highlightedStopName: extra['highlightedStopName'] as String?,
        );
      },
    ),
  ],
);
