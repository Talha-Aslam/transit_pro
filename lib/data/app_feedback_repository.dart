import 'package:transit_core/transit_core.dart';

/// Writes `app_feedback/{autoId}` — "Rate the App" submissions.
///
/// Typed like every other cross-app collection (`Db.appFeedback`,
/// `AppFeedback` in `transit_core`) rather than a raw map, because the admin
/// app's notifications screen reads this collection back
/// (`AdminRepository.watchRecentFeedback`) — this is no longer write-only
/// from the client's side of things, even though the mobile app itself never
/// reads it.
class AppFeedbackRepository {
  AppFeedbackRepository._();
  static final AppFeedbackRepository instance = AppFeedbackRepository._();

  /// [rating] is 1-5, enforced by the star widget itself and by
  /// `firestore.rules` on create — this trusts the caller the same way
  /// `RatingRepository.submit` trusts its `rating` arg.
  ///
  /// One `add()`, not a create-then-update pair. The earlier version wrote
  /// the document, then set `timestamp` in a second call using `Db.now`
  /// (`FieldValue.serverTimestamp()`) — because that sentinel can't travel
  /// through `withConverter`, same reasoning as
  /// `RideRequestRepository.send()`'s separate `createdAt` write. But that
  /// second call is a write against an *existing* document, which Firestore
  /// rules treat as `update`, not `create` — and `app_feedback`'s rule only
  /// grants the owning user `create`; `update`/`delete` are `isAdmin()`-only.
  /// So every submission failed permission-denied on that second write,
  /// after the first had already silently created a timestamp-less
  /// document. `RatingRepository.submit` shows the actual fix: it never
  /// needed a second write because it accepts a plain client `DateTime` for
  /// `createdAt` instead of a server sentinel. This does the same —
  /// `DateTime.now()` in the same `add()` call — for a field where "exact
  /// to the second, immune to device clock drift" doesn't matter (an
  /// admin-only feedback list), the same tradeoff `ratings` already makes.
  Future<void> submit({
    required String userId,
    required int rating,
    String? comment,
  }) => Db.appFeedback.add(
    AppFeedback(
      id: '',
      userId: userId,
      rating: rating,
      comment: (comment == null || comment.trim().isEmpty)
          ? null
          : comment.trim(),
      timestamp: DateTime.now(),
    ),
  );
}
