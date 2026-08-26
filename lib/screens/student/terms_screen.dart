import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class TermsScreen extends StatelessWidget {
  final Color accentColor;
  const TermsScreen({super.key, this.accentColor = AppTheme.studentAmber});

  List<String> _paragraphs(String content) {
    return content
        .split('\n\n')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String _sectionTitle(String text, int index) {
    if (index == 0) return 'Overview';
    final match = RegExp(r'^\s*(\d+)\.?\s*(.+)$').firstMatch(text);
    if (match != null) {
      return 'Section ${match.group(1)}';
    }
    // The intro paragraph (index 1) has no leading digit, so it would
    // otherwise fall through to 'Section 2' and collide with the real
    // "2. Privacy" section below it.
    if (index == 1) return 'Introduction';
    return 'Section ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final sections = _paragraphs(AppStrings.t('terms_content'));
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('terms_lbl')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.textPrimary,
        automaticallyImplyLeading: true,
      ),
      body: Container(
        decoration: context.scaffoldBg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(18),
                borderRadius: 24,
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    AppTheme.info.withValues(alpha: 0.06),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('📄', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('terms_lbl'),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please read these terms carefully before using TransportKid.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(
                                icon: Icons.verified_rounded,
                                label: 'TransportKid v2.4.1',
                                color: accentColor,
                              ),
                              _MetaChip(
                                icon: Icons.update_rounded,
                                label: 'Last updated: May 2026',
                                color: AppTheme.driverCyan,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(sections.length, (index) {
                final section = sections[index];
                final title = _sectionTitle(section, index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    // Built inside List.generate — one card per terms
                    // section, so this is a repeated-item list, not a
                    // one-off card.
                    enableBlur: false,
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.studentAmber.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          section,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Text(
                'By continuing to use TransportKid, you acknowledge that you have read and understood these terms.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
