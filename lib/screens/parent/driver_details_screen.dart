import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../data/user_repository.dart';
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

  /// The assigned driver's real record, fetched by id (`child.driver` holds
  /// the driver's uid — see ParentDataService._rebuild). Feeds the contact
  /// number/experience/seats tile that used to come from a hardcoded map
  /// keyed by bus number.
  Driver? _driver;

  /// Whether this child has ever completed a ride with their currently
  /// assigned driver — resolved once (this screen doesn't react to a child
  /// switch happening while it's open), and gates whether the rating card
  /// renders at all. See `ParentDataService.hasRiddenWithDriver`.
  bool _hasRidden = false;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _svc.driverRatings.addListener(_onRatingChanged);
    _svc.loadDriverRatings();
    _loadDriver();
    _loadHasRidden();
  }

  Future<void> _loadDriver() async {
    final child = _svc.selectedChild;
    if (child == null || child.driver.isEmpty) return;
    final driver = await UserRepository.instance.fetchDriver(child.driver);
    if (mounted) setState(() => _driver = driver);
  }

  Future<void> _loadHasRidden() async {
    final child = _svc.selectedChild;
    if (child == null) return;
    final ridden = await _svc.hasRiddenWithDriver(child);
    if (mounted) setState(() => _hasRidden = ridden);
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
    final stop = child?.stop.isNotEmpty == true ? child!.stop : '—';
    final meta = _driverInfoMetaFor(
      driver: _driver,
      transportNumber: busNumber,
    );
    final driverRating = child == null ? null : _svc.driverRatingFor(child);
    final canRate = child != null && _hasRidden && _svc.canRateDriver(child);

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
                        enableBlur: false,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.parentPurple.withValues(alpha: 0.16),
                            AppTheme.info.withValues(alpha: 0.05),
                          ],
                        ),
                        borderColor: AppTheme.parentPurple.withValues(
                          alpha: 0.25,
                        ),
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
                              label: 'Contact Number',
                              value: meta.contactNumber,
                              icon: '📞',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              label: 'Experience',
                              value: meta.experience,
                              icon: '📅',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: 'Transport Number',
                              value: meta.transportNumber,
                              icon: '🚌',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              label: 'Total Seats',
                              value: meta.totalSeats,
                              icon: '👥',
                            ),
                          ),
                        ],
                      ),
                      if (_hasRidden && child != null) ...[
                        const SizedBox(height: 16),
                        GlassCard(
                          enableBlur: false,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                      ],
                      // Hidden with no driver assigned yet — there is
                      // nobody on the other end of this chat.
                      if (child != null && child.driver.trim().isNotEmpty) ...[
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
      enableBlur: false,
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

class _DriverInfoMeta {
  final String contactNumber;
  final String experience;
  final String transportNumber;
  final String totalSeats;

  const _DriverInfoMeta({
    required this.contactNumber,
    required this.experience,
    required this.transportNumber,
    required this.totalSeats,
  });
}

/// Built from the real driver record when it's loaded; a hardcoded map keyed
/// by bus number used to stand in for this, which showed the same fabricated
/// phone/experience/seat-count for every driver on that bus regardless of who
/// actually held it.
_DriverInfoMeta _driverInfoMetaFor({
  required Driver? driver,
  required String transportNumber,
}) {
  final resolvedTransport = transportNumber == '—' ? 'N/A' : transportNumber;
  if (driver == null) {
    return _DriverInfoMeta(
      contactNumber: '—',
      experience: '—',
      transportNumber: resolvedTransport,
      totalSeats: '—',
    );
  }
  return _DriverInfoMeta(
    contactNumber: driver.phone.isNotEmpty ? driver.phone : '—',
    experience: driver.experienceYears > 0
        ? '${driver.experienceYears} year${driver.experienceYears == 1 ? '' : 's'}'
        : '—',
    transportNumber: resolvedTransport,
    // Driver has no single "vehicle capacity" field — seats live per round
    // on DriverSchedule — so this sums seats offered across every round the
    // driver runs as the closest real proxy for "total seats".
    totalSeats: '${driver.totalSeatsOffered}',
  );
}
