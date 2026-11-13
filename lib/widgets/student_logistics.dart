import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_data_service.dart' show kWeekdayKeys;
import '../app/navigation_launcher.dart';
import '../app/round_display.dart';
import '../app/weekly_times.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

const _kDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Everything a driver needs to carry one student, read live off their
/// record: where they are collected and set down, their timings today (and
/// the rest of the week on a tap), and who to call.
///
/// Used where a driver decides on a request and where they look up a
/// booked student, so both show the same thing.
class StudentLogistics extends StatelessWidget {
  final Student student;
  final Color accent;
  const StudentLogistics({
    super.key,
    required this.student,
    this.accent = AppTheme.driverCyan,
  });

  @override
  Widget build(BuildContext context) {
    final today = WeeklyTimes.on(student);
    final todayName = DateTime.now().weekday == DateTime.sunday
        ? 'Sunday'
        : _kDayNames[DateTime.now().weekday - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '📍 Where',
          child: Column(
            children: [
              _PlaceRow(
                label: 'Pickup (home)',
                point: student.pickupLocation,
                accent: accent,
              ),
              _PlaceRow(
                label: student.school.isEmpty
                    ? 'Drop-off (institute)'
                    : 'Drop-off · ${student.school}',
                point: student.dropoffLocation,
                accent: accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: '🕒 Today ($todayName)',
          trailing: TextButton(
            onPressed: () => _showWeek(context),
            child: Text('Full week', style: TextStyle(color: accent)),
          ),
          child: today.isEmpty
              ? Text(
                  'No timings set for today.',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                )
              : _TimesLine(times: today),
        ),
        const SizedBox(height: 12),
        _Section(
          title: '📞 Contacts',
          child: Column(
            children: [
              if (student.guardianPhone.isNotEmpty)
                _ContactRow(
                  name: student.guardianName.isEmpty
                      ? 'Family'
                      : student.guardianName,
                  relation: student.parentId.isEmpty ? 'Student' : 'Parent',
                  phone: student.guardianPhone,
                  accent: accent,
                ),
              for (final c in student.emergencyContacts)
                _ContactRow(
                  name: c.name,
                  relation: c.relation,
                  phone: c.phone,
                  accent: accent,
                ),
              if (student.guardianPhone.isEmpty &&
                  student.emergencyContacts.isEmpty)
                Text(
                  'The family has not added a phone number or emergency '
                  'contacts yet.',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showWeek(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ctx.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${student.name}'s week",
              style: TextStyle(
                color: ctx.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < kWeekdayKeys.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        _kDayNames[i],
                        style: TextStyle(
                          color: ctx.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: () {
                        // Monday is weekday 1; build a date on that weekday.
                        final now = DateTime.now();
                        final day = now.add(
                          Duration(days: i + 1 - now.weekday),
                        );
                        final t = WeeklyTimes.on(student, day);
                        return t.isEmpty
                            ? Text(
                                'Not set',
                                style: TextStyle(color: ctx.textTertiary),
                              )
                            : _TimesLine(times: t);
                      }(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      enableBlur: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _TimesLine extends StatelessWidget {
  final WeeklyTimes times;
  const _TimesLine({required this.times});

  @override
  Widget build(BuildContext context) {
    String span(String a, String b) {
      final from = clock12(a);
      final to = clock12(b);
      if (from.isEmpty && to.isEmpty) return '';
      return '${from.isEmpty ? '—' : from} – ${to.isEmpty ? '—' : to}';
    }

    final school = span(times.schoolStartAt, times.schoolEndAt);
    final van = span(times.pickupAt, times.dropoffAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (school.isNotEmpty)
          Text(
            'Institute: $school',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        if (van.isNotEmpty)
          Text(
            'Pickup / drop-off asked: $van',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final String label;
  final GeoCoord? point;
  final Color accent;
  const _PlaceRow({
    required this.label,
    required this.point,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final at = point;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  at == null
                      ? 'No pin set'
                      : '${at.lat.toStringAsFixed(5)}, ${at.lng.toStringAsFixed(5)}',
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (at != null)
            TextButton.icon(
              onPressed: () => NavigationLauncher.navigateTo(at),
              icon: Icon(Icons.map_rounded, size: 16, color: accent),
              label: Text('Map', style: TextStyle(color: accent)),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String name;
  final String relation;
  final String phone;
  final Color accent;
  const _ContactRow({
    required this.name,
    required this.relation,
    required this.phone,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relation.isEmpty ? name : '$name · $relation',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  phone,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
            icon: Icon(Icons.call_rounded, color: accent),
            tooltip: 'Call',
          ),
        ],
      ),
    );
  }
}
