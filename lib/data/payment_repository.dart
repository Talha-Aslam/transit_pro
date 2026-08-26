import 'package:transit_core/transit_core.dart';

import 'db.dart';

/// Fee records.
///
/// The gateway integration is deliberately out of scope (JazzCash/EasyPaisa
/// need a registered merchant account). The real flow is: parent pays via the
/// app's deep link, uploads a slip, and the driver or admin confirms receipt —
/// which is genuinely how small operators work.
class PaymentRepository {
  PaymentRepository._();
  static final PaymentRepository instance = PaymentRepository._();

  /// Newest month first. Sorted here rather than by Firestore — see the note on
  /// [watchForParent].
  static List<Payment> _newestFirst(List<Payment> list) {
    final sorted = [...list];
    sorted.sort((a, b) => b.monthKey.compareTo(a.monthKey));
    return sorted;
  }

  /// Every fee record for one family.
  ///
  /// ## Why there is no `orderBy`
  ///
  /// These three queries used `.orderBy('monthKey', descending: true)` alongside
  /// their equality filter, which Firestore cannot serve without a composite
  /// index — and each one needs its own. That failed in production as
  /// `FAILED_PRECONDITION` the first time a real parent account loaded its fees,
  /// while working perfectly in development, because indexes here are created by
  /// hand through a console link rather than deployed from
  /// `firestore.indexes.json`.
  ///
  /// A single equality filter is served by Firestore's automatic index, so
  /// sorting in memory removes that failure mode entirely. `monthKey` is
  /// `YYYY-MM`, which sorts correctly as a string, and a family has at most a
  /// couple of dozen of these — the ordering was never the expensive part.
  Stream<List<Payment>> watchForParent(String parentId) => Db.payments
      .where('parentId', isEqualTo: parentId)
      .snapshots()
      .docsList
      .map(_newestFirst);

  Stream<List<Payment>> watchForStudent(String studentId) => Db.payments
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .docsList
      .map(_newestFirst);

  /// What a driver is owed — drives the driver's payment-history screen.
  Stream<List<Payment>> watchForDriver(String driverId) => Db.payments
      .where('driverId', isEqualTo: driverId)
      .snapshots()
      .docsList
      .map(_newestFirst);

  Future<Payment?> fetchForMonth(String studentId, String monthKey) async {
    final snap = await Db.payments
        .where('studentId', isEqualTo: studentId)
        .where('monthKey', isEqualTo: monthKey)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.data();
  }

  Future<String> createPayment(Payment payment) async {
    final ref = await Db.payments.add(payment);
    await ref.update({'createdAt': Db.now});
    return ref.id;
  }

  /// Records that the parent says they've paid and attached a slip. The money
  /// is not confirmed until [confirmReceipt] runs.
  Future<void> submitPayment({
    required String paymentId,
    required PaymentMethod method,
    String? slipUrl,
    String? slipPublicId,
    String? notes,
  }) =>
      Db.fs.collection('payments').doc(paymentId).update({
        'method': method.name,
        'slipUrl': ?slipUrl,
        'slipPublicId': ?slipPublicId,
        'notes': ?notes,
        'paidAt': Db.now,
      });

  /// Driver or admin confirms the money actually arrived. Only this flips the
  /// status to paid.
  Future<void> confirmReceipt({
    required String paymentId,
    required String confirmedBy,
  }) =>
      Db.fs.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.paid.name,
        'confirmedBy': confirmedBy,
        'confirmedAt': Db.now,
      });

  Future<void> markOverdue(String paymentId) =>
      Db.fs.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.overdue.name,
      });
}
