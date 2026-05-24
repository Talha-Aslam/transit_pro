import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../app/student_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'student_driver_chat.dart';

class StudentDriverDetailsScreen extends StatelessWidget {
  final StudentInfo student;

  const StudentDriverDetailsScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.inputBorder),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: context.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppStrings.t('driver_lbl'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassCard(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.parentPurple.withValues(alpha: 0.16),
                      AppTheme.info.withValues(alpha: 0.05),
                    ],
                  ),
                  borderColor: AppTheme.parentPurple.withValues(alpha: 0.25),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppTheme.parentGradient,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Center(
                          child: Text('🧑‍✈️', style: TextStyle(fontSize: 34)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        student.driverName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.school,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _Detail(
                        icon: '📞',
                        label: AppStrings.t('driver_phone_lbl'),
                        value: student.driverPhone,
                      ),
                      _Detail(
                        icon: '🚌',
                        label: AppStrings.t('bus_lbl'),
                        value: student.busNumber,
                      ),
                      _Detail(
                        icon: '🗺️',
                        label: AppStrings.t('route_lbl'),
                        value: student.route,
                      ),
                      _Detail(
                        icon: '🚏',
                        label: AppStrings.t('stop_lbl'),
                        value: student.stop,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentDriverChat(
                          driverName: student.driverName,
                          busNumber: student.busNumber,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.parentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        AppStrings.t('driver_chat'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool isLast;

  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Container(height: 1, color: context.surfaceBorder),
      ],
    );
  }
}
