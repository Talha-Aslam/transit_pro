import 'package:flutter/material.dart';
import '../../app/subscription_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late String _selected;

  void _onProviderChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _selected = SubscriptionProvider.instance.plan;
    SubscriptionProvider.instance.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    SubscriptionProvider.instance.removeListener(_onProviderChanged);
    super.dispose();
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
                      'Subscription',
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current plan banner
                      GlassCard(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.parentPurple.withOpacity(0.3),
                            AppTheme.parentIndigo.withOpacity(0.15),
                          ],
                        ),
                        borderColor: AppTheme.parentPurple.withOpacity(0.4),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.parentGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/profile_page/premium.png',
                                      width: 36,
                                      height: 36,
                                      filterQuality: FilterQuality.high,
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
                                        '${SubscriptionProvider.instance.planDisplayName} Plan',
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Active · Renews Apr 8, 2026',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.success.withOpacity(0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    '● Active',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'Change Plan',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Plan cards
                      _PlanCard(
                        id: 'premium',
                        selected: _selected == 'premium',
                        name: 'Premium',
                        price: 'Rs. 299/mo',
                        badge: SubscriptionProvider.instance.plan == 'premium'
                            ? 'Current'
                            : null,
                        features: const [
                          'Live GPS tracking',
                          'Up to 3 child profiles',
                          'Push + SMS alerts',
                          'Full trip history',
                          'Emergency contacts',
                        ],
                        color: AppTheme.parentPurple,
                        onTap: () => setState(() => _selected = 'premium'),
                      ),
                      const SizedBox(height: 8),
                      _PlanCard(
                        id: 'family',
                        selected: _selected == 'family',
                        name: 'Family',
                        price: 'Rs. 499/mo',
                        badge: SubscriptionProvider.instance.plan == 'family'
                            ? 'Current'
                            : 'Best Value',
                        features: const [
                          'Everything in Premium',
                          'Unlimited child profiles',
                          'Priority support',
                          'Route customisation',
                          'Driver direct chat',
                        ],
                        color: AppTheme.warning,
                        onTap: () => setState(() => _selected = 'family'),
                      ),
                      if (_selected != SubscriptionProvider.instance.plan) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            SubscriptionProvider.instance.setPlan(_selected);
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.clearSnackBars();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Switched to ${SubscriptionProvider.instance.planDisplayName} plan',
                                ),
                                backgroundColor: AppTheme.parentPurple,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.parentGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'Switch Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
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

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.parentPurple.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: context.textSecondary, fontSize: 11),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String id, name, price;
  final String? badge;
  final bool selected;
  final List<String> features;
  final Color color;
  final VoidCallback onTap;

  const _PlanCard({
    required this.id,
    required this.selected,
    required this.name,
    required this.price,
    required this.features,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : context.cardBgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : context.surfaceBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        price,
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color : Colors.transparent,
                    border: Border.all(
                      color: selected ? color : context.surfaceBorder,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: color.withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
