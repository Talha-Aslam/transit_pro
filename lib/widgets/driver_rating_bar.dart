import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A driver's average rating: 5 stars, the numeric average, and a trip/
/// rating count -- or a "No ratings yet" empty state for an account with
/// none. Shared between `driver_profile.dart` (where this lived inline
/// until it was extracted here) and `driver_performance_screen.dart`.
///
/// [rating] null or [count] `0` renders the empty state: a dash instead of
/// a number and every star shown as empty, rather than a misleading
/// half-filled bar for data that doesn't exist.
class DriverRatingBar extends StatelessWidget {
  final double? rating;
  final int count;
  final MainAxisAlignment alignment;

  /// Color for filled stars and the numeric average. Defaults to
  /// [AppTheme.warningLight] (the amber this app already uses for ratings
  /// elsewhere); pass a different color for a widget sitting on its own
  /// colored background, e.g. the profile header's gradient.
  final Color? filledColor;

  /// Color for empty stars and the count/empty-state text. Defaults to
  /// `context.textTertiary`.
  final Color? emptyColor;

  const DriverRatingBar({
    super.key,
    required this.rating,
    required this.count,
    this.alignment = MainAxisAlignment.center,
    this.filledColor,
    this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    final filled = filledColor ?? AppTheme.warningLight;
    final empty = emptyColor ?? context.textTertiary;

    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Text(
              '⭐',
              style: TextStyle(
                fontSize: 16,
                color: i < (rating ?? 0).floor() ? filled : empty,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          rating == null ? '—' : rating!.toStringAsFixed(1),
          style: TextStyle(
            color: filled,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          count == 0
              ? 'No ratings yet'
              : '($count rating${count == 1 ? '' : 's'})',
          style: TextStyle(color: empty, fontSize: 12),
        ),
      ],
    );
  }
}
