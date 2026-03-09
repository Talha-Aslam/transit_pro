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
import '../screens/parent/payment_screens.dart';

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
      path: '/student',
      builder: (context, state) => const StudentLayout(),
    ),
  ],
);
