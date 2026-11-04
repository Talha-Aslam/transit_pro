import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pro/app/language_provider.dart';

/// Integration check over the translation table.
///
/// `AppStrings.t('key')` falls back to the English string, and then to the
/// key itself, when a key is missing — so a typo or a half-finished
/// translation never fails a build or a run. It just leaves one word in
/// English in the middle of an Urdu card, which is exactly how the gaps on
/// the dashboards survived this long.
void main() {
  late final String providerSrc;
  late final Set<String> enKeys;
  late final Set<String> urKeys;
  late final Map<String, List<String>> usedKeys;

  setUpAll(() {
    providerSrc = File('lib/app/language_provider.dart').readAsStringSync();

    // The file holds the English map first, then the Urdu one; both end on a
    // line that is exactly "  };".
    final lines = providerSrc.split('\n');
    final ends = <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i] == '  };') i,
    ];
    expect(ends.length, greaterThanOrEqualTo(2),
        reason: 'expected an English and an Urdu map');

    // Several lines carry two entries, so scan every match on the line
    // rather than only the one at its start; skip commented-out entries.
    final keyPattern = RegExp(r"'([a-z0-9_]+)':");
    Set<String> keysIn(int from, int to) => {
          for (final line in lines.sublist(from, to))
            if (!line.trimLeft().startsWith('//'))
              for (final m in keyPattern.allMatches(line)) m.group(1)!,
        };

    enKeys = keysIn(0, ends[0]);
    urKeys = keysIn(ends[0] + 1, ends[1]);

    usedKeys = {};
    final call = RegExp(r"AppStrings\.t\(\s*'([a-z0-9_]+)'");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('language_provider.dart')) continue;
      for (final m in call.allMatches(entity.readAsStringSync())) {
        usedKeys
            .putIfAbsent(m.group(1)!, () => [])
            .add(entity.path.replaceAll(r'\', '/'));
      }
    }
  });

  test('the scan found both maps and a realistic number of call sites', () {
    expect(enKeys.length, greaterThan(100));
    expect(urKeys.length, greaterThan(100));
    expect(usedKeys.length, greaterThan(50));
  });

  test('every key the code asks for exists in English', () {
    final missing = <String>[];
    usedKeys.forEach((key, users) {
      if (!enKeys.contains(key)) {
        missing.add('$key  (used by ${users.toSet().join(', ')})');
      }
    });
    expect(missing, isEmpty,
        reason: 'keys with no English string:\n${missing.join('\n')}');
  });

  test('every key the code asks for is translated to Urdu', () {
    // This is the one that matters: a key present in English and absent in
    // Urdu shows the English word to a reader who switched language.
    final missing = <String>[];
    usedKeys.forEach((key, users) {
      if (!urKeys.contains(key)) {
        missing.add('$key  (used by ${users.toSet().join(', ')})');
      }
    });
    expect(missing, isEmpty,
        reason: 'keys with no Urdu translation:\n${missing.join('\n')}');
  });

  test('neither map declares the same key twice', () {
    // A repeated key silently wins or loses depending on order, and the
    // analyzer only warns — it does not fail a build.
    final lines = providerSrc.split('\n');
    final ends = <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i] == '  };') i,
    ];
    final key = RegExp(r"'([a-z0-9_]+)':");

    List<String> duplicatesIn(int from, int to) {
      final seen = <String>{};
      final dupes = <String>[];
      for (final line in lines.sublist(from, to)) {
        // A commented-out entry is not a key, and several lines carry two
        // entries, so scan every match on the line but skip comments.
        if (line.trimLeft().startsWith('//')) continue;
        for (final m in key.allMatches(line)) {
          if (!seen.add(m.group(1)!)) dupes.add(m.group(1)!);
        }
      }
      return dupes;
    }

    expect(duplicatesIn(0, ends[0]), isEmpty,
        reason: 'duplicate English keys: '
            '${duplicatesIn(0, ends[0]).join(', ')}');
    expect(duplicatesIn(ends[0] + 1, ends[1]), isEmpty,
        reason: 'duplicate Urdu keys: '
            '${duplicatesIn(ends[0] + 1, ends[1]).join(', ')}');
  });

  test('the Urdu map covers the English one', () {
    final untranslated = enKeys.difference(urKeys).toList()..sort();
    expect(untranslated, isEmpty,
        reason: 'English keys with no Urdu entry:\n'
            '${untranslated.join('\n')}');
  });

  test('no Urdu entry is left as English', () {
    // A copy-pasted English value is worse than a missing key: the fallback
    // at least makes a missing key obvious in a diff.
    final lines = providerSrc.split('\n');
    final ends = <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i] == '  };') i,
    ];
    final entry = RegExp(r"^    '([a-z0-9_]+)':\s*(['\x22])(.*)\2,$");
    final latin = RegExp(r'[A-Za-z]{4,}');

    // Strings that keep Latin on purpose, because the terms inside them
    // are not translated anywhere. Listed by key so the exception stays
    // visible instead of being buried in a regex.
    const keepsLatin = <String, String>{
      'login_encrypted': '"256-bit" and "GDPR" are used as-is in Urdu too',
    };

    final suspicious = <String>[];
    for (final line in lines.sublist(ends[0] + 1, ends[1])) {
      final m = entry.firstMatch(line);
      if (m == null) continue;
      if (keepsLatin.containsKey(m.group(1))) continue;
      final value = m.group(3)!;
      // Dart interpolations and `{placeholder}` slots are filled in by the
      // caller, so Latin inside them says nothing about the translation.
      if (value.contains(r'$')) continue;
      final stripped = value.replaceAll(RegExp(r'\{[^}]*\}'), '');
      if (latin.hasMatch(stripped)) suspicious.add('${m.group(1)} = $value');
    }
    expect(suspicious, isEmpty,
        reason: 'Urdu entries that still read as English:\n'
            '${suspicious.join('\n')}');
  });

  group('AppStrings.t at runtime', () {
    test('returns the English string by default', () {
      LanguageProvider.instance.setLanguage('English');
      expect(AppStrings.t('good_morning'), 'Good Morning');
    });

    test('returns the Urdu string once switched', () {
      LanguageProvider.instance.setLanguage('Urdu');
      expect(AppStrings.t('good_morning'), isNot('Good Morning'));
      LanguageProvider.instance.setLanguage('English');
    });

    test('an unknown key falls back to the key itself, not a crash', () {
      expect(AppStrings.t('definitely_not_a_key'), 'definitely_not_a_key');
    });
  });
}
