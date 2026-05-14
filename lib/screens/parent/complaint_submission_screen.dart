import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ComplaintSubmissionScreen extends StatefulWidget {
  const ComplaintSubmissionScreen({super.key});

  @override
  State<ComplaintSubmissionScreen> createState() =>
      _ComplaintSubmissionScreenState();
}

class _ComplaintSubmissionScreenState extends State<ComplaintSubmissionScreen> {
  String? _complaintType;
  String? _relatedTo;
  final _descriptionCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _submitted = false;
  bool _loading = false;

  final List<String> _complaintTypes = [
    'Driver Behavior',
    'Delay Issue',
    'Safety Concern',
    'Vehicle Cleanliness',
    'Route Issue',
    'Missing Pickup',
    'Other',
  ];

  final List<String> _relatedToOptions = [
    'Morning Route',
    'Evening Route',
    'General Service',
  ];

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _contactCtrl.text = '+92 '; // Default Pakistan code
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _descriptionCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  Future<void> _submitComplaint() async {
    if (_complaintType == null ||
        _relatedTo == null ||
        _descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    // Simulate submission delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _loading = false;
        _submitted = true;
      });

      // Auto-navigate after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        body: Container(
          decoration: context.scaffoldBg,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('✅', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Complaint Submitted',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you for reporting this issue. Our admin team will review and take action within 24-48 hours.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.parentPurple,
                              AppTheme.parentAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Back to Support',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.parentPurple.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Complaint',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Help us improve the service',
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

              // ── Form ───────────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Complaint Type
                      Text(
                        'Complaint Type *',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _complaintTypes.map((type) {
                          final selected = _complaintType == type;
                          return GestureDetector(
                            onTap: () => setState(() => _complaintType = type),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.parentPurple
                                    : context.cardBgElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? Colors.transparent
                                      : context.surfaceBorder,
                                ),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : context.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Related To
                      Text(
                        'Related To *',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.surfaceBorder),
                        ),
                        child: DropdownButton<String>(
                          value: _relatedTo,
                          hint: Text(
                            'Select option',
                            style: TextStyle(color: context.textTertiary),
                          ),
                          underline: const SizedBox(),
                          isExpanded: true,
                          dropdownColor: context.cardBg,
                          items: _relatedToOptions.map((option) {
                            return DropdownMenuItem(
                              value: option,
                              child: Text(
                                option,
                                style: TextStyle(color: context.textPrimary),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _relatedTo = value),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'Description *',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionCtrl,
                        maxLines: 5,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Please describe the issue in detail...',
                          hintStyle: TextStyle(color: context.textTertiary),
                          filled: true,
                          fillColor: context.cardBgElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.surfaceBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.surfaceBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.parentPurple,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Contact Info
                      Text(
                        'Your Contact (Optional)',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _contactCtrl,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Phone number',
                          hintStyle: TextStyle(color: context.textTertiary),
                          filled: true,
                          fillColor: context.cardBgElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.surfaceBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.surfaceBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.parentPurple,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Info box
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Text('ℹ️', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your complaint will be reviewed by our admin team and appropriate action will be taken.',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Submit button ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _loading ? null : _submitComplaint,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _loading
                            ? [Colors.grey, Colors.grey]
                            : [AppTheme.parentPurple, AppTheme.parentAccent],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Submit Complaint',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
}
