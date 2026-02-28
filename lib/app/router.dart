import 'package:go_router/go_router.dart';
import '../screens/welcome_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/login_screen.dart';
import '../screens/parent/parent_layout.dart';
import '../screens/driver/driver_layout.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
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
    GoRoute(
      path: '/parent',
      builder: (context, state) => const ParentLayout(),
    ),
    GoRoute(
      path: '/driver',
      builder: (context, state) => const DriverLayout(),
    ),
  ],
);
