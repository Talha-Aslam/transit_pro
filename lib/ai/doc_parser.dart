/// Reads a Pakistani (Punjab) driving licence or vehicle registration card
/// from OCR text, and checks it against the driver's profile.
///
/// Pure Dart — unit tested with text transcribed from real cards. Lines are
/// in OCR block order (a label followed by its value), the way ML Kit reads
/// a card whose fields sit in columns.
library;

import 'text_utils.dart';

/// What was read off a licence or registration card. [fields] uses the
/// `DocCheck.fieldLabels` keys and holds only non-sensitive values (a CNIC
/// as its last four digits).
/// `DocumentType.drivingLicense.name` / `.vehicleRegistration.name`, spelled
/// out so this file needs no Flutter import.
const docTypeLicense = 'drivingLicense';
const docTypeRegistration = 'vehicleRegistration';

class DocReading {
  /// `DocumentType` name: [docTypeLicense] or [docTypeRegistration].
  final String docType;
  final Map<String, String> fields;
  final DateTime? expiryDate;
  final DateTime? issueDate;

  /// Licence categories, normalised: `M/CYCLE`, `M/CAR`, `LTV`, `HTV`, `PSV`…
  final List<String> categories;

  /// Whether the text looks like the kind of document it should be.
  final bool looksRight;

  /// Anything at all was read.
  final bool hasText;
  final String engine;

  const DocReading({
    required this.docType,
    this.fields = const {},
    this.expiryDate,
    this.issueDate,
    this.categories = const [],
    this.looksRight = false,
    this.hasText = false,
    this.engine = 'ocr',
  });

  bool get isLicense => docType == docTypeLicense;

  /// The fields a check depends on are missing — worth asking Gemini.
  bool get needsAi {
    if (!looksRight) return true;
    if (isLicense) return fields['name'] == null || expiryDate == null;
    return fields['seatingCapacity'] == null &&
        fields['bodyType'] == null &&
        fields['registrationNumber'] == null &&
        fields['ownerName'] == null;
  }

  /// Gemini's JSON (see the Worker's `license` / `registration` schemas).
  factory DocReading.fromAi(String docType, Map<String, dynamic> m) {
    String? str(String k) {
      final v = m[k];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
    }

    DateTime? date(String k) {
      final s = str(k);
      if (s == null) return null;
      return DateTime.tryParse(s) ?? firstDateIn([s]);
    }

    final fields = <String, String>{};
    void put(String key, String? value) {
      if (value != null) fields[key] = value;
    }

    if (docType == docTypeLicense) {
      put('name', str('name'));
      put('fatherName', str('fatherName'));
      final cnic = last4Digits(str('cnic'));
      put('cnicLast4', cnic);
      put(
        'licenseNumber',
        _safeLicenceNumber(str('licenseNumber'), str('cnic')),
      );
      final issue = date('issueDate');
      final expiry = date('expiryDate');
      if (issue != null) fields['issueDate'] = _iso(issue);
      if (expiry != null) fields['expiryDate'] = _iso(expiry);
      final cats = <String>{
        for (final c
            in (m['categories'] is List ? m['categories'] as List : const []))
          ...DocParser.categoriesIn(c.toString()),
      }.toList();
      if (cats.isNotEmpty) fields['categories'] = cats.join(', ');
      return DocReading(
        docType: docType,
        fields: fields,
        expiryDate: expiry,
        issueDate: issue,
        categories: cats,
        looksRight: m['isDrivingLicense'] != false,
        hasText: true,
        engine: 'gemini',
      );
    }
    put('registrationNumber', _cleanPlate(str('registrationNumber')));
    put('make', str('make'));
    put('makerName', str('makerName'));
    put('bodyType', str('bodyType'));
    final seats = m['seatingCapacity'];
    if (seats is num && seats > 0) {
      fields['seatingCapacity'] = seats.round().toString();
    } else if (seats is String && int.tryParse(seats.trim()) != null) {
      fields['seatingCapacity'] = int.parse(seats.trim()).toString();
    }
    final year = m['yearOfManufacture'];
    if (year != null && RegExp(r'^\d{4}$').hasMatch(year.toString().trim())) {
      fields['yearOfManufacture'] = year.toString().trim();
    }
    put('colour', str('colour'));
    put('ownerName', str('ownerName'));
    return DocReading(
      docType: docType,
      fields: fields,
      looksRight: m['isVehicleRegistration'] != false,
      hasText: true,
      engine: 'gemini',
    );
  }

  /// This (OCR) reading with any field it lacks taken from [ai]. With
  /// [fromAi] false, [ai] is a second OCR pass and the engine stays `ocr`.
  DocReading mergedWith(DocReading ai, {bool fromAi = true}) {
    final merged = {...fields};
    var used = false;
    for (final e in ai.fields.entries) {
      if (!merged.containsKey(e.key)) {
        merged[e.key] = e.value;
        used = true;
      }
    }
    final cats = categories.isNotEmpty ? categories : ai.categories;
    if (categories.isEmpty && ai.categories.isNotEmpty) used = true;
    if (expiryDate == null && ai.expiryDate != null) used = true;
    return DocReading(
      docType: docType,
      fields: merged,
      expiryDate: expiryDate ?? ai.expiryDate,
      issueDate: issueDate ?? ai.issueDate,
      categories: cats,
      looksRight: looksRight || ai.looksRight,
      hasText: hasText || ai.hasText,
      engine: !fromAi
          ? engine
          : (!hasText ? 'gemini' : (used ? 'ocr+gemini' : engine)),
    );
  }
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A licence number, unless it is the holder's CNIC (Punjab issues licences
/// under the CNIC) — then only its last four digits.
String? _safeLicenceNumber(String? number, String? cnic) {
  if (number == null) return null;
  final digits = number.replaceAll(RegExp(r'\D'), '');
  final cnicDigits = (cnic ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length == 13 || (cnicDigits.isNotEmpty && digits == cnicDigits)) {
    return '•••• ${digits.substring(digits.length - 4)}';
  }
  return number.trim();
}

String? _cleanPlate(String? s) {
  if (s == null) return null;
  final t = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\- ]'), '').trim();
  return t.isEmpty ? null : t.replaceAll(RegExp(r'\s+'), '-');
}

/// `LEA-12-1234` / `LEA 1234` / `LEA1234` → (`LEA`, `1234`), for comparing
/// plates written with and without the year.
(String, String)? plateParts(String? plate) {
  if (plate == null) return null;
  final t = plate.toUpperCase();
  final m = RegExp(
    r'([A-Z]{1,4})[\s\-]*(?:\d{2}[\s\-]+)?(\d{1,4})\s*$',
  ).firstMatch(t.trim());
  if (m == null) return null;
  return (m[1]!, m[2]!);
}

bool platesMatch(String? a, String? b) {
  final pa = plateParts(a);
  final pb = plateParts(b);
  if (pa == null || pb == null) {
    return normalizeId(a ?? '') == normalizeId(b ?? '');
  }
  return pa.$1 == pb.$1 && int.parse(pa.$2) == int.parse(pb.$2);
}

class DocParser {
  DocParser._();

  /// A blurred or blank photo still yields a few stray characters; this
  /// much is needed before the text is judged at all.
  static bool _enoughText(String text) =>
      RegExp('[A-Za-z]').allMatches(text).length >= 20;

  // ── Shared ──────────────────────────────────────────────────────────────

  /// The value for the first line matching [label]: the rest of that line,
  /// else the next line that is not itself a label.
  static String? _labelled(
    List<String> lines,
    RegExp label, {
    RegExp? exclude,
    bool Function(String)? accept,
  }) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (exclude != null && exclude.hasMatch(line)) continue;
      final m = label.firstMatch(line);
      if (m == null) continue;
      final rest = restAfter(line, m);
      if (rest.isNotEmpty && (accept == null || accept(rest))) return rest;
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        final next = lines[j];
        if (_anyLabel.hasMatch(next)) break;
        if (accept == null || accept(next)) return next;
      }
    }
    return null;
  }

  static final _anyLabel = RegExp(
    r"\b(name|father|husband|cnic|licen[cs]e\s*(?:no|number|#)|issue|valid|expiry|category|categories|date\s*of|make|maker|type\s*of\s*body|colou?r|seating|horse\s*power|year\s*of|tax\s*paid|laden|owner|chassis|chasis|engine\s*no|address|reg(?:istration)?\.?\s*no|import|purchase|blood|cell\s*no)\b",
    caseSensitive: false,
  );

  static final _cnic = RegExp(r'\b(\d{5})\s*[-–]?\s*(\d{7})\s*[-–]?\s*(\d)\b');

  static List<String> categoriesIn(String text) {
    final t = text.toUpperCase();
    final out = <String>[];
    void add(String code, String pattern) {
      if (RegExp(pattern).hasMatch(t) && !out.contains(code)) out.add(code);
    }

    add('M/CYCLE', r'\bM\s*/?\s*CYCLE\b|\bMOTOR\s*CYCLE\b|\bMOTORCYCLE\b');
    add('M/CAR', r'\bM\s*/\s*CAR\b|\bMOTOR\s*CAR\b|\bM\.?\s*CAR\b');
    add('LTV', r'\bLTV\b');
    add('HTV', r'\bHTV\b');
    add('PSV', r'\bPSV\b');
    add('TRACTOR', r'\bTRACTOR\b');
    add('RICKSHAW', r'\bRICKSHAW\b');
    add('INVALID CARRIAGE', r'\bINVALID\s*CARRIAGE\b');
    return out;
  }

  // ── Driving licence ─────────────────────────────────────────────────────

  static final _licenceWords = RegExp(
    r"driving\s*licen[cs]e|licen[cs]e\s*(?:no|number|#)|licensing\s*authority|dlims|\bdl\s*no\b|valid\s*up\s*to|allowed\s*vehicles?",
    caseSensitive: false,
  );

  static DocReading parseLicense(List<String> rawLines) {
    final lines = cleanLines(rawLines);
    final type = docTypeLicense;
    if (lines.isEmpty) return DocReading(docType: type);
    final text = lines.join('\n');
    final fields = <String, String>{};

    bool nameLike(String s) => looksLikeName(
      s,
      stopWords: const {
        'name',
        'father',
        'licence',
        'license',
        'driving',
        'punjab',
        'government',
        'pakistan',
        'cnic',
        'valid',
        'issue',
      },
    );

    final name = _labelled(
      lines,
      RegExp(r"\b(?:holder'?s?\s*)?name\b", caseSensitive: false),
      exclude: RegExp(
        r"father|husband|s\s*/\s*o|d\s*/\s*o|w\s*/\s*o|owner",
        caseSensitive: false,
      ),
      accept: nameLike,
    );
    if (name != null) fields['name'] = _title(name);

    final father = _labelled(
      lines,
      RegExp(
        r"\b(?:father'?s?|husband'?s?)\s*(?:/\s*husband'?s?\s*)?name\b|\b[sdw]\s*/\s*o\b|\bson\s*of\b|\bdaughter\s*of\b|\bwife\s*of\b",
        caseSensitive: false,
      ),
      accept: nameLike,
    );
    if (father != null) fields['fatherName'] = _title(father);

    final cnicMatch = _cnic.firstMatch(text.replaceAll(RegExp(r'[lI]'), '1'));
    final cnicDigits = cnicMatch == null
        ? null
        : '${cnicMatch[1]}${cnicMatch[2]}${cnicMatch[3]}';
    if (cnicDigits != null) {
      fields['cnicLast4'] = cnicDigits.substring(cnicDigits.length - 4);
    }

    final number = _labelled(
      lines,
      RegExp(
        r'\b(licen[cs]e\s*(?:no|number|#)\.?|dl\s*no\.?)',
        caseSensitive: false,
      ),
      accept: (s) => RegExp(r'\d{3,}').hasMatch(s),
    );
    final safeNumber = _safeLicenceNumber(
      number?.split(RegExp(r'\s{2,}')).first,
      cnicDigits,
    );
    if (safeNumber != null) fields['licenseNumber'] = safeNumber;

    DateTime? labelledDate(RegExp label) {
      final v = _labelled(
        lines,
        label,
        accept: (s) => findDates([s]).isNotEmpty,
      );
      return v == null ? null : firstDateIn([v]);
    }

    final issue = labelledDate(
      RegExp(
        r'\b(issue(?:d)?\s*(?:date|on)?|date\s*of\s*issue)\b',
        caseSensitive: false,
      ),
    );
    var expiry = labelledDate(
      RegExp(
        r'\b(valid\s*(?:up\s*to|upto|till|until|thru|through|to)|expiry(?:\s*date)?|expires?(?:\s*on)?|date\s*of\s*expiry|validity)\b',
        caseSensitive: false,
      ),
    );
    final all = findDates(lines).map((d) => d.value).toList()..sort();
    // No label read: the latest date on a licence is when it runs out —
    // but only when there are several to choose from.
    if (expiry == null && all.length >= 2) expiry = all.last;
    if (issue != null) fields['issueDate'] = _iso(issue);
    if (expiry != null) fields['expiryDate'] = _iso(expiry);

    final cats = categoriesIn(text);
    if (cats.isNotEmpty) fields['categories'] = cats.join(', ');

    final looksRight =
        _licenceWords.hasMatch(text) || (cats.isNotEmpty && cnicDigits != null);
    return DocReading(
      docType: type,
      fields: fields,
      expiryDate: expiry,
      issueDate: issue,
      categories: cats,
      looksRight: looksRight,
      hasText: _enoughText(text),
    );
  }

  // ── Vehicle registration ────────────────────────────────────────────────

  static final _registrationWords = RegExp(
    r"registration|excise|taxation|form\s*-?\s*g\b|date\s*of\s*reg|seating\s*capacity|chass?is|engine\s*no|maker\s*name|type\s*of\s*body|c\s*<\s*etd|owner'?s?\s*name|horse\s*power",
    caseSensitive: false,
  );

  static final _plateShape = RegExp(
    r'\b([A-Z]{2,4})\s*-\s*(?:(\d{2})\s*-\s*)?(\d{1,4})\b',
  );

  static DocReading parseRegistration(List<String> rawLines) {
    final lines = cleanLines(rawLines);
    final type = docTypeRegistration;
    if (lines.isEmpty) return DocReading(docType: type);
    final text = lines.join('\n');
    final fields = <String, String>{};

    bool hasLetters(String s) => RegExp('[A-Za-z]{2,}').hasMatch(s);

    final make = _labelled(
      lines,
      RegExp(r'^make\b', caseSensitive: false),
      accept: (s) => s.trim().length >= 2,
    );
    if (make != null) fields['make'] = make.toUpperCase();

    final maker = _labelled(
      lines,
      RegExp(r'\b(maker\s*name|manufacturer)\b', caseSensitive: false),
      accept: hasLetters,
    );
    if (maker != null) fields['makerName'] = maker.toUpperCase();

    final body = _labelled(
      lines,
      RegExp(r'\b(type\s*of\s*body|body\s*type)\b', caseSensitive: false),
      accept: hasLetters,
    );
    if (body != null) fields['bodyType'] = body.toUpperCase();

    final colour = _labelled(
      lines,
      RegExp(r'\bcolou?r\b', caseSensitive: false),
      accept: hasLetters,
    );
    if (colour != null) fields['colour'] = colour.toUpperCase();

    final seats = _labelled(
      lines,
      RegExp(
        r'\b(seating\s*capacity|seating|no\.?\s*of\s*seats)\b',
        caseSensitive: false,
      ),
      accept: (s) => RegExp(r'^\s*\d{1,3}\b').hasMatch(s),
    );
    final seatCount = seats == null
        ? null
        : int.tryParse(RegExp(r'\d{1,3}').firstMatch(seats)![0]!);
    if (seatCount != null && seatCount > 0 && seatCount < 200) {
      fields['seatingCapacity'] = '$seatCount';
    }

    final year = _labelled(
      lines,
      RegExp(
        r'\b(year\s*of\s*m[a-z1]{1,3}\.?|year\s*of\s*manufactur\w*|model\s*year|model)\b',
        caseSensitive: false,
      ),
      accept: (s) => RegExp(r'\b(19|20)\d{2}\b').hasMatch(s),
    );
    if (year != null) {
      fields['yearOfManufacture'] = RegExp(
        r'\b(19|20)\d{2}\b',
      ).firstMatch(year)![0]!;
    }

    final owner = _labelled(
      lines,
      RegExp(r"\bowner'?s?\s*name\b", caseSensitive: false),
      accept: (s) => looksLikeName(
        s,
        stopWords: const {
          'father',
          'husband',
          'name',
          'cnic',
          'owner',
          'chasis',
          'chassis',
          'engine',
          'address',
        },
      ),
    );
    if (owner != null) fields['ownerName'] = _title(owner);

    final ownerCnic = _labelled(
      lines,
      RegExp(r'\bowner\s*cnic\b', caseSensitive: false),
      accept: (s) => _cnic.hasMatch(s),
    );
    final cnicLast4 = last4Digits(ownerCnic);
    if (cnicLast4 != null) fields['cnicLast4'] = cnicLast4;

    // Registration number: a labelled one, else the MRZ line
    // ("C<ETD<<<<LEA-12-1234<<<"), else any plate-shaped text.
    String? plate;
    final labelledPlate = _labelled(
      lines,
      RegExp(
        r'\b(reg(?:istration)?\.?\s*(?:no|number|#)\.?|vehicle\s*no\.?)',
        caseSensitive: false,
      ),
      exclude: RegExp(r'prv|previous|vanity|date', caseSensitive: false),
      accept: (s) => _plateShape.hasMatch(s.toUpperCase()),
    );
    if (labelledPlate != null) {
      plate = _plateShape.firstMatch(labelledPlate.toUpperCase())![0];
    }
    if (plate == null) {
      for (final l in lines) {
        if (!RegExp(r'C\s*<\s*ETD', caseSensitive: false).hasMatch(l)) continue;
        final inner = l
            .toUpperCase()
            .replaceFirst(RegExp(r'C\s*<\s*ETD'), '')
            .replaceAll('<', ' ');
        final m = _plateShape.firstMatch(inner);
        if (m != null) plate = m[0];
      }
    }
    if (plate == null) {
      for (final l in lines) {
        // "15-JAN-2018" is plate-shaped too.
        if (RegExp(r'form|mfb', caseSensitive: false).hasMatch(l) ||
            findDates([l]).isNotEmpty) {
          continue;
        }
        final m = _plateShape.firstMatch(l.toUpperCase());
        if (m != null) {
          plate = m[0];
          break;
        }
      }
    }
    if (plate != null) {
      fields['registrationNumber'] = plate.replaceAll(RegExp(r'\s+'), '');
    }

    return DocReading(
      docType: type,
      fields: fields,
      looksRight: _registrationWords.hasMatch(text),
      hasText: _enoughText(text),
    );
  }

  static String _title(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .map(
        (w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');
}
