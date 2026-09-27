import 'package:transit_core/transit_core.dart';

/// Grows the crowdsourced `institutes` directory that backs the "Institute
/// Name" autocomplete on Edit Info.
///
/// Nothing reads from `institutes` yet — the autocomplete's suggestion pool
/// is still the local dummy list in `parent_profile.dart` (see its own doc
/// comment for the sketch of swapping that to a live query). This is the
/// other half: every name a parent actually saves gets written here, so
/// that swap has real, ever-growing data to query once it happens.
class InstituteRepository {
  InstituteRepository._();
  static final InstituteRepository instance = InstituteRepository._();

  /// Deterministic id from [type] + a slug of [name], not an auto-generated
  /// one — so "Punjab College" typed by two different parents (however
  /// they capitalised or spaced it) always resolves to the *same* document
  /// instead of racing to create two near-duplicates. This is also what
  /// makes [ensureInstituteExists] safe to call unconditionally on every
  /// save rather than only when a name "looks new": an institute that
  /// already exists just gets a no-op read, never a duplicate write.
  static String _idFor(String type, String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${type.toLowerCase()}_$slug';
  }

  /// Trims [input] and title-cases it word by word, so "punjab college",
  /// "PUNJAB COLLEGE" and "Punjab College" all normalise to the one string
  /// and never create three separate directory entries for what a person
  /// would call the same institute.
  ///
  /// An all-caps token is left alone rather than title-cased — naive
  /// title-casing would otherwise mangle a real acronym like "LUMS" or
  /// "UET" into "Lums"/"Uet", which is a worse outcome than the duplicate
  /// this function exists to prevent.
  static String titleCase(String input) {
    final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    return collapsed
        .split(' ')
        .map((word) {
          final isAcronym =
              word == word.toUpperCase() && word != word.toLowerCase();
          if (isAcronym) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  /// Sanitises [rawName] and, if no institute with that (type, name) exists
  /// in `institutes` yet, creates it. Call this with whatever text is left
  /// in the "Institute Name" field's controller at save time — see
  /// `_ChildFlowSheetState._save()` in `parent_profile.dart`.
  Future<void> ensureInstituteExists({
    required String type,
    required String rawName,
  }) async {
    final name = titleCase(rawName);
    if (name.isEmpty || type.trim().isEmpty) return;

    final id = _idFor(type, name);
    final ref = Db.institutes.doc(id);
    final existing = await ref.get();
    if (existing.exists) return;

    // A single raw (non-typed-converter) `set`, not `Institute.toMap()` —
    // `Db.now` (`FieldValue.serverTimestamp()`) can't travel through a
    // typed converter, and `firestore.rules` only grants a regular user
    // `create` on this collection, never `update`, so this has to be the
    // one write that creates the document with its real timestamp already
    // on it, not a create-then-patch like some other repositories here do.
    await Db.fs.collection('institutes').doc(id).set({
      'name': name,
      'type': type,
      'createdAt': Db.now,
    });
  }
}
