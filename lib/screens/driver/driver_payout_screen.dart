import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/session_service.dart';
import '../../data/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// Where families pay this driver: a bank account and any mobile wallets.
///
/// What is saved here is exactly what a family sees on their payment screen,
/// so they can send the money themselves and attach a screenshot. The app
/// moves no money; the driver checks their own account and marks each
/// payment received or not.
class DriverPayoutScreen extends StatefulWidget {
  const DriverPayoutScreen({super.key});

  @override
  State<DriverPayoutScreen> createState() => _DriverPayoutScreenState();
}

/// Wallets offered in the picker; anything else is typed in.
const _kWalletProviders = ['JazzCash', 'Easypaisa', 'NayaPay', 'SadaPay'];

class _WalletForm {
  String provider;
  final name = TextEditingController();
  final number = TextEditingController();
  _WalletForm(this.provider, {String name = '', String number = ''}) {
    this.name.text = name;
    this.number.text = number;
  }
  void dispose() {
    name.dispose();
    number.dispose();
  }
}

class _DriverPayoutScreenState extends State<DriverPayoutScreen> {
  final _bankName = TextEditingController();
  final _accountTitle = TextEditingController();
  final _accountNumber = TextEditingController();
  final _wallets = <_WalletForm>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final payout = SessionService.instance.driver.value?.payout;
    if (payout != null) {
      _bankName.text = payout.bankName;
      _accountTitle.text = payout.accountTitle;
      _accountNumber.text = payout.accountNumber;
      for (final w in payout.wallets) {
        _wallets.add(_WalletForm(w.provider, name: w.name, number: w.number));
      }
    }
    if (_wallets.isEmpty) _wallets.add(_WalletForm(_kWalletProviders.first));
  }

  @override
  void dispose() {
    _bankName.dispose();
    _accountTitle.dispose();
    _accountNumber.dispose();
    for (final w in _wallets) {
      w.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final uid = SessionService.instance.uid;
    if (uid == null) return;
    final wallets = [
      for (final w in _wallets)
        if (w.number.text.trim().isNotEmpty)
          WalletAccount(
            provider: w.provider,
            name: w.name.text.trim(),
            number: w.number.text.trim(),
          ),
    ];
    final payout = PayoutDetails(
      bankName: _bankName.text.trim(),
      accountTitle: _accountTitle.text.trim(),
      accountNumber: _accountNumber.text.trim(),
      wallets: wallets,
    );
    if (payout.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a bank account or at least one wallet number.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await UserRepository.instance.updateDriver(uid, {
        'payout': payout.toMap(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved. Families will see these when they pay.'),
          backgroundColor: AppTheme.success,
        ),
      );
      context.pop();
    } catch (e) {
      debugPrint('saving payout details failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Check your connection.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _field(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.textHint),
    filled: true,
    fillColor: context.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.inputBorder),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 12),
    child: Text(
      text,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment details'),
        backgroundColor: context.cardBgElevated,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: context.scaffoldBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(
              'Families pay you directly and send a screenshot. You check '
              'your account and mark each payment received or not.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            GlassCard(
              enableBlur: false,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏦  Bank account',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _label('BANK NAME'),
                  TextField(
                    controller: _bankName,
                    style: TextStyle(color: context.textPrimary),
                    decoration: _field('e.g. Meezan Bank'),
                  ),
                  _label('ACCOUNT TITLE'),
                  TextField(
                    controller: _accountTitle,
                    style: TextStyle(color: context.textPrimary),
                    decoration: _field('Name on the account'),
                  ),
                  _label('ACCOUNT NUMBER / IBAN'),
                  TextField(
                    controller: _accountNumber,
                    style: TextStyle(color: context.textPrimary),
                    decoration: _field('e.g. PK36MEZN0001...'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              enableBlur: false,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱  Mobile wallets',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (var i = 0; i < _wallets.length; i++) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                _kWalletProviders.contains(_wallets[i].provider)
                                ? _wallets[i].provider
                                : _kWalletProviders.first,
                            items: [
                              for (final p in _kWalletProviders)
                                DropdownMenuItem(value: p, child: Text(p)),
                            ],
                            onChanged: (v) =>
                                setState(() => _wallets[i].provider = v!),
                            decoration: _field('Wallet'),
                          ),
                        ),
                        if (_wallets.length > 1)
                          IconButton(
                            onPressed: () {
                              final w = _wallets[i];
                              setState(() => _wallets.removeAt(i));
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => w.dispose(),
                              );
                            },
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: AppTheme.error,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wallets[i].name,
                      style: TextStyle(color: context.textPrimary),
                      decoration: _field('Account name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wallets[i].number,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: context.textPrimary),
                      decoration: _field('Number, e.g. 0300 1234567'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _wallets.add(_WalletForm(_kWalletProviders.first)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add another wallet'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.driverCyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
