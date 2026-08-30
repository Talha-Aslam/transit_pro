import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../data/rating_repository.dart';
import '../../data/trip_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_rating_bar.dart';
import '../../widgets/glass_card.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _MonthStat {
  final String month;
  final int trips;
  final double onTime;

  /// Placeholder: `DriverRating` only carries a `weekKey`, not a month, and
  /// aggregating ratings into calendar months is out of scope here — see the
  /// comment where this list is built.
  final double rating;

  const _MonthStat(this.month, this.trips, this.onTime, this.rating);
}

/// One earned achievement badge.
///
/// **Interim, not the real thing.** The task this models describes
/// achievements "granted dynamically by the backend admin or an AI based on
/// actual driving performance" — no such collection/service exists yet
/// (same "not built yet" state as the Metric Breakdown's satisfaction/
/// compliance/safe-driving scores above). Rather than leave the whole
/// section hardcoded until that exists, [_computeAchievements] derives a
/// small, honest set of these from data this screen already streams for
/// real (trips, ratings) — genuinely earned, just not yet admin/AI-curated.
/// Swap this for a real `List<Achievement>` from a backend once one exists;
/// the empty-state UI below only cares that the list can be empty.
class Achievement {
  final String icon;
  final String label;
  const Achievement(this.icon, this.label);
}

/// Real thresholds against real data (never invented percentages): a
/// verified driver's first trip, a strong average rating over a real
/// sample, a genuinely spotless on-time record, and trip-count milestones.
/// A new/unverified account with `hasTrips == false` always gets `[]` here
/// since every rule below requires at least one real trip.
List<Achievement> _computeAchievements({
  required bool isVerified,
  required List<Trip> completed,
  required double? avgRating,
  required double? onTimePct,
}) {
  if (!isVerified || completed.isEmpty) return const [];

  final achievements = <Achievement>[];
  if (avgRating != null && avgRating >= 4.8) {
    achievements.add(const Achievement('⭐', '5-Star Rated'));
  }
  // Require a real sample before calling a streak "spotless" — a single
  // on-time trip is not a pattern.
  if (onTimePct != null && onTimePct >= 99.9 && completed.length >= 5) {
    achievements.add(const Achievement('🕐', 'Never Late'));
  }
  if (completed.length >= 50) {
    achievements.add(const Achievement('🏆', '50 Trips'));
  } else if (completed.length >= 10) {
    achievements.add(const Achievement('🎯', '10 Trips'));
  } else {
    achievements.add(const Achievement('🚌', 'First Trip'));
  }
  return achievements;
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December', //
];

/// The three most recent calendar months (this one first), with real trip
/// counts and a real on-time rate computed from [trips]. Replaces what used to
/// be three fully hardcoded `_MonthStat` rows for January–March 2026.
List<_MonthStat> _recentMonths(List<Trip> trips) {
  final now = DateTime.now();
  // Illustrative only — there is no monthly rating table, see [_MonthStat].
  const placeholderRatings = [4.9, 4.8, 4.8];

  return List.generate(3, (i) {
    final m = DateTime(now.year, now.month - i, 1);
    final inMonth = trips.where((t) {
      final d = t.startedAt ?? DateTime.tryParse(t.dateKey);
      return d != null && d.year == m.year && d.month == m.month;
    }).toList();
    final completed = inMonth
        .where((t) => t.status == TripStatus.completed)
        .toList();
    final onTime = completed.where((t) => t.onTime == true).length;
    final pct = completed.isEmpty ? 0.0 : onTime / completed.length * 100;
    return _MonthStat(
      '${_monthNames[m.month - 1]} ${m.year}',
      inMonth.length,
      double.parse(pct.toStringAsFixed(1)),
      placeholderRatings[i],
    );
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DriverPerformanceScreen extends StatefulWidget {
  const DriverPerformanceScreen({super.key});

  @override
  State<DriverPerformanceScreen> createState() =>
      _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState extends State<DriverPerformanceScreen> {
  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_rebuild);
    // Needed for the verification gate below (`Driver.isApproved`) -- a
    // driver who gets approved while sitting on this screen should see the
    // placeholder state clear without navigating away and back.
    SessionService.instance.driver.addListener(_rebuild);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_rebuild);
    SessionService.instance.driver.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final uid = SessionService.instance.uid;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withValues(alpha: 0.2),
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
                    const SizedBox(width: 14),
                    Text(
                      AppStrings.t('performance_report'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: uid == null
                    ? Center(
                        child: Text(
                          'Sign in to see your performance report.',
                          style: TextStyle(color: context.textTertiary),
                        ),
                      )
                    : StreamBuilder<List<Trip>>(
                        stream: TripRepository.instance.watchTripsForDriver(
                          uid,
                          limit: 500,
                        ),
                        builder: (context, tripSnap) {
                          final trips = tripSnap.data ?? const <Trip>[];
                          return StreamBuilder<List<DriverRating>>(
                            stream: RatingRepository.instance.watchForDriver(
                              uid,
                            ),
                            builder: (context, ratingSnap) {
                              final ratings =
                                  ratingSnap.data ?? const <DriverRating>[];
                              return _buildBody(context, trips, ratings);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Trip> trips,
    List<DriverRating> ratings,
  ) {
    final completed = trips
        .where((t) => t.status == TripStatus.completed)
        .toList();
    final onTimeCount = completed.where((t) => t.onTime == true).length;
    final onTimePct = completed.isEmpty
        ? null
        : onTimeCount / completed.length * 100;
    final avgRating = ratings.isEmpty
        ? null
        : ratings.map((r) => r.rating).reduce((a, b) => a + b) / ratings.length;

    // New-account gate: a driver whose documents haven't cleared review yet
    // (`Driver.isApproved` -- false while `status` is `pendingVerification`
    // or `suspended`) is never allowed to accept a request, so there is
    // structurally no way for them to have a real trip yet either. Checking
    // both (not just trip count) also covers the moment right after
    // approval, before a first trip exists -- still nothing real to show.
    final driver = SessionService.instance.driver.value;
    final isVerified = driver?.isApproved ?? false;
    final hasTrips = trips.isNotEmpty;
    final hasData = isVerified && hasTrips;
    final achievements = _computeAchievements(
      isVerified: isVerified,
      completed: completed,
      avgRating: avgRating,
      onTimePct: onTimePct,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          // Overall score card
          GlassCard(
            gradient: LinearGradient(
              colors: [
                AppTheme.driverCyan.withValues(alpha: 0.15),
                AppTheme.driverTeal.withValues(alpha: 0.05),
              ],
            ),
            borderColor: AppTheme.driverCyan.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.driverGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    // Placeholder even when `hasData` is true: there is no
                    // composite "overall score" metric anywhere in the app
                    // yet — this would need a real ratings + operations
                    // scoring model, which is out of scope here. Trips/
                    // rating/on-time below are real either way. What *is*
                    // new here is that a driver with nothing real behind
                    // this number no longer sees an invented one.
                    child: Text(
                      hasData ? '96' : 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Moved here from the driver's own profile page --
                // `DriverRatingBar` (`widgets/driver_rating_bar.dart`) is
                // now shown in exactly one place, right under the score
                // circle, rather than duplicated on both screens.
                DriverRatingBar(rating: avgRating, count: ratings.length),
                const SizedBox(height: 12),
                Text(
                  'Overall Score',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  !isVerified
                      ? 'Pending Verification'
                      : !hasTrips
                      ? 'No data available'
                      : 'Excellent Performance',
                  style: TextStyle(
                    color: hasData
                        ? AppTheme.successLight
                        : context.textTertiary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // No separate "Rating" pill here any more -- the
                    // `DriverRatingBar` above already shows the same average,
                    // just with more detail (stars + count). Repeating it as
                    // a pill too would be clutter, not confirmation.
                    _ScorePill('🏆', '${trips.length}', 'Trips'),
                    _ScorePill(
                      '⏱️',
                      onTimePct == null ? '—' : '${onTimePct.round()}%',
                      'On-Time',
                    ),
                    // Placeholder even when `hasData` is true: no
                    // satisfaction-survey data source exists yet. Blank for
                    // a new/unverified driver rather than always-98% either
                    // way.
                    _ScorePill('😊', hasData ? '98%' : '—', 'Satisfaction'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Monthly breakdown
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Performance',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (!hasData)
                  const _EmptyMonthlyState()
                else
                  for (final s in _recentMonths(trips)) _MonthRow(s),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Metric breakdown
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Metric Breakdown',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _MetricBar(
                  label: 'On-Time Arrivals',
                  value: (onTimePct ?? 0) / 100,
                  color: AppTheme.driverCyan,
                ),
                const SizedBox(height: 12),
                // Placeholder metrics below even when `hasData` is true: no
                // survey, compliance-tracking or safe-driving-scoring
                // backend exists yet. Zeroed out (empty/grey bar) for a
                // new/unverified driver instead of always showing the same
                // static values regardless of whether they've ever driven.
                _MetricBar(
                  label: 'Student Satisfaction',
                  value: hasData ? 0.98 : 0.0,
                  color: AppTheme.success,
                ),
                const SizedBox(height: 12),
                _MetricBar(
                  label: 'Route Compliance',
                  value: hasData ? 0.99 : 0.0,
                  color: AppTheme.driverTeal,
                ),
                const SizedBox(height: 12),
                _MetricBar(
                  label: 'Safe Driving Score',
                  value: hasData ? 0.94 : 0.0,
                  color: AppTheme.warningLight,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Achievements — was six hardcoded badges shown unconditionally
          // (a brand-new, unverified driver with zero trips saw the exact
          // same "Top Driver"/"5-Star Week"/etc. as a real veteran). Now
          // maps over the dynamic `achievements` list computed above, which
          // is genuinely empty for such an account.
          SizedBox(
            width: double.infinity,
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (achievements.isEmpty)
                    const _LockedAchievements()
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final a in achievements) _Badge(a.icon, a.label),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final String icon, value, label;
  const _ScorePill(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 10),
        ),
      ],
    );
  }
}

/// Shown instead of `_MonthRow`s for a driver with no verified/real trip
/// history yet -- replaces what used to be three fully hardcoded rows
/// (4.8/4.9 star ratings included) that rendered for every account
/// regardless of whether they had ever driven.
class _EmptyMonthlyState extends StatelessWidget {
  const _EmptyMonthlyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: context.textTertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Complete your first trip to unlock monthly insights.',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final _MonthStat stat;
  const _MonthRow(this.stat);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              stat.month,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              '${stat.trips} trips',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${stat.onTime}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.successLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text(
                  '${stat.rating}',
                  style: const TextStyle(
                    color: AppTheme.warningLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String icon, label;
  const _Badge(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.driverCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.driverCyan.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.driverAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the achievements `Wrap` for a new/unverified driver
/// (or any account that simply hasn't earned one yet) -- a message plus a
/// few grayed-out "locked" silhouettes, so the section reads as "nothing
/// earned so far" rather than a blank space that looks broken.
class _LockedAchievements extends StatelessWidget {
  const _LockedAchievements();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [_LockedBadge(), _LockedBadge(), _LockedBadge()],
        ),
        const SizedBox(height: 12),
        Text(
          'Start driving to unlock your first achievement!',
          style: TextStyle(color: context.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: context.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            'Locked',
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
