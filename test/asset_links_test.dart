import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Integration check over the whole source tree: every image the code asks
/// for has to exist on disk *and* be declared in `pubspec.yaml`.
///
/// Flutter fails an undeclared or missing asset at runtime, on whatever
/// screen happens to reference it, with nothing at analysis or build time to
/// warn you — so a renamed file or a forgotten `pubspec` entry ships. This
/// catches both from a plain test run.
void main() {
  final assetPattern = RegExp(r"'(assets/[^']+\.(?:png|jpg|jpeg|gif|webp))'");

  late final List<String> declared;
  late final Map<String, List<String>> referenced;

  setUpAll(() {
    // ── What pubspec declares ──────────────────────────────────────────
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final start = pubspec.indexWhere((l) => l.trimRight() == '  assets:');
    expect(start, isNot(-1), reason: 'pubspec.yaml has no assets: section');

    declared = [];
    for (final line in pubspec.skip(start + 1)) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('- ')) break;
      declared.add(trimmed.substring(2).trim());
    }

    // ── What the code references ───────────────────────────────────────
    referenced = {};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in assetPattern.allMatches(entity.readAsStringSync())) {
        referenced
            .putIfAbsent(match.group(1)!, () => [])
            .add(entity.path.replaceAll(r'\', '/'));
      }
    }
  });

  test('the source references at least the assets we know about', () {
    // A guard on the guard: if the regex ever stops matching, the two tests
    // below would pass by finding nothing to check.
    expect(referenced.length, greaterThan(10));
  });

  /// Assets the code names but does not ship, each one guarded by an
  /// `errorBuilder` at the call site so it degrades to a drawn icon rather
  /// than failing. Listed here rather than silently skipped, so the gap stays
  /// visible and the entry has to be deleted the day the file is added.
  const knownMissing = <String, String>{
    'assets/images/utilities/google.png':
        'Google mark for the sign-in button; login_screen.dart falls back to '
            'an icon. Needs the official asset from Google\'s branding '
            'guidelines, which must not be redrawn by hand.',
  };

  test('every referenced asset exists on disk', () {
    final missing = <String>[];
    referenced.forEach((asset, users) {
      if (knownMissing.containsKey(asset)) return;
      if (!File(asset).existsSync()) {
        missing.add('$asset  (referenced by ${users.join(', ')})');
      }
    });
    expect(missing, isEmpty, reason: 'missing asset files:\n${missing.join('\n')}');
  });

  test('the known-missing list has not gone stale', () {
    // The allowlist must not become a place where broken references pile up:
    // each entry has to still be both missing and still referenced.
    knownMissing.forEach((asset, _) {
      expect(
        File(asset).existsSync(),
        isFalse,
        reason: '$asset now exists — remove it from knownMissing',
      );
      expect(
        referenced.containsKey(asset),
        isTrue,
        reason: '$asset is no longer referenced — remove it from knownMissing',
      );
    });
  });

  test('every referenced asset is declared in pubspec.yaml', () {
    bool isDeclared(String asset) => declared.any(
          (entry) => entry.endsWith('/')
              // A directory entry covers the files directly inside it, not
              // files in its subdirectories — which is exactly how Flutter
              // resolves it.
              ? asset.startsWith(entry) &&
                  !asset.substring(entry.length).contains('/')
              : entry == asset,
        );

    final undeclared = <String>[];
    referenced.forEach((asset, users) {
      if (!isDeclared(asset)) {
        undeclared.add('$asset  (referenced by ${users.join(', ')})');
      }
    });
    expect(
      undeclared,
      isEmpty,
      reason: 'assets used in code but not declared in pubspec.yaml:\n'
          '${undeclared.join('\n')}',
    );
  });

  test('the dashboard header has both of its themed renders', () {
    for (final f in const [
      'assets/images/dashboard/header_light.jpg',
      'assets/images/dashboard/header_dark.jpg',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: '$f is missing');
      // These are photographs shipped in the APK; the originals were 1.7MB
      // apiece before they were resized, which is most of a megabyte of
      // install size per theme for a banner.
      expect(
        File(f).lengthSync(),
        lessThan(400 * 1024),
        reason: '$f is too large to ship — resize and recompress it',
      );
    }
  });
}
