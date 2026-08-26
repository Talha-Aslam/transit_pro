import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../app/session_service.dart';
import '../../app/student_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'student_driver_chat.dart';

class StudentDriverDetailsScreen extends StatefulWidget {
  final StudentInfo student;

  const StudentDriverDetailsScreen({super.key, required this.student});

  @override
  State<StudentDriverDetailsScreen> createState() =>
      _StudentDriverDetailsScreenState();
}

class _StudentDriverDetailsScreenState
    extends State<StudentDriverDetailsScreen> {
  double _selectedRating = 5.0;

  /// Whether this student has ever completed a ride with their currently
  /// assigned driver — gates whether the rating card renders at all. See
  /// `ParentDataService.hasRiddenWithDriver`.
  bool _hasRidden = false;

  /// Built once from `widget.student`, which is always this student's own
  /// profile (never another child's — this screen has no child switcher).
  /// `StudentInfo` doesn't carry the real Firestore student id (only the
  /// human-readable `studentId` number), so [id] comes from the live
  /// session instead — it's what `TripRepository.fetchAttendanceForStudent`
  /// needs. `driver` is `widget.student.driverId` (the driver's real id),
  /// not `driverName` — `ParentDataService`'s `_driverKey`/weekly gate and
  /// the completed-ride check both key off a real driver id.
  late final ChildInfo _child = ChildInfo(
    id: SessionService.instance.student.value?.id ?? '',
    name: widget.student.name,
    grade: widget.student.grade,
    school: widget.student.school,
    busNumber: widget.student.busNumber,
    route: widget.student.route,
    stop: widget.student.stop,
    driver: widget.student.driverId,
  );

  @override
  void initState() {
    super.initState();
    ParentDataService.instance.driverRatings.addListener(_onRatingChanged);
    // `ParentDataService` only auto-loads ratings for a parent session; a
    // student rater needs this explicit call, same as the parent screen's.
    ParentDataService.instance.loadDriverRatings();
    final existing = ParentDataService.instance.driverRatingFor(_child);
    if (existing != null) _selectedRating = existing.rating;
    _loadHasRidden();
  }

  @override
  void dispose() {
    ParentDataService.instance.driverRatings.removeListener(_onRatingChanged);
    super.dispose();
  }

  void _onRatingChanged() => setState(() {});

  Future<void> _loadHasRidden() async {
    final ridden = await ParentDataService.instance.hasRiddenWithDriver(_child);
    if (mounted) setState(() => _hasRidden = ridden);
  }

  @override
  Widget build(BuildContext context) {
    final driverRating = ParentDataService.instance.driverRatingFor(_child);
    final canRate =
        _hasRidden && ParentDataService.instance.canRateDriver(_child);
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
                          widget.student.driverName,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.student.school,
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
                      value: widget.student.busNumber,
                    ),
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '📍',
                      label: AppStrings.t('selected_stop'),
                      value: widget.student.stop,
                    ),
                    _InfoTile(
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      icon: '📞',
                      label: AppStrings.t('driver_phone_lbl'),
                      value: widget.student.driverPhone,
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
                      value: widget.student.busNumber,
                    ),
                    // No real "total seats" value is available from
                    // `StudentInfo`/session data on this screen — the tile
                    // used to show a fabricated '28' here, which is worse
                    // than not showing it at all.
                  ],
                ),
                if (_hasRidden) ...[
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
                        if (driverRating != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Last rating: ${driverRating.rating.toStringAsFixed(1)}/5',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (!canRate) ...[
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.t('already_rated'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final idx = i + 1;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: IconButton(
                                onPressed: canRate
                                    ? () => setState(() {
                                        _selectedRating = idx.toDouble();
                                      })
                                    : null,
                                icon: Icon(
                                  Icons.star,
                                  color: !canRate
                                      ? context.textHint
                                      : idx <= _selectedRating
                                      ? Colors.amber
                                      : context.surfaceBorder,
                                  size: 32,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        // Submit weekly rating button inside card
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: !canRate
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );

                                    await ParentDataService.instance
                                        .rateDriverForChild(
                                          _child,
                                          _selectedRating,
                                        );
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Rating submitted: ${_selectedRating.toStringAsFixed(1)}/5',
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: canRate
                                    ? AppTheme.parentGradient
                                    : LinearGradient(
                                        colors: [
                                          context.surfaceBorder,
                                          context.surfaceBorder,
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(28),
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
                ],
                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentDriverChat(
                          driverName: widget.student.driverName,
                          busNumber: widget.student.busNumber,
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
        // Rendered 6 times side by side in the info grid above — a
        // repeated-item card, not a one-off.
        enableBlur: false,
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
