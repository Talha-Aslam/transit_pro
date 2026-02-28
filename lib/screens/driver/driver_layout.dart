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
    _NavItem(icon: '🏠', label: 'Home'),
    _NavItem(icon: '👦', label: 'Students'),
    _NavItem(icon: '🗺️', label: 'Route'),
    _NavItem(icon: '💬', label: 'Messages'),
    _NavItem(icon: '👤', label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: List.generate(_navItems.length, (i) {
                  final isActive = _tab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _goToTab(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: isActive
                                ? BoxDecoration(
                                    color: AppTheme.driverCyan.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : null,
                            child: Text(
                              _navItems[i].icon,
                              style: TextStyle(fontSize: isActive ? 22 : 20),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _navItems[i].label,
                            style: TextStyle(
                              color: isActive ? AppTheme.driverAccent : Colors.white.withOpacity(0.4),
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
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
