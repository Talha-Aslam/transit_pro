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
/// The `en.pk#holiday` calendar is already country-restricted to Pakistan
/// (there is no further `country=PK`-style query parameter on the Calendar
/// API — the restriction lives in *which calendar* you read, not in a
/// filter param), but Google's Pakistan calendar mixes in every regionally
/// observed festival for Pakistan's religious minorities (Janmashtami,
/// Durga Puja, Dussehra, Diwali, Holi, …) alongside official national
/// holidays and Islamic observances. The API has no "official/national
/// only" or "Islamic calendar only" flag, so [_isApprovedHoliday] filters
/// the response locally against a curated allowlist after fetching.
///
/// Replaces `parent_schedule.dart`'s old static 3-entry `_holidays` list.
class HolidayService {
  HolidayService._();
  static final HolidayService instance = HolidayService._();

  static const _calendarId = 'en.pk%23holiday%40group.v.calendar.google.com';

  /// Fetched from the API before filtering — well above the largest
  /// `maxResults` any caller asks for, since a chunk of Google's raw feed
  /// (the regional/minority festivals) gets dropped by [_isApprovedHoliday]
  /// and there still needs to be enough left over to fill the caller's
  /// requested count.
  static const _rawFetchLimit = 30;

  /// Official Pakistani national holidays and Islamic observances,
  /// matched case-insensitively as a substring of the calendar's event
  /// name — Google's summaries vary in exact wording/spelling year to year
  /// ("Eid-ul-Fitr" vs "Eid al-Fitr", "Ashura" vs "Youm-e-Ashura"), so this
  /// is an allowlist of keywords, not exact titles. An allowlist (not a
  /// blocklist of the unwanted festivals) is deliberate: it fails closed —
  /// an unrecognised entry is dropped rather than shown, so a new regional
  /// festival Google adds later can't slip through unnoticed.
  static const _approvedKeywords = [
    // National holidays
    'kashmir solidarity',
    'pakistan day',
    'labour day',
    'may day',
    'independence day',
    'defence day',
    'defense day',
    'iqbal day',
    'quaid-e-azam',
    "quaid's birthday",
    'christmas', // shares 25 Dec with Quaid-e-Azam Day; kept, official gazetted holiday
    // Islamic observances
    'eid', // covers Eid-ul-Fitr / Eid al-Fitr / Eid-ul-Azha / Eid al-Adha
    'ashura',
    'muharram',
    'milad',
    'mawlid',
    'eid milad-un-nabi',
    'shab-e-meraj',
    'shab-e-barat',
    'giarhwin',
    'gyarhwin',
    'giyarhwin',
    'ramadan',
    'ramazan',
    'chaand raat',
  ];

  /// True if [name] names an official Pakistani national holiday or an
  /// Islamic observance — see [_approvedKeywords]. Public (not private) so
  /// this can be exercised directly against real calendar summaries, e.g.
  /// in a test, without going through the network call.
  static bool isApprovedHoliday(String name) {
    final lower = name.toLowerCase();
    return _approvedKeywords.any(lower.contains);
  }

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
      return cached.take(maxResults).toList();
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
              'maxResults': _rawFetchLimit.toString(),
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
        if (!isApprovedHoliday(summary)) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        holidays.add(Holiday(name: summary, date: date));
      }

      _cache = holidays;
      _cachedAt = DateTime.now();
      return holidays.take(maxResults).toList();
    } catch (_) {
      return const [];
    }
  }
}
