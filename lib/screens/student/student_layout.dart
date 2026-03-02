import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'student_dashboard.dart';
import 'student_tracking.dart';
import 'student_schedule.dart';
import 'student_attendance.dart';
import 'student_fees.dart';
import 'student_profile.dart';

class StudentLayout extends StatefulWidget {
  const StudentLayout({super.key});

  @override
  State<StudentLayout> createState() => _StudentLayoutState();
}

class _StudentLayoutState extends State<StudentLayout> {
  int _tab = 0;

  void _goToTab(int index) => setState(() => _tab = index);

  static const _navItems = [
    _NavItem(icon: '🏠', label: 'Home'),
    _NavItem(icon: '📍', label: 'Track'),
    _NavItem(icon: '📅', label: 'Schedule'),
    _NavItem(icon: '📱', label: 'QR Pass'),
    _NavItem(icon: '💰', label: 'Fees'),
    _NavItem(icon: '👤', label: 'Profile'),
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
              StudentDashboard(onNavigate: _goToTab),
              StudentTracking(onBack: () => _goToTab(0)),
              const StudentSchedule(),
              const StudentAttendance(),
              const StudentFees(),
              StudentProfile(onLogout: () => context.go('/role-select')),
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
            color: context.isDark
                ? Colors.black.withOpacity(0.45)
                : Colors.white.withOpacity(0.85),
            border: Border(top: BorderSide(color: context.cardBgElevated)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
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
                            padding: const EdgeInsets.all(6),
                            decoration: isActive
                                ? BoxDecoration(
                                    color: AppTheme.studentAmber.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : null,
                            child: Text(
                              _navItems[i].icon,
                              style: TextStyle(fontSize: isActive ? 20 : 18),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _navItems[i].label,
                            style: TextStyle(
                              color: isActive
                                  ? AppTheme.studentAccent
                                  : context.textTertiary,
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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
