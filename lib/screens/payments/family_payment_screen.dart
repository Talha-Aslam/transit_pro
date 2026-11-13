import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/push_sender.dart';
import '../../app/session_service.dart';
import '../../data/payment_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';
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
    if (picked != null) setState(() => _slip = File(picked.path));
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

    setState(() => _sending = true);
    final repo = PaymentRepository.instance;
    final paymentId = bill?.id ?? repo.newPaymentId();
    final monthKey = bill?.monthKey ?? _monthKey;
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
        );
      }
      await PushSender.instance.notifyOne(
        driver.id,
        UserNotification(
          id: '',
          type: NotificationType.payment,
          title: 'Payment sent for ${payer.name}',
          body:
              'Rs.$rupees via $method for ${monthLabel(monthKey)}. Check '
              'your account and mark it received.',
          data: {
            'paymentId': paymentId,
            'studentId': payer.studentId,
            'route': '/driver/payment-history',
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _slip = null;
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sending ? null : () => _send(payer, driver),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _sending ? 'Sending…' : 'Send to ${driver.name}',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        enableBlur: false,
        padding: const EdgeInsets.all(14),
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
