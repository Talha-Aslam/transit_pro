import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
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
    LanguageProvider.instance.removeListener(_onLangChanged);
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _hasLength(String v) => v.length >= 8;
  bool _hasUpper(String v) => v.contains(RegExp(r'[A-Z]'));
  bool _hasDigit(String v) => v.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String v) =>
      v.contains(RegExp(r'[!@#\$%\^&\*\(\),.?":{}|<>_\-]'));

  int get _strength {
    final v = _newCtrl.text;
    return [
      _hasLength(v),
      _hasUpper(v),
      _hasDigit(v),
      _hasSpecial(v),
    ].where((b) => b).length;
  }

  Color get _strengthColor {
    switch (_strength) {
      case 1:
        return AppTheme.errorLight;
      case 2:
        return AppTheme.warningLight;
      case 3:
        return const Color(0xFF84CC16);
      case 4:
        return AppTheme.successLight;
      default:
        return Colors.transparent;
    }
  }

  String get _strengthLabel {
    switch (_strength) {
      case 1:
        return AppStrings.t('pwd_weak');
      case 2:
        return AppStrings.t('pwd_fair');
      case 3:
        return AppStrings.t('pwd_good');
      case 4:
        return AppStrings.t('pwd_strong');
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() => setState(() {});

  Future<void> _submit() async {
    setState(() => _error = null);
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _error = AppStrings.t('fill_all_fields'));
      return;
    }
    if (!_hasLength(next) ||
        !_hasUpper(next) ||
        !_hasDigit(next) ||
        !_hasSpecial(next)) {
      setState(() => _error = AppStrings.t('pwd_not_meet'));
      return;
    }
    if (next != confirm) {
      setState(() => _error = AppStrings.t('pwd_no_match'));
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.t('pwd_changed')),
        backgroundColor: AppTheme.success,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
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
                      onTap: () => context.pop(),
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
                      AppStrings.t('change_password_title'),
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
                              AppStrings.t('update_password'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppStrings.t('strong_password'),
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
                              hint: AppStrings.t('current_password'),
                              show: _showCurrent,
                              onToggle: () =>
                                  setState(() => _showCurrent = !_showCurrent),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              ctrl: _newCtrl,
                              hint: AppStrings.t('new_password'),
                              show: _showNew,
                              onToggle: () =>
                                  setState(() => _showNew = !_showNew),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              ctrl: _confirmCtrl,
                              hint: AppStrings.t('confirm_new_password'),
                              show: _showConfirm,
                              onToggle: () =>
                                  setState(() => _showConfirm = !_showConfirm),
                              onChanged: (_) => setState(() {}),
                            ),
                            if (_confirmCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const SizedBox(width: 2),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: Icon(
                                      _confirmCtrl.text == _newCtrl.text
                                          ? Icons.check_circle
                                          : Icons.cancel_outlined,
                                      key: ValueKey(
                                        _confirmCtrl.text == _newCtrl.text,
                                      ),
                                      size: 14,
                                      color: _confirmCtrl.text == _newCtrl.text
                                          ? AppTheme.success
                                          : AppTheme.errorLight,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 250),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _confirmCtrl.text == _newCtrl.text
                                          ? AppTheme.success
                                          : AppTheme.errorLight,
                                    ),
                                    child: Text(
                                      _confirmCtrl.text == _newCtrl.text
                                          ? AppStrings.t('passwords_match')
                                          : AppStrings.t('pwd_no_match'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    AppStrings.t('password_requirements'),
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (_strength > 0)
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: TextStyle(
                                      color: _strengthColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    child: Text(_strengthLabel),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Animated strength bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 5,
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                  LayoutBuilder(
                                    builder: (ctx, box) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      curve: Curves.easeOut,
                                      height: 5,
                                      width: box.maxWidth * (_strength / 4),
                                      color: _strengthColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Requirement(
                              label: AppStrings.t('min_8_chars'),
                              met: _hasLength(_newCtrl.text),
                            ),
                            _Requirement(
                              label: AppStrings.t('uppercase'),
                              met: _hasUpper(_newCtrl.text),
                            ),
                            _Requirement(
                              label: AppStrings.t('one_digit'),
                              met: _hasDigit(_newCtrl.text),
                            ),
                            _Requirement(
                              label: AppStrings.t('special_char'),
                              met: _hasSpecial(_newCtrl.text),
                              isLast: true,
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
                                : Text(
                                    AppStrings.t('update_password_btn'),
                                    style: const TextStyle(
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
  final bool isLast;
  const _Requirement({
    required this.label,
    required this.met,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(met),
              size: 15,
              color: met ? AppTheme.success : context.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: met ? AppTheme.success : context.textSecondary,
              fontSize: 12,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
