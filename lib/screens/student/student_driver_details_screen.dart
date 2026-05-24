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
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.inputBorder),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: context.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('my_driver'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.t('selected_driver'),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Large avatar card
                Center(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 26,
                    ),
                    borderRadius: 18,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.parentPurple.withValues(alpha: 0.12),
                        AppTheme.info.withValues(alpha: 0.02),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: AppTheme.parentGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text(
                              '🧑‍✈️',
                              style: TextStyle(fontSize: 34),
                            ),
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
                        const SizedBox(height: 6),
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
                ),
                const SizedBox(height: 18),

                // Grid info tiles
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '🚌',
                      label: AppStrings.t('selected_bus'),
                      value: student.busNumber,
                    ),
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '📍',
                      label: AppStrings.t('selected_stop'),
                      value: student.stop,
                    ),
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '📞',
                      label: AppStrings.t('driver_phone_lbl'),
                      value: student.driverPhone,
                    ),
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '📅',
                      label: 'Experience',
                      value: '8 years',
                    ),
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '🚌',
                      label: 'Transport Number',
                      value: student.busNumber,
                    ),
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '👥',
                      label: 'Total Seats',
                      value: '28',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Rating card (centered)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Weekly Driver Rating',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rate your driver once per week based on punctuality, safety, and service.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Last rating: 1.0/5',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final filled = i < 1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Icon(
                              Icons.star,
                              color: filled
                                  ? Colors.amber
                                  : context.surfaceBorder,
                              size: 32,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      // Submit weekly rating button inside card
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () {
                            // TODO: implement rating submission
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: AppTheme.parentGradient,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Text(
                                'Submit Weekly Rating',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
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
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.parentGradient,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Text(
                        AppStrings.t('driver_chat'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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

class _InfoTile extends StatelessWidget {
  final double width;
  final String icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
