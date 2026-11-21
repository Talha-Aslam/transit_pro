/// Pure-Dart helpers shared by the slip and document parsers.
///
/// No Flutter imports: everything here is exercised by plain unit tests with
/// text transcribed from real screenshots, OCR noise included.
library;

import 'dart:math' as math;

// ── Lines ───────────────────────────────────────────────────────────────────

/// Trims, collapses whitespace and drops empty lines.
List<String> cleanLines(Iterable<String> raw) => [
  for (final l in raw)
    if (l.trim().isNotEmpty) l.replaceAll(RegExp(r'\s+'), ' ').trim(),
];

/// OCR splits a time like "2:15" into "2:1 5". Put it back together, before
/// any date parsing sees it.
String fixSplitTimes(String s) => s.replaceAllMapped(
  RegExp(r'(\d{1,2})\s*:\s*(\d)\s+(\d)(?!\d)'),
  (m) => '${m[1]}:${m[2]}${m[3]}',
);

/// What follows [label] on [line], minus separators; empty when nothing.
String restAfter(String line, RegExpMatch label) =>
    line.substring(label.end).replaceFirst(RegExp(r'^[\s:#\-–|.]+'), '').trim();

// ── Digits & ids ────────────────────────────────────────────────────────────

/// In a token that is mostly digits, OCR's favourite swaps (`l`/`I`/`|` for
/// 1, `O`/`o` for 0) are undone. Hex ids keep their letters: none of the
/// swapped characters are hex digits.
String fixDigitLookalikes(String token) {
  final digits = RegExp(r'\d').allMatches(token).length;
  if (token.isEmpty || digits / token.length < 0.6) return token;
  return token.replaceAll(RegExp('[lI|]'), '1').replaceAll(RegExp('[Oo]'), '0');
}

/// The last four digits of an account-like value: `03151929161`,
/// `0310xxx3717`, `●●●●3717`, `MFB-3717`, `PK36MEZN0001234567890123`.
/// Null when it carries fewer than four digits in a row.
String? last4Digits(String? value) {
  if (value == null) return null;
  final fixed = value.split(RegExp(r'\s+')).map(fixDigitLookalikes).join(' ');
  final runs = RegExp(r'\d{4,}').allMatches(fixed).toList();
  if (runs.isEmpty) return null;
  final last = runs.last[0]!;
  return last.substring(last.length - 4);
}

/// Upper-case letters and digits only — the comparable form of an id.
String normalizeId(String s) =>
    s.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

// ── Money ───────────────────────────────────────────────────────────────────

/// `Rs.1000.00`, `Rs. 1`, `PKR 10`, `Rs 1,000`, `Rs. 1 00` (a superscript
/// `.00` read as a separate group).
final moneyPattern = RegExp(
  r'\b(?:rs|pkr|rupees)\b\.?\s*[:.]?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?(?:\s[0-9]{2}(?![0-9,.]))?)',
  caseSensitive: false,
);

/// A bare figure on its own: `1000.00`, `1,000`.
final bareAmountPattern = RegExp(r'^([0-9][0-9,]*(?:\.[0-9]{1,2})?)$');

/// [text] in paisa, or null. Handles `1,000`, `1000.00`, `1 00` (= 1.00).
int? parsePaisa(String text) {
  var t = text.trim();
  final split = RegExp(r'^([0-9][0-9,]*)\s([0-9]{2})$').firstMatch(t);
  if (split != null) t = '${split[1]}.${split[2]}';
  t = t.replaceAll(',', '');
  final value = double.tryParse(t);
  if (value == null || value <= 0 || value > 10000000) return null;
  return (value * 100).round();
}

// ── Dates ───────────────────────────────────────────────────────────────────

const _monthNames = {
  'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3, //
  'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
  'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9, 'oct': 10,
  'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
};

int? monthFromName(String s) => _monthNames[s.toLowerCase()];

class FoundDate {
  final DateTime value;
  final bool hasTime;

  /// Index of the line it was found on.
  final int line;
  const FoundDate(this.value, this.hasTime, this.line);
}

final _dmyName = RegExp(
  r'\b(\d{1,2})(?:st|nd|rd|th)?[\s\-/.,]+([A-Za-z]{3,9})\.?[\s\-/.,]+(\d{4})\b',
);
final _mdyName = RegExp(
  r'\b([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
);
final _dmyNum = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b');
final _ymdNum = RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b');
final _timeAfter = RegExp(
  r'^\s*(?:at|\||,|-|–)?\s*(\d{1,2})\s*[:.]\s*(\d{2})(?:\s*[:.]\s*\d{2})?\s*([AaPp])?\.?\s*(?:[Mm]\.?)?',
);

DateTime? _date(int y, int m, int d) {
  if (y < 100) y += 2000;
  if (y < 1950 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  // Rejects 31 Feb and friends, which DateTime would roll over.
  return dt.month == m ? dt : null;
}

/// Every date on every line, in reading order, each with the time that
/// directly follows it when there is one.
List<FoundDate> findDates(List<String> lines) {
  final out = <FoundDate>[];
  for (var i = 0; i < lines.length; i++) {
    final line = fixSplitTimes(lines[i]);
    final taken = <(int, int)>[];
    bool overlaps(RegExpMatch m) =>
        taken.any((t) => m.start < t.$2 && m.end > t.$1);

    void add(RegExpMatch m, DateTime? d) {
      if (d == null || overlaps(m)) return;
      taken.add((m.start, m.end));
      final t = _timeAfter.firstMatch(line.substring(m.end));
      if (t != null) {
        var h = int.parse(t[1]!);
        final min = int.parse(t[2]!);
        final ap = t[3]?.toLowerCase();
        if (ap == 'p' && h < 12) h += 12;
        if (ap == 'a' && h == 12) h = 0;
        if (h < 24 && min < 60) {
          out.add(FoundDate(DateTime(d.year, d.month, d.day, h, min), true, i));
          return;
        }
      }
      out.add(FoundDate(d, false, i));
    }

    for (final m in _dmyName.allMatches(line)) {
      final mo = monthFromName(m[2]!);
      if (mo != null) add(m, _date(int.parse(m[3]!), mo, int.parse(m[1]!)));
    }
    for (final m in _mdyName.allMatches(line)) {
      final mo = monthFromName(m[1]!);
      if (mo != null) add(m, _date(int.parse(m[3]!), mo, int.parse(m[2]!)));
    }
    for (final m in _ymdNum.allMatches(line)) {
      add(m, _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)));
    }
    // Day first: Pakistani documents and banks write 20/11/2026.
    for (final m in _dmyNum.allMatches(line)) {
      add(m, _date(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!)));
    }
  }
  return out;
}

/// The first date on [line] (with [fallbackLines] tried after it).
DateTime? firstDateIn(List<String> lines) {
  final found = findDates(lines);
  return found.isEmpty ? null : found.first.value;
}

// ── Names ───────────────────────────────────────────────────────────────────

/// Words that say nothing about who someone is.
const _honorifics = {
  'muhammad', 'mohammad', 'muhammed', 'mohammed', 'mohamad', 'mohd', 'md', //
  'syed', 'sayed', 'mr', 'mrs', 'ms', 'miss', 'dr', 'engr', 'hafiz', 'haji',
};

List<String> nameTokens(String? s) => (s ?? '')
    .toLowerCase()
    .replaceAll(RegExp('[^a-z ]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.length > 1 && !_honorifics.contains(t))
    .toList();

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      cur[j + 1] = math.min(
        math.min(cur[j] + 1, prev[j + 1] + 1),
        prev[j] + cost,
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

double _tokenSim(String a, String b) =>
    1 - _levenshtein(a, b) / math.max(a.length, b.length);

/// 0–100: how much of two names agree, word by word, tolerant of an OCR
/// letter or two and of a missing "Muhammad".
int nameMatchPercent(String? a, String? b) {
  final ta = nameTokens(a);
  final tb = nameTokens(b);
  if (ta.isEmpty || tb.isEmpty) return 0;
  final short = ta.length <= tb.length ? ta : tb;
  final long = identical(short, ta) ? tb : ta;
  final used = <int>{};
  var score = 0.0;
  for (final s in short) {
    var best = 0.0;
    var bestIdx = -1;
    for (var j = 0; j < long.length; j++) {
      if (used.contains(j)) continue;
      final sim = _tokenSim(s, long[j]);
      if (sim > best) {
        best = sim;
        bestIdx = j;
      }
    }
    if (bestIdx >= 0 && best >= 0.6) {
      used.add(bestIdx);
      score += best;
    }
  }
  return (100 * score / long.length).round().clamp(0, 100);
}

/// Whether two names are plausibly the same person: every word of the
/// shorter name appears (allowing an OCR slip) in the longer one. A single
/// short word ("Ali") is not enough on its own.
bool namesMatch(String? a, String? b) {
  final ta = nameTokens(a);
  final tb = nameTokens(b);
  if (ta.isEmpty || tb.isEmpty) return false;
  final short = ta.length <= tb.length ? ta : tb;
  final long = identical(short, ta) ? tb : ta;
  if (short.length == 1 && short.first.length < 4) return false;
  final used = <int>{};
  for (final s in short) {
    var hit = -1;
    for (var j = 0; j < long.length; j++) {
      if (!used.contains(j) && _tokenSim(s, long[j]) >= 0.8) {
        hit = j;
        break;
      }
    }
    if (hit < 0) return false;
    used.add(hit);
  }
  return true;
}

/// Looks like a person's name: letters, spaces and a few marks, no digits.
bool looksLikeName(String s, {Set<String> stopWords = const {}}) {
  final t = s.trim();
  if (t.length < 3 || t.length > 45) return false;
  if (!RegExp(r"^[A-Za-z][A-Za-z .'\-]+$").hasMatch(t)) return false;
  final words = t.toLowerCase().split(RegExp(r'[\s.\-]+'));
  return !words.any(stopWords.contains);
}
