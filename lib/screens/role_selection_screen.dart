import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/language_provider.dart';
import '../theme/app_theme.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selected;
  late AnimationController _rainbowCtrl;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _rainbowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  void _onLangChanged() => setState(() {});

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _rainbowCtrl.dispose();
    super.dispose();
  }

  final List<_RoleConfig> _roles = [
    _RoleConfig(
      id: 'parent',
      icon: 'assets/images/role_selection/welcome_parent_transparent.gif',
      label: "I'm a Parent",
      desc: "Monitor your child's school commute in real-time",
      gradient: const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFF7C3AED),
      accent: AppTheme.parentAccent,
      // features: ['Live bus tracking', 'Arrival alerts', 'Safe ride history'],
    ),
    _RoleConfig(
      id: 'driver',
      icon: 'assets/images/role_selection/welcome_driver_transparent.gif',
      label: "I'm a Driver",
      desc: "Manage your route, students & daily schedule",
      gradient: const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF0891B2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFF0EA5E9),
      accent: AppTheme.driverAccent,
      // features: ['Student attendance', 'Route navigation', 'Parent messaging'],
    ),
    _RoleConfig(
      id: 'student',
      icon: 'assets/images/role_selection/welcome_student_transparent.gif',
      label: "I'm a Student",
      desc: 'View bus schedule, track ride & manage fees',
      gradient: const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: Color(0xFFF59E0B),
      accent: AppTheme.studentAccent,
      // features: ['Bus tracking', 'QR attendance', 'Fee status'],
    ),
  ];

  void _selectRole(String id) {
    setState(() => _selected = id);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) context.go('/login/$id');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Purple blob top-left
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(
                        0xFF7C3AED,
                      ).withOpacity(context.isDark ? 0.25 : 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Amber blob top-right
            Positioned(
              top: 60,
              right: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(
                        0xFFF59E0B,
                      ).withOpacity(context.isDark ? 0.15 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Cyan blob bottom-right
            Positioned(
              bottom: -40,
              right: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(
                        0xFF0EA5E9,
                      ).withOpacity(context.isDark ? 0.20 : 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Indigo blob bottom-left
            Positioned(
              bottom: 0,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(
                        0xFF4F46E5,
                      ).withOpacity(context.isDark ? 0.18 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 66,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Header badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? AppTheme.purple.withOpacity(0.18)
                                    : Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: context.isDark
                                      ? AppTheme.purple.withOpacity(0.45)
                                      : AppTheme.purple.withOpacity(0.35),
                                  width: 1.5,
                                ),
                                boxShadow: context.isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppTheme.purple.withOpacity(
                                            0.12,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: AnimatedBuilder(
                                animation: _rainbowCtrl,
                                builder: (context, child) {
                                  // Hue offset rotates full 360° per loop.
                                  // At t=0 and t=1 hue%360 is identical → no seam.
                                  final offset = _rainbowCtrl.value * 360;
                                  Color hue(double base) => HSVColor.fromAHSV(
                                    1.0,
                                    (base + offset) % 360,
                                    1.0,
                                    1.0,
                                  ).toColor();
                                  return ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        hue(0), // red → yellow → ...
                                        hue(40),
                                        hue(80),
                                        hue(160),
                                        hue(220),
                                        hue(280),
                                      ],
                                    ).createShader(bounds),
                                    child: child,
                                  );
                                },
                                child: Text(
                                  AppStrings.t('welcome_banner'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 65),
                            Text(
                              AppStrings.t('select_role'),
                              style: TextStyle(
                                color: context.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Role cards
                            ..._roles.map((role) {
                              final isSelected = _selected == role.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 25),
                                child: GestureDetector(
                                  onTap: () => _selectRole(role.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? context.surfaceBorder
                                          : context.cardBg,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSelected
                                            ? role.accent
                                            : context.surfaceBorder,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: role.glowColor
                                                    .withOpacity(0.3),
                                                blurRadius: 30,
                                                offset: const Offset(0, 8),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,

                                      children: [
                                        // Icon
                                        Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            gradient: role.gradient,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: role.glowColor
                                                    .withOpacity(
                                                      context.isDark
                                                          ? 0.45
                                                          : 0.30,
                                                    ),
                                                blurRadius: 20,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            child: Image.asset(
                                              role.icon,
                                              width: 62,
                                              height: 62,
                                              fit: BoxFit.cover,
                                              filterQuality: FilterQuality.high,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                AppStrings.t(
                                                  '${role.id}_label',
                                                ),
                                                style: TextStyle(
                                                  color: context.textPrimary,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                AppStrings.t('${role.id}_desc'),
                                                style: TextStyle(
                                                  color: context.textSecondary,
                                                  fontSize: 12.5,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Radio
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: isSelected
                                                ? role.gradient
                                                : null,
                                            color: isSelected
                                                ? null
                                                : context.isDark
                                                ? Colors.white.withOpacity(0.08)
                                                : const Color(0xFFE2E8F0),
                                            border: Border.all(
                                              color: isSelected
                                                  ? role.accent
                                                  : context.isDark
                                                  ? Colors.white.withOpacity(
                                                      0.2,
                                                    )
                                                  : const Color(0xFFCBD5E1),
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Center(
                                                  child: Text(
                                                    '✓',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // ── Language toggle ──────────────────────────
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                14,
                                12,
                                14,
                              ),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.surfaceBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.language_rounded,
                                        size: 13,
                                        color: context.textTertiary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Language · زبان',
                                        style: TextStyle(
                                          color: context.textTertiary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _LangChip(
                                        label: '🇬🇧  English',
                                        selected:
                                            !LanguageProvider.instance.isUrdu,
                                        onTap: () => LanguageProvider.instance
                                            .setLanguage('English'),
                                      ),
                                      const SizedBox(width: 8),
                                      _LangChip(
                                        label: 'اردو  🇵🇰',
                                        selected:
                                            LanguageProvider.instance.isUrdu,
                                        onTap: () => LanguageProvider.instance
                                            .setLanguage('Urdu'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Push footer to bottom
                            const Spacer(),

                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppStrings.t('no_account'),
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.go('/signup'),
                                  child: Text(
                                    AppStrings.t('sign_up'),
                                    style: TextStyle(
                                      color: AppTheme.parentAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AppStrings.t('data_secure'),
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleConfig {
  final String id, icon, label, desc;
  final LinearGradient gradient;
  final Color glowColor, accent;
  // final List<String> features;

  const _RoleConfig({
    required this.id,
    required this.icon,
    required this.label,
    required this.desc,
    required this.gradient,
    required this.glowColor,
    required this.accent,
    // required this.features,
  });
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.parentGradient : null,
            color: selected ? null : context.cardBgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.transparent : context.inputBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.parentPurple.withOpacity(0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
