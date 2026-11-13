import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

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
  }) => Db.fs.collection('payments').doc(paymentId).update({
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
  }) => Db.fs.collection('payments').doc(paymentId).update({
    'status': PaymentStatus.paid.name,
    'confirmedBy': confirmedBy,
    'confirmedAt': Db.now,
  });

  /// A fresh id for a payment about to be written, so its screenshot can be
  /// uploaded under it first.
  String newPaymentId() => Db.payments.doc().id;

  /// The family's "we have paid": how they paid, a screenshot of it, and the
  /// month and amount. Waits as [PaymentStatus.submitted] until the driver
  /// checks their own account.
  ///
  /// Every submission is its own document: one the driver could not find
  /// stays on record as not received, and the family sends a new one rather
  /// than rewriting history.
  Future<void> submitProof({
    required String paymentId,
    required String studentId,
    required String payerId,
    required String driverId,
    required String monthKey,
    required int amountPaisa,
    required String methodName,
    String? slipUrl,
    String? slipPublicId,
    String? notes,
  }) => Db.fs.collection('payments').doc(paymentId).set({
    ...Payment(
      id: paymentId,
      studentId: studentId,
      parentId: payerId,
      driverId: driverId,
      monthKey: monthKey,
      amountPaisa: amountPaisa,
      status: PaymentStatus.submitted,
      methodName: methodName,
      slipUrl: slipUrl,
      slipPublicId: slipPublicId,
      notes: notes,
    ).toMap(),
    'paidAt': Db.now,
    'createdAt': Db.now,
  });

  /// The driver's answer after checking their account: the money arrived,
  /// or it did not. [note] says why, for a family told "not received".
  Future<void> decide({
    required String paymentId,
    required bool received,
    required String driverId,
    String? note,
  }) => Db.fs.collection('payments').doc(paymentId).update({
    'status': (received ? PaymentStatus.paid : PaymentStatus.rejected).name,
    'confirmedBy': driverId,
    'confirmedAt': Db.now,
    if (note != null && note.trim().isNotEmpty) 'driverNote': note.trim(),
  });

  /// The id of the [period]th monthly bill for [studentId] — fixed, so the
  /// same bill is never issued twice whichever phone issues it.
  static String billId(String driverId, String studentId, int period) =>
      'bill_${driverId}_${studentId}_$period';

  /// Issues one 30-day bill: [periodStart] to its due date 30 days later.
  Future<void> createBill({
    required String driverId,
    required String studentId,
    required String payerId,
    required int amountPaisa,
    required DateTime periodStart,
    required int period,
  }) => Db.fs
      .collection('payments')
      .doc(billId(driverId, studentId, period))
      .set({
        ...Payment(
          id: '',
          studentId: studentId,
          parentId: payerId,
          driverId: driverId,
          monthKey: Payment.monthKeyFor(periodStart),
          amountPaisa: amountPaisa,
          dueDate: periodStart.add(billingPeriod),
          periodStart: periodStart,
        ).toMap(),
        'createdAt': Db.now,
      });

  /// How long one bill covers.
  static const billingPeriod = Duration(days: 30);

  /// The family's proof against a bill the driver issued: the bill itself
  /// moves to [PaymentStatus.submitted] and waits for the driver.
  Future<void> submitProofOnBill({
    required String paymentId,
    required String methodName,
    String? slipUrl,
    String? slipPublicId,
    String? notes,
  }) => Db.fs.collection('payments').doc(paymentId).update({
    'status': PaymentStatus.submitted.name,
    'methodName': methodName,
    'slipUrl': ?slipUrl,
    'slipPublicId': ?slipPublicId,
    'notes': ?notes,
    'paidAt': Db.now,
  });

  /// The driver's answer on a bill. Received closes it; not received puts
  /// it back to what is owed — due, or overdue past its date — with the
  /// driver's reason for the family to read.
  Future<void> decideBill({
    required Payment bill,
    required bool received,
    required String driverId,
    String? note,
  }) {
    final overdue =
        bill.dueDate != null && bill.dueDate!.isBefore(DateTime.now());
    return Db.fs.collection('payments').doc(bill.id).update({
      'status': received
          ? PaymentStatus.paid.name
          : (overdue ? PaymentStatus.overdue : PaymentStatus.pending).name,
      'confirmedBy': driverId,
      'confirmedAt': Db.now,
      'driverNote': (note ?? '').trim().isEmpty
          ? (received ? FieldValue.delete() : 'Not received')
          : note!.trim(),
    });
  }

  Future<void> markReminded(String paymentId) => Db.fs
      .collection('payments')
      .doc(paymentId)
      .update({'reminderSentAt': Db.now});

  Future<void> markOverdue(String paymentId) => Db.fs
      .collection('payments')
      .doc(paymentId)
      .update({'status': PaymentStatus.overdue.name});
}
