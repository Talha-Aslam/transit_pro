import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/auth_service.dart';
import '../../app/language_provider.dart';
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

  static const int _trackTab = 1;

  void _goToTab(int index) => setState(() => _tab = index);

  List<_NavItem> get _navItems => [
    _NavItem(
      icon: 'assets/images/navbar/home_transparent.png',
      label: AppStrings.t('snav_home'),
    ),
    _NavItem(
      icon: 'assets/images/navbar/track_transparent.png',
      label: AppStrings.t('snav_track'),
    ),
    _NavItem(
      icon: 'assets/images/navbar/calendar_transparent.png',
      label: AppStrings.t('snav_schedule'),
    ),
    _NavItem(
      icon: 'assets/images/navbar/qr_pass.png',
      label: AppStrings.t('snav_qr'),
    ),
    _NavItem(
      icon: 'assets/images/navbar/fees.png',
      label: AppStrings.t('snav_fees'),
    ),
    _NavItem(
      icon: 'assets/images/navbar/user_transparent.png',
      label: AppStrings.t('snav_profile'),
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
              StudentDashboard(onNavigate: _goToTab),
              // StudentTracking hosts a GoogleMap platform view.
              // Render it ONLY while the Track tab is active so the native
              // MapView/TextureView render loop is fully stopped on other tabs.
              if (_tab == _trackTab)
                StudentTracking(onBack: () => _goToTab(0))
              else
                const SizedBox.shrink(),
              const StudentSchedule(),
              const StudentAttendance(),
              const StudentFees(),
              StudentProfile(
                onLogout: () {
                  AuthService.instance.clearRole();
                  context.go('/role-select');
                },
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
    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                            vertical: 7,
                            horizontal: 2,
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
                                width: isActive ? 26 : 22,
                                height: isActive ? 26 : 22,
                                cacheWidth: 56,
                                cacheHeight: 56,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _navItems[i].label,
                                style: TextStyle(
                                  color: isActive
                                      ? AppTheme.studentAccent
                                      : context.textTertiary,
                                  fontSize: isActive ? 10 : 9,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
      ),
    );
  }
}

class _NavItem {
  final String icon, label;
  const _NavItem({required this.icon, required this.label});
}
