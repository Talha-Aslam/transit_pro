import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  static const _docs = [
    _DocItem(
      icon: '🪪',
      title: 'Driving License',
      number: 'DL-2018-LHR-8821',
      issued: 'Jan 15, 2018',
      expiry: 'Jan 14, 2028',
      status: 'Verified',
      statusOk: true,
    ),
    _DocItem(
      icon: '🚌',
      title: 'Vehicle Registration',
      number: 'LHR-BUS-4221',
      issued: 'Mar 1, 2022',
      expiry: 'Feb 28, 2027',
      status: 'Verified',
      statusOk: true,
    ),
    _DocItem(
      icon: '🛡️',
      title: 'Insurance Certificate',
      number: 'INS-2025-88774',
      issued: 'Apr 1, 2025',
      expiry: 'Mar 31, 2026',
      status: 'Renew Soon',
      statusOk: false,
    ),
    _DocItem(
      icon: '📋',
      title: 'Route Permit',
      number: 'RP-LHR-A-0042',
      issued: 'Sep 1, 2024',
      expiry: 'Aug 31, 2026',
      status: 'Verified',
      statusOk: true,
    ),
    _DocItem(
      icon: '🩺',
      title: 'Medical Fitness',
      number: 'MF-2025-LHR-001',
      issued: 'Jan 10, 2025',
      expiry: 'Jan 9, 2026',
      status: 'Verified',
      statusOk: true,
    ),
    _DocItem(
      icon: '🏫',
      title: 'School Contract',
      number: 'SC-2025-LES-42',
      issued: 'Feb 1, 2025',
      expiry: 'Jan 31, 2026',
      status: 'Active',
      statusOk: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final verified = _docs.where((d) => d.statusOk).length;
    final total = _docs.length;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withOpacity(0.2),
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
                    const SizedBox(width: 14),
                    Text(
                      AppStrings.t('documents_license'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      // Summary card
                      GlassCard(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.driverCyan.withOpacity(0.15),
                            AppTheme.driverTeal.withOpacity(0.05),
                          ],
                        ),
                        borderColor: AppTheme.driverCyan.withOpacity(0.3),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SummaryPill(
                              icon: '✅',
                              value: '$verified',
                              label: 'Verified',
                              color: AppTheme.successLight,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: context.cardBgElevated,
                            ),
                            _SummaryPill(
                              icon: '⚠️',
                              value: '${total - verified}',
                              label: 'Action Needed',
                              color: AppTheme.warningLight,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: context.cardBgElevated,
                            ),
                            _SummaryPill(
                              icon: '📋',
                              value: '$total',
                              label: 'Total Docs',
                              color: AppTheme.driverAccent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Document cards
                      ...List.generate(_docs.length, (i) {
                        final doc = _docs[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.driverCyan.withOpacity(
                                          0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          doc.icon,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.title,
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            doc.number,
                                            style: TextStyle(
                                              color: context.textTertiary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: doc.statusOk
                                            ? AppTheme.success.withOpacity(0.15)
                                            : AppTheme.warning.withOpacity(
                                                0.15,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: doc.statusOk
                                              ? AppTheme.success.withOpacity(
                                                  0.3,
                                                )
                                              : AppTheme.warning.withOpacity(
                                                  0.3,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        doc.status,
                                        style: TextStyle(
                                          color: doc.statusOk
                                              ? AppTheme.successLight
                                              : AppTheme.warningLight,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 1,
                                  color: context.cardBgElevated,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DateChip(
                                        label: 'Issued',
                                        value: doc.issued,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _DateChip(
                                        label: 'Expiry',
                                        value: doc.expiry,
                                        warn: !doc.statusOk,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _DocItem {
  final String icon, title, number, issued, expiry, status;
  final bool statusOk;

  const _DocItem({
    required this.icon,
    required this.title,
    required this.number,
    required this.issued,
    required this.expiry,
    required this.status,
    required this.statusOk,
  });
}

class _SummaryPill extends StatelessWidget {
  final String icon, value, label;
  final Color color;
  const _SummaryPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label, value;
  final bool warn;
  const _DateChip({
    required this.label,
    required this.value,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warn
            ? AppTheme.warning.withOpacity(0.08)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: warn ? AppTheme.warningLight : context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
