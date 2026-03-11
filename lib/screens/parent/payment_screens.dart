import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Mock driver payment data (in a real app this comes from a backend)
// ─────────────────────────────────────────────────────────────────────────────
class _DriverPaymentInfo {
  final String driverName;
  final String busNumber;
  final String? jazzCashNumber;
  final String? easypaisaNumber;
  final String? jazzCashAccountName;
  final String? easypaisaAccountName;

  const _DriverPaymentInfo({
    required this.driverName,
    required this.busNumber,
    this.jazzCashNumber,
    this.easypaisaNumber,
    this.jazzCashAccountName,
    this.easypaisaAccountName,
  });
}

/// Returns mock driver payment info for a given bus number.
_DriverPaymentInfo _driverInfoFor(String busNumber) {
  // In a real app this would be a Firestore/API lookup.
  const drivers = {
    'Bus #42': _DriverPaymentInfo(
      driverName: 'Muhammad Tariq',
      busNumber: 'Bus #42',
      jazzCashNumber: '0300-1234567',
      easypaisaNumber: '0321-7654321',
      jazzCashAccountName: 'M. Tariq',
      easypaisaAccountName: 'Muhammad Tariq',
    ),
    'Bus #15': _DriverPaymentInfo(
      driverName: 'Ali Hassan',
      busNumber: 'Bus #15',
      jazzCashNumber: '0312-9876543',
      easypaisaNumber: null,
      jazzCashAccountName: 'Ali Hassan',
      easypaisaAccountName: null,
    ),
  };
  return drivers[busNumber] ??
      _DriverPaymentInfo(driverName: 'Driver', busNumber: busNumber);
}

// ─────────────────────────────────────────────────────────────────────────────
//  1. Payment Method Selection Screen
// ─────────────────────────────────────────────────────────────────────────────
class PaymentMethodScreen extends StatefulWidget {
  final String amount;
  final String month;

  const PaymentMethodScreen({
    super.key,
    required this.amount,
    required this.month,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final children = ParentDataService.instance.children.value;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _PayHeader(
                title: AppStrings.t('select_payment_method'),
                onBack: () => context.pop(),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount summary
                      GlassCard(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.studentAmber.withOpacity(0.15),
                            AppTheme.studentOrange.withOpacity(0.06),
                          ],
                        ),
                        borderColor: AppTheme.studentAmber.withOpacity(0.3),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppTheme.studentGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text(
                                  '💳',
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.t('amount_due'),
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  ShaderMask(
                                    shaderCallback: (b) => AppTheme
                                        .studentGradient
                                        .createShader(b),
                                    child: Text(
                                      widget.amount,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppStrings.t('month_lbl'),
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  widget.month,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        AppStrings.t('choose_method'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Cash
                      _MethodCard(
                        icon: '💵',
                        title: AppStrings.t('cash_payment'),
                        subtitle: AppStrings.t('cash_payment_desc'),
                        accentColor: AppTheme.success,
                        badgeLabel: AppStrings.t('requires_approval'),
                        badgeColor: AppTheme.warning,
                        onTap: () => context.push(
                          '/parent/payment/cash',
                          extra: {
                            'amount': widget.amount,
                            'month': widget.month,
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Online (JazzCash / EasyPaisa)
                      _MethodCard(
                        icon: '📲',
                        title: AppStrings.t('online_payment'),
                        subtitle: AppStrings.t('online_payment_desc'),
                        accentColor: AppTheme.info,
                        badgeLabel: 'JazzCash · EasyPaisa',
                        badgeColor: AppTheme.info,
                        onTap: () {
                          // Pick the first child's driver for demo; real app
                          // shows a child selector if multiple children exist
                          final busNumber = children.isNotEmpty
                              ? children.first.busNumber
                              : 'Bus #42';
                          context.push(
                            '/parent/payment/online',
                            extra: {
                              'amount': widget.amount,
                              'month': widget.month,
                              'busNumber': busNumber,
                              'children': children
                                  .map(
                                    (c) => {
                                      'name': c.name,
                                      'busNumber': c.busNumber,
                                      'driver': c.driver,
                                    },
                                  )
                                  .toList(),
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Card
                      _MethodCard(
                        icon: '💳',
                        title: AppStrings.t('card_payment'),
                        subtitle: AppStrings.t('card_payment_desc'),
                        accentColor: AppTheme.parentPurple,
                        badgeLabel: 'Visa · Mastercard',
                        badgeColor: AppTheme.parentPurple,
                        onTap: () => context.push(
                          '/parent/payment/card',
                          extra: {
                            'amount': widget.amount,
                            'month': widget.month,
                          },
                        ),
                      ),

                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 12,
                              color: context.textTertiary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              AppStrings.t('secure_payment_note'),
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 11,
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
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  2. Cash Payment Screen
// ─────────────────────────────────────────────────────────────────────────────
class CashPaymentScreen extends StatefulWidget {
  final String amount;
  final String month;

  const CashPaymentScreen({
    super.key,
    required this.amount,
    required this.month,
  });

  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> {
  final _notesCtrl = TextEditingController();
  bool _submitted = false;
  String _requestId = '';

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    // Generate a mock request ID
    _requestId =
        'CP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  void _submitRequest() {
    // In a real app: POST to backend, notify driver
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _PayHeader(
                title: AppStrings.t('cash_payment'),
                onBack: () => context.pop(),
              ),
              Expanded(
                child: _submitted
                    ? _SubmittedConfirmation(
                        icon: '✅',
                        accentColor: AppTheme.success,
                        title: AppStrings.t('request_submitted'),
                        subtitle: AppStrings.t('cash_request_submitted_desc'),
                        lines: [
                          _ConfirmLine(
                            AppStrings.t('amount_lbl'),
                            widget.amount,
                          ),
                          _ConfirmLine(AppStrings.t('month_lbl'), widget.month),
                          _ConfirmLine(
                            AppStrings.t('request_id_lbl'),
                            _requestId,
                          ),
                          _ConfirmLine(
                            AppStrings.t('status_lbl'),
                            AppStrings.t('pending_driver_confirmation'),
                          ),
                        ],
                        actionLabel: AppStrings.t('back_to_fees'),
                        onAction: () {
                          context.go('/parent');
                        },
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info banner
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.info.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ℹ️',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      AppStrings.t('cash_info_banner'),
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Summary card
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _SummaryRow(
                                    AppStrings.t('amount_lbl'),
                                    widget.amount,
                                    highlight: true,
                                  ),
                                  const Divider(
                                    color: Colors.white12,
                                    height: 20,
                                  ),
                                  _SummaryRow(
                                    AppStrings.t('month_lbl'),
                                    widget.month,
                                  ),
                                  const SizedBox(height: 4),
                                  _SummaryRow(
                                    AppStrings.t('payment_method_lbl'),
                                    AppStrings.t('cash_payment'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            Text(
                              AppStrings.t('notes_optional'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: AppStrings.t('cash_notes_hint'),
                                filled: true,
                                fillColor: context.inputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: context.inputBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: context.inputBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppTheme.success,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 28),

                            _GradientButton(
                              label: AppStrings.t('send_cash_request'),
                              gradient: const LinearGradient(
                                colors: [AppTheme.success, Color(0xFF059669)],
                              ),
                              onTap: _submitRequest,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  3. Online Payment Screen (JazzCash / EasyPaisa)
// ─────────────────────────────────────────────────────────────────────────────
class OnlinePaymentScreen extends StatefulWidget {
  final String amount;
  final String month;
  final List<Map<String, String>> children;

  const OnlinePaymentScreen({
    super.key,
    required this.amount,
    required this.month,
    required this.children,
  });

  @override
  State<OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends State<OnlinePaymentScreen> {
  final _txnCtrl = TextEditingController();
  int _childIndex = 0;
  String _platform = 'jazzcash'; // 'jazzcash' | 'easypaisa'
  bool _submitted = false;
  bool _loading = false;
  String _txnError = '';

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _txnCtrl.dispose();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  _DriverPaymentInfo get _currentDriver {
    final bn = widget.children.isNotEmpty
        ? widget.children[_childIndex]['busNumber'] ?? 'Bus #42'
        : 'Bus #42';
    return _driverInfoFor(bn);
  }

  bool get _hasPlatform {
    final d = _currentDriver;
    if (_platform == 'jazzcash') return d.jazzCashNumber != null;
    return d.easypaisaNumber != null;
  }

  String get _platformNumber {
    final d = _currentDriver;
    return _platform == 'jazzcash'
        ? (d.jazzCashNumber ?? '')
        : (d.easypaisaNumber ?? '');
  }

  String get _platformAccountName {
    final d = _currentDriver;
    return _platform == 'jazzcash'
        ? (d.jazzCashAccountName ?? '')
        : (d.easypaisaAccountName ?? '');
  }

  void _confirmPayment() {
    if (_txnCtrl.text.trim().isEmpty) {
      setState(() => _txnError = AppStrings.t('enter_transaction_id'));
      return;
    }
    setState(() {
      _txnError = '';
      _loading = true;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted)
        setState(() {
          _loading = false;
          _submitted = true;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _PayHeader(
                title: AppStrings.t('online_payment'),
                onBack: () => context.pop(),
              ),
              Expanded(
                child: _submitted
                    ? _SubmittedConfirmation(
                        icon: '📲',
                        accentColor: AppTheme.info,
                        title: AppStrings.t('payment_submitted'),
                        subtitle: AppStrings.t('online_submitted_desc'),
                        lines: [
                          _ConfirmLine(
                            AppStrings.t('amount_lbl'),
                            widget.amount,
                          ),
                          _ConfirmLine(AppStrings.t('month_lbl'), widget.month),
                          _ConfirmLine(
                            AppStrings.t('transaction_id_lbl'),
                            _txnCtrl.text.trim(),
                          ),
                          _ConfirmLine(
                            AppStrings.t('platform_lbl'),
                            _platform == 'jazzcash' ? 'JazzCash' : 'EasyPaisa',
                          ),
                        ],
                        actionLabel: AppStrings.t('back_to_fees'),
                        onAction: () => context.go('/parent'),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Child selector (if multiple children)
                            if (widget.children.length > 1) ...[
                              Text(
                                AppStrings.t('select_child'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 38,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: widget.children.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, i) {
                                    final sel = i == _childIndex;
                                    return GestureDetector(
                                      onTap: () =>
                                          setState(() => _childIndex = i),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: sel
                                              ? AppTheme.parentGradient
                                              : null,
                                          color: sel
                                              ? null
                                              : context.cardBgElevated,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: sel
                                                ? Colors.transparent
                                                : context.surfaceBorder,
                                          ),
                                        ),
                                        child: Text(
                                          widget.children[i]['name'] ?? '',
                                          style: TextStyle(
                                            color: sel
                                                ? Colors.white
                                                : context.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Platform toggle
                            Text(
                              AppStrings.t('select_platform'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _PlatformChip(
                                  label: 'JazzCash',
                                  imagePath:
                                      'assets/images/utilities/jazzcash.png',
                                  selected: _platform == 'jazzcash',
                                  accentColor: const Color(0xFFD3290F),
                                  onTap: () =>
                                      setState(() => _platform = 'jazzcash'),
                                ),
                                const SizedBox(width: 10),
                                _PlatformChip(
                                  label: 'EasyPaisa',
                                  imagePath:
                                      'assets/images/utilities/easypaisa.png',
                                  selected: _platform == 'easypaisa',
                                  accentColor: const Color(0xFF4CAF50),
                                  onTap: () =>
                                      setState(() => _platform = 'easypaisa'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Driver info card
                            if (_hasPlatform) ...[
                              Text(
                                AppStrings.t('driver_account_details'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DriverInfoCard(
                                driver: _currentDriver,
                                platform: _platform,
                                accountName: _platformAccountName,
                                number: _platformNumber,
                                amount: widget.amount,
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.warning.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      '⚠️',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        AppStrings.t('platform_not_available'),
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            if (_hasPlatform) ...[
                              Text(
                                AppStrings.t('enter_transaction_id'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _txnCtrl,
                                onChanged: (_) =>
                                    setState(() => _txnError = ''),
                                decoration: InputDecoration(
                                  hintText: AppStrings.t('txn_id_hint'),
                                  filled: true,
                                  fillColor: context.inputFill,
                                  errorText: _txnError.isEmpty
                                      ? null
                                      : _txnError,
                                  prefixIcon: Icon(
                                    Icons.receipt_long_rounded,
                                    color: context.textTertiary,
                                    size: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: context.inputBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: context.inputBorder,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppTheme.info,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _GradientButton(
                                label: _loading
                                    ? '...'
                                    : AppStrings.t('confirm_payment'),
                                gradient: const LinearGradient(
                                  colors: [AppTheme.info, Color(0xFF2563EB)],
                                ),
                                onTap: _loading ? null : _confirmPayment,
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  4. Card Payment Screen
// ─────────────────────────────────────────────────────────────────────────────
class CardPaymentScreen extends StatefulWidget {
  final String amount;
  final String month;

  const CardPaymentScreen({
    super.key,
    required this.amount,
    required this.month,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _cardNumCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;
  bool _loading = false;
  bool _obscureCvv = true;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _cardNumCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  String _formatCardNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final chunks = <String>[];
    for (var i = 0; i < digits.length && i < 16; i += 4) {
      chunks.add(
        digits.substring(i, i + 4 > digits.length ? digits.length : i + 4),
      );
    }
    return chunks.join(' ');
  }

  String? _validateCard(String? v) {
    if (v == null || v.replaceAll(' ', '').length < 16) {
      return AppStrings.t('invalid_card_number');
    }
    return null;
  }

  String? _validateExpiry(String? v) {
    if (v == null || !RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) {
      return AppStrings.t('invalid_expiry');
    }
    return null;
  }

  String? _validateCvv(String? v) {
    if (v == null || v.length < 3) return AppStrings.t('invalid_cvv');
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().length < 2) {
      return AppStrings.t('enter_card_name');
    }
    return null;
  }

  void _pay() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted)
        setState(() {
          _loading = false;
          _submitted = true;
        });
    });
  }

  // Determine card brand from number
  String _cardBrandIcon(String number) {
    final d = number.replaceAll(' ', '');
    if (d.startsWith('4')) return '💳 Visa';
    if (d.startsWith('5')) return '💳 Mastercard';
    if (d.startsWith('3')) return '💳 Amex';
    return '💳';
  }

  @override
  Widget build(BuildContext context) {
    final cardDisplay = _cardNumCtrl.text.replaceAll(' ', '');

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _PayHeader(
                title: AppStrings.t('card_payment'),
                onBack: () => context.pop(),
              ),
              Expanded(
                child: _submitted
                    ? _SubmittedConfirmation(
                        icon: '✅',
                        accentColor: AppTheme.parentPurple,
                        title: AppStrings.t('payment_successful'),
                        subtitle: AppStrings.t('card_success_desc'),
                        lines: [
                          _ConfirmLine(
                            AppStrings.t('amount_lbl'),
                            widget.amount,
                          ),
                          _ConfirmLine(AppStrings.t('month_lbl'), widget.month),
                          _ConfirmLine(
                            AppStrings.t('card_lbl'),
                            '**** **** **** ${_cardNumCtrl.text.replaceAll(' ', '').substring((_cardNumCtrl.text.replaceAll(' ', '').length - 4).clamp(0, 9999))}',
                          ),
                          _ConfirmLine(
                            AppStrings.t('status_lbl'),
                            AppStrings.t('approved'),
                          ),
                        ],
                        actionLabel: AppStrings.t('back_to_fees'),
                        onAction: () => context.go('/parent'),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Visual card preview
                              _CardPreview(
                                number: cardDisplay.isEmpty
                                    ? '•••• •••• •••• ••••'
                                    : _formatCardNumber(cardDisplay),
                                name: _nameCtrl.text.isEmpty
                                    ? AppStrings.t('cardholder_name')
                                    : _nameCtrl.text.toUpperCase(),
                                expiry: _expiryCtrl.text.isEmpty
                                    ? 'MM/YY'
                                    : _expiryCtrl.text,
                                brand: _cardBrandIcon(cardDisplay),
                              ),
                              const SizedBox(height: 24),

                              // Amount
                              GlassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: _SummaryRow(
                                  AppStrings.t('amount_to_pay'),
                                  widget.amount,
                                  highlight: true,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Card number
                              _FieldLabel(AppStrings.t('card_number_lbl')),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _cardNumCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(16),
                                  _CardNumberFormatter(),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: _fieldDecor(
                                  context,
                                  hint: '0000 0000 0000 0000',
                                  prefixIcon: Icons.credit_card_rounded,
                                  accentColor: AppTheme.parentPurple,
                                ),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                                validator: _validateCard,
                              ),
                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  // Expiry
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _FieldLabel(AppStrings.t('expiry_lbl')),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _expiryCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(4),
                                            _ExpiryFormatter(),
                                          ],
                                          onChanged: (_) => setState(() {}),
                                          decoration: _fieldDecor(
                                            context,
                                            hint: 'MM/YY',
                                            prefixIcon:
                                                Icons.date_range_rounded,
                                            accentColor: AppTheme.parentPurple,
                                          ),
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 15,
                                          ),
                                          validator: _validateExpiry,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // CVV
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _FieldLabel(AppStrings.t('cvv_lbl')),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _cvvCtrl,
                                          keyboardType: TextInputType.number,
                                          obscureText: _obscureCvv,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(4),
                                          ],
                                          decoration: _fieldDecor(
                                            context,
                                            hint: '•••',
                                            prefixIcon: Icons.lock_rounded,
                                            accentColor: AppTheme.parentPurple,
                                            suffix: GestureDetector(
                                              onTap: () => setState(
                                                () =>
                                                    _obscureCvv = !_obscureCvv,
                                              ),
                                              child: Icon(
                                                _obscureCvv
                                                    ? Icons
                                                          .visibility_off_rounded
                                                    : Icons.visibility_rounded,
                                                size: 18,
                                                color: context.textTertiary,
                                              ),
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 15,
                                          ),
                                          validator: _validateCvv,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Cardholder name
                              _FieldLabel(AppStrings.t('cardholder_name')),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setState(() {}),
                                decoration: _fieldDecor(
                                  context,
                                  hint: AppStrings.t('name_on_card_hint'),
                                  prefixIcon: Icons.person_rounded,
                                  accentColor: AppTheme.parentPurple,
                                ),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                ),
                                validator: _validateName,
                              ),
                              const SizedBox(height: 28),

                              _GradientButton(
                                label: _loading
                                    ? AppStrings.t('processing')
                                    : '${AppStrings.t('pay')} ${widget.amount}',
                                gradient: AppTheme.parentGradient,
                                onTap: _loading ? null : _pay,
                                loading: _loading,
                              ),

                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 12,
                                    color: context.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.t('ssl_secured'),
                                    style: TextStyle(
                                      color: context.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecor(
    BuildContext context, {
    required String hint,
    required IconData prefixIcon,
    required Color accentColor,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: context.inputFill,
      prefixIcon: Icon(prefixIcon, color: context.textTertiary, size: 18),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PayHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PayHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.studentAmber.withOpacity(0.12), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.cardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.inputBorder),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back,
                  color: context.textPrimary,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String icon, title, subtitle, badgeLabel;
  final Color accentColor, badgeColor;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.badgeLabel,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.surfaceBorder),
          boxShadow: context.isDark
              ? null
              : [
                  BoxShadow(
                    color: accentColor.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withOpacity(0.25)),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StatusBadge(label: badgeLabel, color: badgeColor),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  final _DriverPaymentInfo driver;
  final String platform, accountName, number, amount;

  const _DriverInfoCard({
    required this.driver,
    required this.platform,
    required this.accountName,
    required this.number,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final isJazz = platform == 'jazzcash';
    final accentColor = isJazz
        ? const Color(0xFFD3290F)
        : const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isJazz ? '🎵' : '🟢',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isJazz ? 'JazzCash' : 'EasyPaisa',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    AppStrings.t('driver_account'),
                    style: TextStyle(color: context.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: AppStrings.t('driver_name_lbl'),
            value: driver.driverName,
          ),
          const SizedBox(height: 8),
          _InfoRow(label: AppStrings.t('account_name_lbl'), value: accountName),
          const SizedBox(height: 8),
          _InfoRow(
            label: AppStrings.t('account_number_lbl'),
            value: number,
            copyable: true,
          ),
          const SizedBox(height: 8),
          _InfoRow(label: AppStrings.t('bus_lbl'), value: driver.busNumber),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.t('send_exactly'),
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool copyable;

  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 12),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (copyable) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.t('copied')),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 12,
                    color: AppTheme.info,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label, imagePath;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withOpacity(0.12)
                : context.cardBgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accentColor : context.surfaceBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                imagePath,
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) =>
                    Text(label[0], style: TextStyle(color: accentColor)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? accentColor : context.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  final String number, name, expiry, brand;

  const _CardPreview({
    required this.number,
    required this.name,
    required this.expiry,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 185,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.parentGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.parentPurple.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                brand,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.wifi_rounded, color: Colors.white54, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t('card_name_lbl'),
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                  Text(
                    expiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  final bool loading;

  const _GradientButton({
    required this.label,
    required this.gradient,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SubmittedConfirmation extends StatelessWidget {
  final String icon, title, subtitle, actionLabel;
  final Color accentColor;
  final List<_ConfirmLine> lines;
  final VoidCallback onAction;

  const _SubmittedConfirmation({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.lines,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: lines
                  .map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SummaryRow(l.label, l.value),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),
          _GradientButton(
            label: actionLabel,
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withOpacity(0.75)],
            ),
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _ConfirmLine {
  final String label, value;
  const _ConfirmLine(this.label, this.value);
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool highlight;

  const _SummaryRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        highlight
            ? ShaderMask(
                shaderCallback: (b) => AppTheme.studentGradient.createShader(b),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Text input formatters
// ─────────────────────────────────────────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final digits = next.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final digits = next.text.replaceAll('/', '');
    if (digits.length >= 3) {
      final str = '${digits.substring(0, 2)}/${digits.substring(2)}';
      return next.copyWith(
        text: str,
        selection: TextSelection.collapsed(offset: str.length),
      );
    }
    return next.copyWith(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
