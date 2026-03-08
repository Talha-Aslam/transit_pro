import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'driver_dashboard.dart';
import 'driver_attendance.dart';
import 'driver_route.dart';
import 'driver_notifications.dart';
import 'driver_profile.dart';

class DriverLayout extends StatefulWidget {
  const DriverLayout({super.key});

  @override
  State<DriverLayout> createState() => _DriverLayoutState();
}

class _DriverLayoutState extends State<DriverLayout> {
  int _tab = 0;

  void _goToTab(int index) => setState(() => _tab = index);

  static const _navItems = [
    _NavItem(icon: 'assets/images/navbar/home_transparent.png', label: 'Home'),
    _NavItem(icon: 'assets/images/navbar/student.png', label: 'Students'),
    _NavItem(
      icon: 'assets/images/navbar/track_transparent.png',
      label: 'Route',
    ),
    _NavItem(
      icon: 'assets/images/navbar/notification_transparent.png',
      label: 'Alerts',
    ),
    _NavItem(
      icon: 'assets/images/navbar/user_transparent.png',
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: [
              DriverDashboard(onNavigate: _goToTab),
              DriverAttendance(onBack: () => _goToTab(0)),
              DriverRoute(onBack: () => _goToTab(0)),
              DriverNotifications(onBack: () => _goToTab(0)),
              DriverProfile(
                onNavigate: _goToTab,
                onLogout: () => context.go('/role-select'),
              ),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.80),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: List.generate(_navItems.length, (i) {
                  final isActive = _tab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _goToTab(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        decoration: isActive
                            ? BoxDecoration(
                                color: context.isDark
                                    ? Colors.white.withOpacity(0.20)
                                    : Colors.white.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              )
                            : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              _navItems[i].icon,
                              width: isActive ? 28 : 22,
                              height: isActive ? 28 : 22,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _navItems[i].label,
                              style: TextStyle(
                                color: isActive
                                    ? AppTheme.driverAccent
                                    : context.textTertiary,
                                fontSize: isActive ? 10 : 9,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String icon, label;
  const _NavItem({required this.icon, required this.label});
}
