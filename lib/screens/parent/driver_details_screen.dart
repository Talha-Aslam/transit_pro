import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen({super.key});

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final _svc = ParentDataService.instance;
  double _selectedRating = 5.0;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _svc.driverRatings.addListener(_onRatingChanged);
    _svc.loadDriverRatings();
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _svc.driverRatings.removeListener(_onRatingChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  void _onRatingChanged() => setState(() {});

  Future<void> _submitWeeklyRating(ChildInfo child) async {
    await _svc.rateDriverForChild(child, _selectedRating);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Thanks for rating ${child.driver} $_selectedRating/5 this week.',
        ),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _svc.selectedChild;
    final driverName = child?.driver.trim().isNotEmpty == true
        ? child!.driver.trim()
        : AppStrings.t('no_driver_assigned');
    final busNumber = child?.busNumber.isNotEmpty == true
        ? child!.busNumber
        : '—';
    final route = child?.route.isNotEmpty == true ? child!.route : '—';
    final stop = child?.stop.isNotEmpty == true ? child!.stop : '—';
    final driverRating = child == null ? null : _svc.driverRatingFor(child);
    final canRate = child != null && _svc.canRateDriver(child);

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.parentPurple.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
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
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: AppTheme.parentGradient,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Center(
                                child: Text(
                                  '🧑‍✈️',
                                  style: TextStyle(fontSize: 34),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              driverName,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              child?.school.isNotEmpty == true
                                  ? child!.school
                                  : AppStrings.t('no_driver_details'),
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: AppStrings.t('selected_bus'),
                              value: busNumber,
                              icon: '🚌',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              label: AppStrings.t('selected_stop'),
                              value: stop,
                              icon: '📍',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: AppStrings.t('selected_route'),
                              value: route,
                              icon: '🛣️',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              label: AppStrings.t('driver'),
                              value: driverName,
                              icon: '👨‍✈️',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Driver Rating',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canRate
                                  ? 'Rate your driver once per week based on punctuality, safety, and service.'
                                  : 'You already rated this driver for this week.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            if (driverRating != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Last rating: ${driverRating.rating.toStringAsFixed(1)}/5',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(5, (index) {
                                final starValue = index + 1;
                                final active = starValue <= _selectedRating;
                                return GestureDetector(
                                  onTap: canRate
                                      ? () => setState(
                                          () => _selectedRating = starValue
                                              .toDouble(),
                                        )
                                      : null,
                                  child: Icon(
                                    active
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: canRate
                                        ? Colors.amber
                                        : context.textHint,
                                    size: 30,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: GestureDetector(
                                onTap: canRate
                                    ? () => _submitWeeklyRating(child)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: canRate
                                        ? AppTheme.parentGradient
                                        : LinearGradient(
                                            colors: [
                                              context.surfaceBorder,
                                              context.surfaceBorder,
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      canRate
                                          ? 'Submit Weekly Rating'
                                          : 'Rating Submitted This Week',
                                      style: TextStyle(
                                        color: canRate
                                            ? Colors.white
                                            : context.textSecondary,
                                        fontSize: 14,
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
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => context.push('/parent/driver-chat'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: AppTheme.parentGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              AppStrings.t('driver_chat'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
  final String label;
  final String value;
  final String icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
