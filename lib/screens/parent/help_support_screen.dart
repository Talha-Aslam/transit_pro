import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _openFaq;

  final _faqs = const [
    _Faq(
      q: 'How do I track my child\'s bus in real time?',
      a: 'Go to the "Live Tracking" tab from the bottom navigation bar. The map will show the bus\'s current position and estimated arrival time at each stop.',
    ),
    _Faq(
      q: 'How do I add another child to my account?',
      a: 'Open the Profile tab, scroll to the Children section, and tap the "+" button. Fill in your child\'s name, grade, school and bus details.',
    ),
    _Faq(
      q: 'Why am I not receiving notifications?',
      a: 'Make sure notifications are enabled for TransitPro in your device Settings. You can also check alert preferences inside App Settings on the Profile tab.',
    ),
    _Faq(
      q: 'How do I update my child\'s bus route?',
      a: 'Tap the child card on the Profile tab, then select "Edit Info". Update the Bus Number, Route, or Stop fields and tap Save.',
    ),
    _Faq(
      q: 'How do I change my emergency contacts?',
      a: 'Go to Profile → Emergency Contacts. You can add, edit or remove contacts from there.',
    ),
    _Faq(
      q: 'What does the Premium plan include?',
      a: 'Premium includes live GPS tracking, up to 3 child profiles, push & SMS alerts, full trip history and emergency contact management.',
    ),
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
                      'Help & Support',
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
                              label: 'Email Us',
                              value: 'support@\ntransitpro.pk',
                              color: AppTheme.info,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ContactCard(
                              icon: '📞',
                              label: 'Call Us',
                              value: '+92 300\n0000000',
                              color: AppTheme.success,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ContactCard(
                              icon: '💬',
                              label: 'Live Chat',
                              value: 'Mon–Fri\n9am–6pm',
                              color: AppTheme.parentPurple,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Text(
                            'Frequently Asked Questions',
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
                              'Send a Message',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SupportTextField(hint: 'Subject', maxLines: 1),
                            const SizedBox(height: 10),
                            _SupportTextField(
                              hint: 'Describe your issue...',
                              maxLines: 4,
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Message sent! We\'ll reply within 24h.',
                                    ),
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
                                child: const Center(
                                  child: Text(
                                    'Send Message',
                                    style: TextStyle(
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
  const _SupportTextField({required this.hint, required this.maxLines});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.inputBorder),
      ),
      child: TextField(
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
