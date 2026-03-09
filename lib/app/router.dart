import 'package:go_router/go_router.dart';
import '../screens/welcome_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/parent/parent_layout.dart';
import '../screens/parent/language_screen.dart';
import '../screens/parent/help_support_screen.dart';
import '../screens/parent/live_chat_screen.dart';
import '../screens/parent/trip_history_screen.dart';
import '../screens/parent/subscription_screen.dart';
import '../screens/parent/emergency_contacts_screen.dart';
import '../screens/parent/change_password_screen.dart';
import '../screens/parent/rate_app_screen.dart';
import '../screens/driver/driver_layout.dart';
import '../screens/student/student_layout.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
      builder: (context, state) => const RateAppScreen(),
    ),
    GoRoute(path: '/driver', builder: (context, state) => const DriverLayout()),
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentLayout(),
    ),
  ],
);
