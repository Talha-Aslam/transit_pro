import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:transit_core/transit_core.dart';

/// One upcoming Pakistani public holiday.
class Holiday {
  final String name;
  final DateTime date;
  const Holiday({required this.name, required this.date});
}

/// Real upcoming Pakistan holidays from Google's own public holiday
/// calendar (`en.pk#holiday@group.v.calendar.google.com`), read via the
/// Calendar API v3 with a restricted, read-only API key — no OAuth, no user
/// data. Google keeps this calendar current, including the Islamic dates
/// (Eid, etc.) that shift every year on the lunar calendar, which a
/// hand-curated list in this app would otherwise need re-editing for
/// annually.
///
/// Replaces `parent_schedule.dart`'s old static 3-entry `_holidays` list.
class HolidayService {
  HolidayService._();
  static final HolidayService instance = HolidayService._();

  static const _calendarId = 'en.pk%23holiday%40group.v.calendar.google.com';

  List<Holiday>? _cache;
  DateTime? _cachedAt;

  /// Cached for the session (not just per-build) — this is called from a
  /// widget's `build()`, and refetching over the network on every rebuild
  /// would be wasteful for data that only changes once a day at most.
  Future<List<Holiday>> upcomingPakistanHolidays({int maxResults = 5}) async {
    if (!AppConfig.hasGoogleCalendar) return const [];

    final cached = _cache;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(hours: 6)) {
      return cached;
    }

    try {
      final now = DateTime.now();
      final uri =
          Uri.parse(
            'https://www.googleapis.com/calendar/v3/calendars/$_calendarId/events',
          ).replace(
            queryParameters: {
              'key': AppConfig.googleCalendarApiKey,
              'timeMin': now.toUtc().toIso8601String(),
              'maxResults': maxResults.toString(),
              'singleEvents': 'true',
              'orderBy': 'startTime',
            },
          );
      final response = await http.get(uri);
      if (response.statusCode != 200) return const [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List?;
      if (items == null) return const [];

      final holidays = <Holiday>[];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        final summary = m['summary'] as String?;
        final start = m['start'] as Map<String, dynamic>?;
        final dateStr =
            start?['date'] as String? ?? start?['dateTime'] as String?;
        if (summary == null || dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        holidays.add(Holiday(name: summary, date: date));
      }

      _cache = holidays;
      _cachedAt = DateTime.now();
      return holidays;
    } catch (_) {
      return const [];
    }
  }
}
