import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transit_core/transit_core.dart';

import '../../ai/slip_check_service.dart';
import '../../ai/slip_matcher.dart';
import '../../ai/slip_parser.dart';
import '../../app/push_sender.dart';
import '../../app/session_service.dart';
import '../../data/payment_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_check_widgets.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/payment_presentation.dart';

/// How a family pays their driver: the driver's bank account and wallets at
/// the top, then a short form — how they paid, how much, for which month, a
/// screenshot — that goes to the driver, who checks their own account and
/// marks it received or not. Every child has their own payments.
///
/// Shared by parents (one child at a time) and students (themselves). There
/// is no card payment: nothing here moves money, so a card form could only
/// pretend to.
class FamilyPaymentScreen extends StatefulWidget {
  const FamilyPaymentScreen({super.key});

  @override
  State<FamilyPaymentScreen> createState() => _FamilyPaymentScreenState();
}

/// The one rider a payment is for.
class _Payer {
  final String studentId;
  final String name;
  final String driverId;
  const _Payer(this.studentId, this.name, this.driverId);
}

class _FamilyPaymentScreenState extends State<FamilyPaymentScreen> {
  final _method = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _monthKey = Payment.monthKeyFor(DateTime.now());

  /// The driver's bill this payment is for, when there is one to pay.
  String? _billId;
  File? _slip;
  bool _sending = false;

  /// The AI read of [_slip], started the moment it is picked so it is
  /// usually done by the time "Send" is tapped.
  Future<SlipReading>? _slipReading;

  /// [_slipReading] once it has finished — shown under the screenshot.
  SlipReading? _slipRead;

  /// Waiting on the AI check before the sheet can show.
  bool _checking = false;
  int _payerIndex = SessionService.instance.selectedChildIndex.value;

  bool get _accent => SessionService.instance.student.value != null;
  Color get _color => _accent ? AppTheme.studentAmber : AppTheme.parentPurple;

  @override
  void initState() {
    super.initState();
    SessionService.instance.addListener(_onSession);
  }

  @override
  void dispose() {
    SessionService.instance.removeListener(_onSession);
    _method.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  List<_Payer> get _payers {
    final session = SessionService.instance;
    final me = session.student.value;
    if (me != null) return [_Payer(me.id, me.name, me.driverId ?? '')];
    return [
      for (final c in session.children.value)
        _Payer(c.id, c.name, c.driverId ?? ''),
    ];
  }

  Future<void> _pickSlip() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final file = File(picked.path);
    // Read on-device straight away; nothing is uploaded until "Send".
    final reading = SlipCheckService.instance.read(file);
    setState(() {
      _slip = file;
      _slipReading = reading;
      _slipRead = null;
    });
    final read = await reading;
    if (mounted && identical(_slip, file)) setState(() => _slipRead = read);
  }

  /// Runs the AI check of the attached screenshot against what is being
  /// paid, and shows it. Null when the family chose not to send this
  /// screenshot (or closed the sheet); otherwise the check to store — which
  /// is itself null when the screenshot could not be checked at all.
  Future<({SlipReading reading, SlipCheck? check})?> _checkSlip({
    required Driver driver,
    required String paymentId,
    required int amountPaisa,
    required String monthKey,
    DateTime? periodStart,
  }) async {
    final slip = _slip!;
    setState(() => _checking = true);
    SlipReading reading;
    SlipCheck? check;
    try {
      reading = await (_slipReading ?? SlipCheckService.instance.read(slip));
      final duplicate = await SlipCheckService.instance.isDuplicate(
        reading,
        paymentId,
      );
      check = evaluateSlip(
        reading,
        SlipCheckService.expectationFor(
          driver: driver,
          amountPaisa: amountPaisa,
          periodStart: periodStart,
          monthKey: monthKey,
        ),
        duplicate: duplicate,
      );
    } catch (e) {
      debugPrint('slip check failed: $e');
      reading = SlipReading.empty;
      check = null;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return null;
    if (check == null) return (reading: reading, check: null);
    final choice = await showAiCheckSheet(
      context,
      details: SlipCheckDetails(check: check),
      matches: check.matches,
      accent: _color,
      proceedLabel: 'Send to ${driver.name}',
      proceedAnywayLabel: 'Send anyway',
      chooseAnotherLabel: 'Choose another screenshot',
    );
    if (choice == AiCheckChoice.chooseAnother && mounted) {
      unawaited(_pickSlip());
    }
    return choice == AiCheckChoice.proceed
        ? (reading: reading, check: check)
        : null;
  }

  /// [payer]'s bills still to pay, the one due first at the top.
  List<Payment> _billsFor(_Payer payer) =>
      SessionService.instance.payments.value
          .where(
            (p) =>
                p.studentId == payer.studentId && p.isBill && p.isOutstanding,
          )
          .toList()
        ..sort(
          (a, b) => (a.dueDate ?? DateTime(9999)).compareTo(
            b.dueDate ?? DateTime(9999),
          ),
        );

  Future<void> _send(_Payer payer, Driver driver) async {
    final method = _method.text.trim();
    final bills = _billsFor(payer);
    final bill =
        bills.where((b) => b.id == _billId).firstOrNull ??
        (bills.isEmpty ? null : bills.first);
    // Paying a bill pays exactly what it asks.
    final rupees = bill != null
        ? (bill.amountPaisa / 100).round()
        : int.tryParse(_amount.text.trim()) ?? 0;
    String? problem;
    if (method.isEmpty) {
      problem = 'Write how you paid, e.g. JazzCash or Easypaisa.';
    } else if (rupees <= 0) {
      problem = 'Enter the amount you sent.';
    } else if (_slip == null) {
      problem = 'Attach a screenshot of the payment.';
    }
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(problem), backgroundColor: AppTheme.error),
      );
      return;
    }
    final payerId = SessionService.instance.uid;
    if (payerId == null) return;

    final repo = PaymentRepository.instance;
    final paymentId = bill?.id ?? repo.newPaymentId();
    final monthKey = bill?.monthKey ?? _monthKey;
    final amountPaisa = bill?.amountPaisa ?? rupees * 100;

    // The AI check, before anything is uploaded. It only warns: the family
    // can always send anyway.
    final checked = await _checkSlip(
      driver: driver,
      paymentId: paymentId,
      amountPaisa: amountPaisa,
      monthKey: monthKey,
      periodStart: bill?.periodStart,
    );
    if (checked == null || !mounted) return;
    var check = checked.check;

    setState(() => _sending = true);
    try {
      String? url;
      String? publicId;
      if (CloudinaryService.instance.isConfigured) {
        final upload = await CloudinaryService.instance.uploadPaymentSlip(
          _slip!,
          paymentId,
        );
        url = upload.secureUrl;
        publicId = upload.publicId;
      }
      final notes = _note.text.trim().isEmpty ? null : _note.text.trim();
      if (bill != null) {
        await repo.submitProofOnBill(
          paymentId: bill.id,
          methodName: method,
          slipUrl: url,
          slipPublicId: publicId,
          notes: notes,
          slipCheck: check,
        );
      } else {
        await repo.submitProof(
          paymentId: paymentId,
          studentId: payer.studentId,
          payerId: payerId,
          driverId: driver.id,
          monthKey: monthKey,
          amountPaisa: rupees * 100,
          methodName: method,
          slipUrl: url,
          slipPublicId: publicId,
          notes: notes,
          slipCheck: check,
        );
      }
      // Claim the transaction id. Taken already (a race, or a check run
      // offline) means the same screenshot paid something else.
      if (check != null) {
        final taken = await SlipCheckService.instance.register(
          reading: checked.reading,
          paymentId: paymentId,
          parentId: payerId,
          driverId: driver.id,
        );
        if (taken && !check.issues.contains(SlipCheck.duplicateTransaction)) {
          check = check.copyWith(
            issues: [...check.issues, SlipCheck.duplicateTransaction],
          );
          await repo.updateSlipCheck(paymentId, check);
        }
      }
      final aiLine = check == null ? '' : ' ${check.summary()}.';
      await PushSender.instance.notifyOne(
        driver.id,
        UserNotification(
          id: '',
          type: NotificationType.payment,
          title: 'Payment sent for ${payer.name}',
          body:
              'Rs.$rupees via $method for ${monthLabel(monthKey)}.$aiLine '
              'Check your account and mark it received.',
          data: {
            'paymentId': paymentId,
            'studentId': payer.studentId,
            'route': '/driver/payment-history',
          },
        ),
      );
      // Warnings reach the family too, not only the driver — in their inbox
      // and on their lock screen, so a wrong screenshot is fixed quickly.
      if (check != null && !check.matches) {
        await PushSender.instance.notifyOne(
          payerId,
          UserNotification(
            id: '',
            type: NotificationType.payment,
            title: 'Check your payment screenshot',
            body:
                '${check.summary()} for ${payer.name}, '
                '${monthLabel(monthKey)}. ${check.messages().join(' ')} '
                '${driver.name} will confirm once they check their account.',
            data: {
              'paymentId': paymentId,
              'studentId': payer.studentId,
              'route': _accent ? '/student/payment' : '/parent/payment',
            },
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _slip = null;
        _slipReading = null;
        _slipRead = null;
        _amount.clear();
        _note.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent to ${driver.name}. You will be told once checked.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      debugPrint('sending payment proof failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send. Check your connection.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _field(String hint, {String? prefix}) => InputDecoration(
    hintText: hint,
    prefixText: prefix,
    hintStyle: TextStyle(color: context.textHint),
    filled: true,
    fillColor: context.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.inputBorder),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final payers = _payers;
    final payer = payers.isEmpty
        ? null
        : payers[_payerIndex.clamp(0, payers.length - 1)];
    final driver = SessionService.instance.driverFor(payer?.driverId);
    final history = payer == null
        ? const <Payment>[]
        : SessionService.instance.payments.value
              .where((p) => p.studentId == payer.studentId)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay your driver'),
        backgroundColor: context.cardBgElevated,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: context.scaffoldBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            if (payers.length > 1)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: payers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final on = payers[i] == payer;
                    return ChoiceChip(
                      label: Text(
                        payers[i].name.isEmpty ? 'Child' : payers[i].name,
                      ),
                      selected: on,
                      selectedColor: _color.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _payerIndex = i),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            if (payer == null || driver == null)
              GlassCard(
                enableBlur: false,
                padding: const EdgeInsets.all(18),
                child: Text(
                  payer == null
                      ? 'Add a child first.'
                      : '${payer.name} has no driver yet. Payment details '
                            'appear once a driver accepts the seat.',
                  style: TextStyle(color: context.textSecondary),
                ),
              )
            else ...[
              _PayoutCard(driver: driver, color: _color),
              const SizedBox(height: 14),
              GlassCard(
                enableBlur: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send payment proof for ${payer.name}',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _method,
                      style: TextStyle(color: context.textPrimary),
                      decoration: _field(
                        'How did you pay? e.g. JazzCash, Easypaisa, NayaPay',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_billsFor(payer).isNotEmpty)
                      _BillPicker(
                        bills: _billsFor(payer),
                        selected: _billId,
                        color: _color,
                        onSelected: (id) => setState(() => _billId = id),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amount,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(color: context.textPrimary),
                              decoration: _field('Amount', prefix: 'Rs. '),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _monthKey,
                              decoration: _field('Month'),
                              items: [
                                for (var i = 0; i < 4; i++)
                                  () {
                                    final now = DateTime.now();
                                    final key = Payment.monthKeyFor(
                                      DateTime(now.year, now.month - i),
                                    );
                                    return DropdownMenuItem(
                                      value: key,
                                      child: Text(monthLabel(key)),
                                    );
                                  }(),
                              ],
                              onChanged: (v) => setState(() => _monthKey = v!),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _note,
                      style: TextStyle(color: context.textPrimary),
                      decoration: _field('Note for the driver (optional)'),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickSlip,
                      child: Container(
                        height: _slip == null ? 70 : 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: context.inputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.inputBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _slip == null
                            ? Center(
                                child: Text(
                                  '📎  Attach payment screenshot',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : Image.file(_slip!, fit: BoxFit.cover),
                      ),
                    ),
                    if (_slip != null) ...[
                      const SizedBox(height: 8),
                      _SlipReadLine(reading: _slipRead),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sending || _checking
                            ? null
                            : () => _send(payer, driver),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _checking
                              ? 'Checking screenshot…'
                              : _sending
                              ? 'Sending…'
                              : 'Send to ${driver.name}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                payer == null ? 'Payments' : '${payer.name}\'s payments',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final p in history) _HistoryRow(payment: p),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  final Driver driver;
  final Color color;
  const _PayoutCard({required this.driver, required this.color});

  Widget _line(BuildContext context, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Copied $label')));
            },
            child: Icon(Icons.copy_rounded, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = driver.payout;
    return GlassCard(
      enableBlur: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay ${driver.name}',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (p.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${driver.name} has not added payment details yet. Ask them '
              'how to pay, or message them from the app.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ],
          if (p.hasBank) ...[
            const SizedBox(height: 12),
            Text(
              '🏦  Bank transfer',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            _line(context, 'Bank', p.bankName),
            _line(context, 'Account title', p.accountTitle),
            _line(context, 'Account no.', p.accountNumber),
          ],
          for (final w in p.wallets) ...[
            const SizedBox(height: 12),
            Text(
              '📱  ${w.provider}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            _line(context, 'Name', w.name),
            _line(context, 'Number', w.number),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Payment payment;
  const _HistoryRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final color = paymentStatusColor(p.status);
    final note = p.driverNote?.trim() ?? '';
    final check = p.slipCheck;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        enableBlur: false,
        padding: const EdgeInsets.all(14),
        onTap: check == null
            ? null
            : () => showSlipCheckDetails(context, check),
        child: Row(
          children: [
            Text(
              paymentStatusEmoji(p.status),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${monthLabel(p.monthKey)} · ${paisaToDisplay(p.amountPaisa)}',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      if ((p.methodName ?? '').isNotEmpty) p.methodName!,
                      paymentStatusLabel(p.status),
                      if (note.isNotEmpty) note,
                    ].join(' · '),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (check != null) ...[
                    const SizedBox(height: 4),
                    AiCheckBadge.slip(check, dense: true),
                  ],
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bills still to pay; the one picked is what the proof goes against.
class _BillPicker extends StatelessWidget {
  final List<Payment> bills;
  final String? selected;
  final Color color;
  final ValueChanged<String> onSelected;
  const _BillPicker({
    required this.bills,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final current = bills.any((b) => b.id == selected)
        ? selected
        : bills.first.id;
    return Column(
      children: [
        for (final b in bills)
          InkWell(
            onTap: () => onSelected(b.id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: b.id == current
                    ? color.withValues(alpha: 0.12)
                    : context.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: b.id == current ? color : context.inputBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    b.id == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${paisaToDisplay(b.amountPaisa)} · '
                          '${b.status == PaymentStatus.overdue ? 'Overdue' : 'Due'} '
                          '${dayLabel(b.dueDate)}',
                          style: TextStyle(
                            color: b.status == PaymentStatus.overdue
                                ? AppTheme.error
                                : context.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((b.driverNote ?? '').isNotEmpty)
                          Text(
                            'Driver: ${b.driverNote}',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One line under the attached screenshot: still reading, or what was read.
class _SlipReadLine extends StatelessWidget {
  final SlipReading? reading;
  const _SlipReadLine({required this.reading});

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final String text;
    if (r == null) {
      text = '🤖 Reading the screenshot…';
    } else if (r.isEmpty) {
      text = '🤖 Could not read this screenshot — you can still send it.';
    } else {
      final parts = [
        if (r.amountPaisa != null) paisaToDisplay(r.amountPaisa!),
        if (r.transactionId != null) 'ID ${r.transactionId}',
        if (r.receiverName != null) 'to ${r.receiverName}',
      ];
      text = '🤖 Read: ${parts.join(' · ')}';
    }
    return Text(
      text,
      style: TextStyle(color: context.textSecondary, fontSize: 12),
    );
  }
}
