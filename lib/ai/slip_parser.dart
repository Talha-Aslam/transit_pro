/// Reads a Pakistani payment screenshot (Easypaisa, JazzCash, NayaPay,
/// SadaPay, Meezan and other bank / Raast receipts) from OCR text.
///
/// Pure Dart — no Flutter, no ML Kit — so every rule is unit tested against
/// text transcribed from real screenshots, OCR noise included.
library;

import 'text_utils.dart';

/// Everything the check could read off a slip, with a 0–1 confidence per
/// field. Nothing here is stored as-is: [SlipCheck] keeps only what a
/// warning needs (last four digits of an account, never the raw text).
class SlipReading {
  /// `easypaisa` / `jazzcash` / `nayapay` / `sadapay` / `meezan` / `bank` /
  /// `unknown`.
  final String provider;

  /// False when the slip says failed / pending; null when it says neither.
  final bool? successful;
  final int? amountPaisa;
  final String? transactionId;

  /// NayaPay shortens long ids with "…" — the prefix is all there is.
  final bool transactionIdTruncated;
  final DateTime? paidAt;
  final String? receiverName;
  final String? receiverAccountLast4;
  final String? senderName;
  final String? senderAccountLast4;

  /// Field name → 0..1. Missing means not read.
  final Map<String, double> confidence;

  /// `ocr`, `gemini` or `ocr+gemini`.
  final String engine;

  const SlipReading({
    this.provider = 'unknown',
    this.successful,
    this.amountPaisa,
    this.transactionId,
    this.transactionIdTruncated = false,
    this.paidAt,
    this.receiverName,
    this.receiverAccountLast4,
    this.senderName,
    this.senderAccountLast4,
    this.confidence = const {},
    this.engine = 'ocr',
  });

  static const empty = SlipReading();

  double conf(String field) => confidence[field] ?? 0;

  /// Nothing worth checking was read.
  bool get isEmpty =>
      amountPaisa == null &&
      transactionId == null &&
      paidAt == null &&
      receiverName == null &&
      receiverAccountLast4 == null;

  /// The amount or the transaction id is missing or doubtful — worth asking
  /// Gemini to read the image.
  bool get needsAi =>
      amountPaisa == null ||
      conf('amount') < 0.6 ||
      transactionId == null ||
      conf('transactionId') < 0.5;

  /// The id under which this transaction is registered in `slip_tids`.
  /// Null when there is no usable id.
  String? get registryKey {
    final tid = transactionId;
    if (tid == null) return null;
    final norm = normalizeId(tid);
    if (norm.length < 4) return null;
    final key = '${provider}_$norm';
    return key.length > 120 ? key.substring(0, 120) : key;
  }

  /// A reading from Gemini's JSON (see the Worker's `slip` schema).
  factory SlipReading.fromAi(Map<String, dynamic> m) {
    String? str(String k) {
      final v = m[k];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
    }

    int? amount;
    final rawAmount = m['amount'];
    if (rawAmount is num && rawAmount > 0) {
      amount = (rawAmount * 100).round();
    } else if (rawAmount is String) {
      amount = parsePaisa(rawAmount.replaceAll(RegExp(r'[^0-9.,]'), ''));
    }
    DateTime? when;
    final rawDate = str('dateTime');
    if (rawDate != null) {
      when = DateTime.tryParse(rawDate) ?? firstDateIn([rawDate]);
    }
    var tid = str('transactionId');
    var truncated = false;
    if (tid != null && RegExp(r'(\.\.\.|…)\s*$').hasMatch(tid)) {
      truncated = true;
      tid = tid.replaceAll(RegExp(r'(\.\.\.|…)\s*$'), '');
    }
    final provider = _providerFromName(str('provider'));
    final ok = m['successful'];
    final receiverName = str('receiverName');
    final receiverLast4 = last4Digits(str('receiverAccount'));
    final senderName = str('senderName');
    return SlipReading(
      provider: provider,
      successful: ok is bool ? ok : null,
      amountPaisa: amount,
      transactionId: tid,
      transactionIdTruncated: truncated,
      paidAt: when,
      receiverName: receiverName,
      receiverAccountLast4: receiverLast4,
      senderName: senderName,
      senderAccountLast4: last4Digits(str('senderAccount')),
      engine: 'gemini',
      confidence: {
        if (provider != 'unknown') 'provider': 0.85,
        if (amount != null) 'amount': 0.85,
        if (tid != null) 'transactionId': truncated ? 0.7 : 0.85,
        if (when != null) 'paidAt': 0.85,
        if (receiverName != null) 'receiverName': 0.85,
        if (receiverLast4 != null) 'receiverAccount': 0.85,
        if (senderName != null) 'senderName': 0.85,
      },
    );
  }

  /// This (OCR) reading with [ai]'s fields taken wherever OCR could not read
  /// a field confidently. Gemini wins those; confident OCR fields stay.
  SlipReading mergedWith(SlipReading ai, {double threshold = 0.75}) {
    var usedAi = false;
    T pick<T>(String field, T mine, T theirs) {
      if (theirs == null) return mine;
      if (mine == null || conf(field) < threshold) {
        usedAi = true;
        return theirs;
      }
      return mine;
    }

    final amount = pick('amount', amountPaisa, ai.amountPaisa);
    final tidFromAi =
        ai.transactionId != null &&
        (transactionId == null || conf('transactionId') < threshold);
    final tid = pick('transactionId', transactionId, ai.transactionId);
    final when = pick('paidAt', paidAt, ai.paidAt);
    final rName = pick('receiverName', receiverName, ai.receiverName);
    final rAcc = pick(
      'receiverAccount',
      receiverAccountLast4,
      ai.receiverAccountLast4,
    );
    final sName = pick('senderName', senderName, ai.senderName);
    final prov = provider == 'unknown' && ai.provider != 'unknown'
        ? ai.provider
        : provider;
    final merged = <String, double>{...confidence};
    for (final e in ai.confidence.entries) {
      if ((merged[e.key] ?? 0) < threshold) merged[e.key] = e.value;
    }
    return SlipReading(
      provider: prov,
      // A failure either reader saw is kept: it is the safer warning.
      successful: successful == false || ai.successful == false
          ? false
          : (successful ?? ai.successful),
      amountPaisa: amount,
      transactionId: tid,
      transactionIdTruncated: tidFromAi
          ? ai.transactionIdTruncated
          : transactionIdTruncated,
      paidAt: when,
      receiverName: rName,
      receiverAccountLast4: rAcc,
      senderName: sName,
      senderAccountLast4: senderAccountLast4 ?? ai.senderAccountLast4,
      confidence: merged,
      engine: isEmpty ? 'gemini' : (usedAi ? 'ocr+gemini' : engine),
    );
  }

  /// Per field, whichever of the two OCR readings is more confident — used
  /// to combine the row-merged and block-order passes over the same image.
  SlipReading bestOf(SlipReading other) {
    T pick<T>(String field, T mine, T theirs) =>
        (mine == null || (theirs != null && other.conf(field) > conf(field)))
        ? theirs
        : mine;
    final merged = <String, double>{...confidence};
    for (final e in other.confidence.entries) {
      if ((merged[e.key] ?? 0) < e.value) merged[e.key] = e.value;
    }
    final otherTid =
        other.transactionId != null &&
        (transactionId == null ||
            other.conf('transactionId') > conf('transactionId'));
    return SlipReading(
      provider: provider == 'unknown' ? other.provider : provider,
      successful: successful == false || other.successful == false
          ? false
          : (successful ?? other.successful),
      amountPaisa: pick('amount', amountPaisa, other.amountPaisa),
      transactionId: pick('transactionId', transactionId, other.transactionId),
      transactionIdTruncated: otherTid
          ? other.transactionIdTruncated
          : transactionIdTruncated,
      paidAt: pick('paidAt', paidAt, other.paidAt),
      receiverName: pick('receiverName', receiverName, other.receiverName),
      receiverAccountLast4: pick(
        'receiverAccount',
        receiverAccountLast4,
        other.receiverAccountLast4,
      ),
      senderName: pick('senderName', senderName, other.senderName),
      senderAccountLast4: senderAccountLast4 ?? other.senderAccountLast4,
      confidence: merged,
      engine: engine,
    );
  }

  @override
  String toString() =>
      'SlipReading($provider, ok=$successful, amount=$amountPaisa, '
      'tid=$transactionId${transactionIdTruncated ? '…' : ''}, at=$paidAt, '
      'to=$receiverName/$receiverAccountLast4, from=$senderName, '
      'conf=$confidence, $engine)';
}

String _providerFromName(String? name) {
  final s = (name ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (s.isEmpty) return 'unknown';
  if (s.contains('nayapay')) return 'nayapay';
  if (s.contains('sadapay')) return 'sadapay';
  if (s.contains('meezan')) return 'meezan';
  if (s.contains('easypaisa') || s.contains('telenor')) return 'easypaisa';
  if (s.contains('jazz') || s.contains('mobilink')) return 'jazzcash';
  if (s.contains('bank') || s.contains('raast') || s.contains('ibft')) {
    return 'bank';
  }
  return 'unknown';
}

// ── The parser ──────────────────────────────────────────────────────────────

class SlipParser {
  SlipParser._();

  static final _feeLine = RegExp(
    r'\b(fee|fees|charges?|tax|commission|discount|cash\s*back|balance)\b',
    caseSensitive: false,
  );

  static final _totalLabel = RegExp(
    r'\b(total\s*amount|amount\s*total|total\s*paid|grand\s*total|total)\b',
    caseSensitive: false,
  );
  static final _amountLabel = RegExp(
    r'\b(amount\s*sent|amount\s*transferred|transfer(?:red)?\s*amount|sent\s*amount|amount\s*paid|paid\s*amount|amount)\b',
    caseSensitive: false,
  );

  static final _failed = RegExp(
    r'\b(failed|failure|unsuccessful|not\s+successful|pending|declined|rejected|reversed|cancell?ed|in\s+process|processing|on\s+hold)\b',
    caseSensitive: false,
  );
  static final _succeeded = RegExp(
    r'\b(successful(?:ly)?|success|completed|money has been sent|sent successfully)\b',
    caseSensitive: false,
  );

  /// Ordered by how much a label can be trusted to name the transaction id.
  static final _tidLabels = <(RegExp, double)>[
    (
      RegExp(
        r'\b(tid|t\.id|transaction\s*id|transaction\s*no\.?|transaction\s*number|transaction\s*#|trans(?:action)?\s*ref(?:erence)?(?:\s*(?:no\.?|number|#))?|trx\s*id|txn\s*id|trx\s*no\.?|txn\s*no\.?|trx\s*#|tran\s*id)(?![a-z])',
        caseSensitive: false,
      ),
      0.95,
    ),
    // "ID#2261..." — Easypaisa. OCR reads the I as l, 1 or |.
    (RegExp(r'(?:^|\s)[1lI|]D\s*#', caseSensitive: false), 0.9),
    (
      RegExp(
        r'\b(reference\s*(?:number|no\.?|#)?(?:\s*\(stan\))?|stan|rrn|ref(?:erence)?\s*id)(?![a-z])',
        caseSensitive: false,
      ),
      0.8,
    ),
    (RegExp(r'\bref(?:\.|erence)?\s*(?:no\.?|#|:)', caseSensitive: false), 0.6),
  ];

  static final _receiverLabels = <(RegExp, double)>[
    (
      RegExp(
        r'\b(destination\s*acc(?:ount|\.)?\s*(?:title|name)|beneficiary\s*(?:name|title)|receiver\s*name|recipient\s*name|to\s*account\s*title)\b',
        caseSensitive: false,
      ),
      0.95,
    ),
    (
      RegExp(
        r'\b(to\s*account|sent\s*to|paid\s*to|beneficiary|receiver|recipient)\b',
        caseSensitive: false,
      ),
      0.9,
    ),
    (RegExp(r'\btransferred\s*to\b', caseSensitive: false), 0.85),
    (RegExp(r'\baccount\s*details\b', caseSensitive: false), 0.8),
  ];

  static final _receiverAccountLabel = RegExp(
    r'\b(destination\s*acc(?:ount|\.)?\s*(?:number|no\.?|#)|beneficiary\s*(?:account|acc\.?)\s*(?:number|no\.?|#)?|to\s*account\s*(?:number|no\.?|#)|receiver\s*account|iban)\b',
    caseSensitive: false,
  );

  static final _senderLabels = RegExp(
    r'\b(source\s*acc(?:ount|\.)?\s*(?:title|name)|from\s*account|sent\s*by|paid\s*by|sender(?:\s*name)?|from)\b',
    caseSensitive: false,
  );
  static final _senderAccountLabel = RegExp(
    r'\b(source\s*acc(?:ount|\.)?\s*(?:number|no\.?|#))\b',
    caseSensitive: false,
  );

  /// Words that are never a person's name on a receipt.
  static const _stopWords = {
    'account',
    'acc',
    'amount',
    'fee',
    'charge',
    'transaction',
    'successful',
    'success',
    'bank',
    'mobile',
    'from',
    'to',
    'sent',
    'total',
    'id',
    'ref',
    'reference',
    'raast',
    'channel',
    'date',
    'time',
    'easypaisa',
    'easy',
    'paisa',
    'jazzcash',
    'jazz',
    'cash',
    'nayapay',
    'sadapay',
    'meezan',
    'mobilink',
    'microfinance',
    'mfb',
    'wallet',
    'transfer',
    'transferred',
    'details',
    'title',
    'number',
    'free',
    'source',
    'destination',
    'funding',
    'message',
    'type',
    'information',
    'additional',
    'service',
    'rs',
    'pkr',
    'tid',
    'stan',
    'beneficiary',
    'add',
    'share',
    'done',
    'receipt',
    'by',
  };

  /// Reads [rawLines] (OCR text, one visual row per line).
  static SlipReading parse(List<String> rawLines) {
    final lines = cleanLines(rawLines.map(fixSplitTimes));
    if (lines.isEmpty) return SlipReading.empty;
    final conf = <String, double>{};
    final text = lines.join('\n');

    // ── Provider ──
    final provider = _provider(lines);
    if (provider != 'unknown') conf['provider'] = 0.8;

    // ── Success ──
    bool? successful;
    if (_failed.hasMatch(text)) {
      successful = false;
    } else if (_succeeded.hasMatch(text)) {
      successful = true;
    }

    // ── Amount ──
    final amount = _amount(lines, provider);
    if (amount != null) conf['amount'] = amount.$2;

    // ── Transaction id ──
    final tid = _transactionId(lines);
    if (tid != null) conf['transactionId'] = tid.$3;

    // ── Date ──
    final dates = findDates(lines);
    FoundDate? when;
    for (final d in dates) {
      if (d.hasTime) {
        when = d;
        break;
      }
    }
    when ??= dates.isEmpty ? null : dates.first;
    if (when != null) conf['paidAt'] = when.hasTime ? 0.9 : 0.7;

    // ── Receiver / sender ──
    final receiver = _party(lines, receiver: true);
    final sender = _party(lines, receiver: false);
    if (receiver.name != null) conf['receiverName'] = receiver.conf;
    if (receiver.last4 != null) conf['receiverAccount'] = receiver.conf;
    if (sender.name != null) conf['senderName'] = sender.conf;

    return SlipReading(
      provider: provider,
      successful: successful,
      amountPaisa: amount?.$1,
      transactionId: tid?.$1,
      transactionIdTruncated: tid?.$2 ?? false,
      paidAt: when?.value,
      receiverName: receiver.name,
      receiverAccountLast4: receiver.last4,
      senderName: sender.name,
      senderAccountLast4: sender.last4,
      confidence: conf,
    );
  }

  static String _provider(List<String> lines) {
    final lower = lines.map((l) => l.toLowerCase()).toList();
    bool any(Pattern p) => lower.any((l) => l.contains(p));
    if (any('nayapay') || any('naya pay')) return 'nayapay';
    if (any('sadapay') || any('sada pay')) return 'sadapay';
    if (any('meezan')) return 'meezan';
    // Easypaisa named as the *sender's* app, not as where the money went.
    final destination = RegExp(
      r'transferred to|destination|to account|sent to',
    );
    if (lower.any(
      (l) =>
          (l.contains('easypaisa') || l.contains('easy paisa')) &&
          !destination.hasMatch(l),
    )) {
      return 'easypaisa';
    }
    if (any('jazzcash') || any('jazz cash') || any('mobilink')) {
      return 'jazzcash';
    }
    if (any('easypaisa') || any('easy paisa') || any('telenor')) {
      return 'easypaisa';
    }
    if (lower.any(
      (l) => RegExp(
        r'\b(bank|hbl|ubl|mcb|alfalah|faysal|askari|allied|ibft|raast|iban)\b',
      ).hasMatch(l),
    )) {
      return 'bank';
    }
    return 'unknown';
  }

  /// The value for a label at [i]: the rest of its line, else the next line.
  static (String, int)? _valueAt(List<String> lines, int i, RegExpMatch m) {
    final rest = restAfter(lines[i], m);
    if (rest.isNotEmpty) return (rest, i);
    if (i + 1 < lines.length) return (lines[i + 1], i + 1);
    return null;
  }

  static int? _moneyIn(String s) {
    final m = moneyPattern.firstMatch(s);
    if (m != null) return parsePaisa(m[1]!);
    final bare = bareAmountPattern.firstMatch(s.trim());
    return bare == null ? null : parsePaisa(bare[1]!);
  }

  /// (paisa, confidence).
  static (int, double)? _amount(List<String> lines, String provider) {
    int? labelled(RegExp label) {
      for (var i = 0; i < lines.length; i++) {
        final m = label.firstMatch(lines[i]);
        if (m == null || _feeLine.hasMatch(lines[i])) continue;
        final rest = restAfter(lines[i], m);
        final inline = rest.isEmpty ? null : _moneyIn(rest);
        if (inline != null) return inline;
        if (rest.isNotEmpty && RegExp(r'[0-9]').hasMatch(rest)) continue;
        if (i + 1 < lines.length && !_feeLine.hasMatch(lines[i + 1])) {
          final next = _moneyIn(lines[i + 1]);
          if (next != null) return next;
        }
      }
      return null;
    }

    final total = labelled(_totalLabel);
    if (total != null) return (total, 0.95);
    final sent = labelled(_amountLabel);
    if (sent != null) return (sent, 0.9);

    // Unlabelled figures — the big headline amount on most apps.
    final found = <(int, String)>[];
    for (final line in lines) {
      if (_feeLine.hasMatch(line)) continue;
      for (final m in moneyPattern.allMatches(line)) {
        final v = parsePaisa(m[1]!);
        if (v != null) found.add((v, m[1]!));
      }
    }
    if (found.isEmpty) return null;
    final distinct = found.map((f) => f.$1).toSet();
    final first = found.first;
    if (distinct.length > 1) return (first.$1, 0.35);
    // JazzCash draws ".00" as superscript, which OCR reads as part of the
    // number: "Rs. 1.00" becomes "Rs. 100". A round, decimal-less headline
    // on JazzCash can not be trusted.
    final raw = first.$2;
    if (provider == 'jazzcash' && !raw.contains('.') && first.$1 % 10000 == 0) {
      return (first.$1, 0.4);
    }
    if (RegExp(r'\s[0-9]{2}$').hasMatch(raw)) return (first.$1, 0.5);
    return (first.$1, 0.7);
  }

  /// (id, truncated, confidence).
  static (String, bool, double)? _transactionId(List<String> lines) {
    for (final (label, weight) in _tidLabels) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (RegExp(r'message', caseSensitive: false).hasMatch(line)) continue;
        final m = label.firstMatch(line);
        if (m == null) continue;
        final candidates = [
          restAfter(line, m),
          if (i + 1 < lines.length) lines[i + 1],
        ];
        for (final c in candidates) {
          final id = _idToken(c);
          if (id != null) {
            return (id.$1, id.$2, id.$2 ? weight - 0.15 : weight);
          }
        }
      }
    }
    return null;
  }

  /// The id in a label's value: `446804416088`, `226l5557344` (→ 1),
  /// `6aff5db31783980fb91ca...`, `4468 0441 6088`.
  static (String, bool)? _idToken(String value) {
    var v = value.trim();
    if (v.isEmpty) return null;
    final truncated = RegExp(r'(\.\.\.|…)').hasMatch(v);
    v = v.replaceAll(RegExp(r'(\.\.\.|…).*$'), '');
    // Digit groups separated by single spaces are one number.
    v = v.replaceAllMapped(RegExp(r'(?<=\d) (?=\d{3,})'), (_) => '');
    for (final raw in v.split(RegExp(r'[\s:#|,]+'))) {
      final token = fixDigitLookalikes(
        raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
      );
      if (token.length < 5 || token.length > 40) continue;
      final digits = RegExp(r'\d').allMatches(token).length;
      if (digits < 3) continue;
      // A phone or account number is not an id when it is labelled as one,
      // but a date or amount never is.
      if (RegExp(r'^(rs|pkr)', caseSensitive: false).hasMatch(token)) continue;
      return (token, truncated);
    }
    return null;
  }

  static ({String? name, String? last4, double conf}) _party(
    List<String> lines, {
    required bool receiver,
  }) {
    String? name;
    String? last4;
    double best = 0;

    bool isOtherSide(String line) => receiver
        ? _senderLabels.hasMatch(line)
        : _receiverLabels.any((l) => l.$1.hasMatch(line));

    bool isAccountish(String line) {
      if (moneyPattern.hasMatch(line) || findDates([line]).isNotEmpty) {
        return false;
      }
      return last4Digits(line) != null;
    }

    final labels = receiver ? _receiverLabels : [(_senderLabels, 0.9)];
    for (final (label, weight) in labels) {
      for (var i = 0; i < lines.length; i++) {
        final m = label.firstMatch(lines[i]);
        if (m == null) continue;
        // "Sent by HUMAIRA" — the sender label must not be read as a
        // receiver one, and vice versa.
        if (receiver && _senderLabels.firstMatch(lines[i])?.start == m.start) {
          continue;
        }
        String? foundName;
        String? foundLast4;
        final rest = restAfter(lines[i], m);
        // An account number on the label's own line: "To Account: 0310xxx3717".
        if (rest.isNotEmpty) {
          if (looksLikeName(rest, stopWords: _stopWords)) {
            foundName = rest;
          } else if (isAccountish(rest)) {
            foundLast4 = last4Digits(rest);
          }
        }
        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          final l = lines[j];
          if (isOtherSide(l)) break;
          if (j > i + 1 &&
              (receiver
                  ? _receiverLabels.any((r) => r.$1.hasMatch(l))
                  : _senderLabels.hasMatch(l))) {
            break;
          }
          if (foundName == null && looksLikeName(l, stopWords: _stopWords)) {
            foundName = l;
            continue;
          }
          if (foundLast4 == null && isAccountish(l)) {
            foundLast4 = last4Digits(l);
          }
          if (foundName != null && foundLast4 != null) break;
        }
        // JazzCash centres a lone "From" between the sender's name above
        // and their account below.
        if (!receiver &&
            foundName == null &&
            rest.isEmpty &&
            i > 0 &&
            looksLikeName(lines[i - 1], stopWords: _stopWords)) {
          foundName = lines[i - 1];
        }
        if (foundName == null && foundLast4 == null) continue;
        if (name == null && foundName != null) {
          name = foundName;
          if (weight > best) best = weight;
        }
        if (last4 == null && foundLast4 != null) {
          last4 = foundLast4;
          if (weight > best) best = weight;
        }
      }
      if (name != null && last4 != null) break;
    }

    // An explicitly labelled account number wins over a nearby guess.
    final accountLabel = receiver ? _receiverAccountLabel : _senderAccountLabel;
    for (var i = 0; i < lines.length; i++) {
      final m = accountLabel.firstMatch(lines[i]);
      if (m == null) continue;
      final v = _valueAt(lines, i, m);
      final l4 = v == null ? null : last4Digits(v.$1);
      if (l4 != null) {
        last4 = l4;
        best = best < 0.95 ? 0.95 : best;
        break;
      }
    }
    if (name != null) name = _titleCase(name);
    return (name: name, last4: last4, conf: best);
  }

  static String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
