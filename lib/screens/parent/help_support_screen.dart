import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class HelpSupportScreen extends StatefulWidget {
  final Color accentColor;
  const HelpSupportScreen({
    super.key,
    this.accentColor = AppTheme.parentPurple,
  });

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _openFaq;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@transitpro.pk',
      queryParameters: {'subject': 'Support Request'},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: '+923000000000');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openLiveChat() {
    context.push('/parent/live-chat');
  }

  List<_Faq> get _faqs => [
    _Faq(q: AppStrings.t('faq_q1'), a: AppStrings.t('faq_a1')),
    _Faq(q: AppStrings.t('faq_q2'), a: AppStrings.t('faq_a2')),
    _Faq(q: AppStrings.t('faq_q3'), a: AppStrings.t('faq_a3')),
    _Faq(q: AppStrings.t('faq_q4'), a: AppStrings.t('faq_a4')),
    _Faq(q: AppStrings.t('faq_q5'), a: AppStrings.t('faq_a5')),
    _Faq(q: AppStrings.t('faq_q6'), a: AppStrings.t('faq_a6')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.accentColor.withOpacity(0.2),
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
                      AppStrings.t('help_and_support'),
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
                      // Contact cards
                      Row(
                        children: [
                          Expanded(
                            child: _ContactCard(
                              icon: '📧',
                              label: AppStrings.t('email_us'),
                              value: 'support@\ntransitpro.pk',
                              color: AppTheme.info,
                              onTap: _launchEmail,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ContactCard(
                              icon: '📞',
                              label: AppStrings.t('call_us'),
                              value: '+92 300\n0000000',
                              color: AppTheme.success,
                              onTap: _launchPhone,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ContactCard(
                              icon: '💬',
                              label: AppStrings.t('live_chat'),
                              value: AppStrings.t('live_chat_hours'),
                              color: widget.accentColor,
                              onTap: _openLiveChat,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Text(
                            AppStrings.t('faq'),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: _faqs.asMap().entries.map((e) {
                            final faq = e.value;
                            final open = _openFaq == e.key;
                            final isLast = e.key == _faqs.length - 1;
                            return GestureDetector(
                              onTap: () => setState(
                                () => _openFaq = open ? null : e.key,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            faq.q,
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AnimatedRotation(
                                          turns: open ? 0.5 : 0,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: Icon(
                                            Icons.keyboard_arrow_down,
                                            color: context.textSecondary,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (open)
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        14,
                                      ),
                                      child: Text(
                                        faq.a,
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  if (!isLast)
                                    Divider(
                                      height: 1,
                                      color: context.surfaceBorder,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('send_message'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SupportTextField(
                              hint: AppStrings.t('subject'),
                              maxLines: 1,
                              controller: _subjectController,
                            ),
                            const SizedBox(height: 10),
                            _SupportTextField(
                              hint: AppStrings.t('describe_issue'),
                              maxLines: 4,
                              controller: _messageController,
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () {
                                _subjectController.clear();
                                _messageController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppStrings.t('message_sent')),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.parentGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    AppStrings.t('send'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

class _Faq {
  final String q, a;
  const _Faq({required this.q, required this.a});
}

class _ContactCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTextField extends StatelessWidget {
  final String hint;
  final int maxLines;
  final TextEditingController controller;
  const _SupportTextField({
    required this.hint,
    required this.maxLines,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.inputBorder),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: context.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
