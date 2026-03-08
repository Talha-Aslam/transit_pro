import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _hasLength(String v) => v.length >= 8;
  bool _hasUpper(String v) => v.contains(RegExp(r'[A-Z]'));
  bool _hasDigit(String v) => v.contains(RegExp(r'[0-9]'));

  Future<void> _submit() async {
    setState(() => _error = null);
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (!_hasLength(next) || !_hasUpper(next) || !_hasDigit(next)) {
      setState(() => _error = 'New password does not meet requirements');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password changed successfully'),
        backgroundColor: AppTheme.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final newVal = _newCtrl.text;
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.parentPurple.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                      'Change Password',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🔐', style: TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            Text(
                              'Update your password',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Use a strong password with at least 8 characters.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _PasswordField(
                              ctrl: _currentCtrl,
                              hint: 'Current Password',
                              show: _showCurrent,
                              onToggle: () =>
                                  setState(() => _showCurrent = !_showCurrent),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              ctrl: _newCtrl,
                              hint: 'New Password',
                              show: _showNew,
                              onToggle: () =>
                                  setState(() => _showNew = !_showNew),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              ctrl: _confirmCtrl,
                              hint: 'Confirm New Password',
                              show: _showConfirm,
                              onToggle: () =>
                                  setState(() => _showConfirm = !_showConfirm),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Strength checklist
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password Requirements',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _Requirement(
                              label: 'At least 8 characters',
                              met: _hasLength(newVal),
                            ),
                            _Requirement(
                              label: 'At least one uppercase letter',
                              met: _hasUpper(newVal),
                            ),
                            _Requirement(
                              label: 'At least one number',
                              met: _hasDigit(newVal),
                            ),
                          ],
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: _loading ? null : _submit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.parentGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Change Password',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool show;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  const _PasswordField({
    required this.ctrl,
    required this.hint,
    required this.show,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.inputBorder),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: !show,
        onChanged: onChanged,
        style: TextStyle(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textTertiary),
          prefixIcon: Icon(
            Icons.lock_outline,
            color: context.textTertiary,
            size: 20,
          ),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: context.textTertiary,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  final String label;
  final bool met;
  const _Requirement({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: met ? AppTheme.success : context.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: met ? AppTheme.success : context.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
