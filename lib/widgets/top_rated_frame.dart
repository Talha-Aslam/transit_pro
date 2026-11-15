import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../data/rating_repository.dart';

/// A gold ring and a "Top rated" ribbon around a highly-rated driver's photo.
///
/// Shown to families choosing a driver and on the driver's own profile, so a
/// consistently good record is visible where trust is decided. Renders
/// [child] unchanged until the driver meets [DriverRatingSummary.isTopRated].
class TopRatedFrame extends StatelessWidget {
  final String driverId;
  final Widget child;

  /// Corner radius of [child], so the ring follows its shape.
  final double radius;

  const TopRatedFrame({
    super.key,
    required this.driverId,
    required this.child,
    this.radius = 999,
  });

  static const _gold = [
    Color(0xFFFFD54F),
    Color(0xFFFFA000),
    Color(0xFFFFE082),
  ];

  @override
  Widget build(BuildContext context) {
    if (driverId.trim().isEmpty) return child;
    return FutureBuilder<DriverRatingSummary>(
      future: RatingRepository.instance.summaryFor(driverId),
      builder: (context, snap) {
        final top = snap.data?.isTopRated ?? false;
        if (!top) return child;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: const SweepGradient(
                  colors: [..._gold, Color(0xFFFFD54F)],
                ),
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFA000).withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: child,
            ),
            Positioned(
              bottom: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _gold),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '★ Top rated',
                  style: TextStyle(
                    color: Color(0xFF4E3400),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A driver's rating as `4.7 (12)`, or `New`, from their ratings.
class DriverRatingText extends StatelessWidget {
  final String driverId;
  final TextStyle? style;
  final String Function(DriverRatingSummary s)? format;

  const DriverRatingText({
    super.key,
    required this.driverId,
    this.style,
    this.format,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<DriverRatingSummary>(
    future: RatingRepository.instance.summaryFor(driverId),
    builder: (context, snap) {
      final s = snap.data ?? const DriverRatingSummary();
      return Text(format?.call(s) ?? s.label, style: style);
    },
  );
}
