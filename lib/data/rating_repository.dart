import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

import 'db.dart';

/// Reads and writes `ratings/{driverId}_{raterId}_{weekKey}`.
///
/// The composite document id is the whole one-rating-per-week mechanism: a
/// second attempt in the same week targets a document that already exists, and
/// `firestore.rules` denies `create` on an existing doc. No query, no read, no
/// race — which is why the id is built rather than auto-generated.
///
/// This replaces the `SharedPreferences` blob the prototype used, where a
/// reinstall wiped the history and the driver never saw the rating at all.
class RatingRepository {
  RatingRepository._();
  static final RatingRepository instance = RatingRepository._();

  static String idFor({
    required String driverId,
    required String raterId,
    required String weekKey,
  }) =>
      '${driverId}_${raterId}_$weekKey';

  /// Every rating this user has given, newest first. Small by construction —
  /// one per driver per week.
  Stream<List<DriverRating>> watchByRater(String raterId, {int limit = 100}) =>
      Db.ratings
          .where('raterId', isEqualTo: raterId)
          .limit(limit)
          .snapshots()
          .docsList;

  Future<List<DriverRating>> fetchByRater(String raterId) async {
    final snap =
        await Db.ratings.where('raterId', isEqualTo: raterId).limit(100).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Stream<List<DriverRating>> watchForDriver(String driverId, {int limit = 50}) =>
      Db.ratings
          .where('driverId', isEqualTo: driverId)
          .limit(limit)
          .snapshots()
          .docsList;

  /// Submits a rating for the current ISO week.
  ///
  /// Returns false when one already exists for that week rather than throwing,
  /// because "you already rated this week" is an expected outcome the UI shows
  /// as a disabled button, not an error.
  Future<bool> submit({
    required String driverId,
    required String raterId,
    required double rating,
    String? studentId,
    String? comment,
    DateTime? at,
  }) async {
    final when = at ?? DateTime.now();
    final weekKey = DriverRating.weekKeyFor(when);
    final id = idFor(driverId: driverId, raterId: raterId, weekKey: weekKey);

    try {
      await Db.ratings.doc(id).set(
            DriverRating(
              id: id,
              driverId: driverId,
              raterId: raterId,
              studentId: studentId,
              rating: rating,
              weekKey: weekKey,
              comment: comment,
              createdAt: when,
            ),
          );
      return true;
    } on FirebaseException catch (e) {
      // The rules reject a write onto an existing rating.
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// Whether [raterId] may still rate [driverId] this week.
  Future<bool> canRate({
    required String driverId,
    required String raterId,
    DateTime? at,
  }) async {
    final weekKey = DriverRating.weekKeyFor(at ?? DateTime.now());
    final snap = await Db.ratings
        .doc(idFor(driverId: driverId, raterId: raterId, weekKey: weekKey))
        .get();
    return !snap.exists;
  }
}
