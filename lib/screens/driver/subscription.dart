import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../app/subscription_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverSubscriptionScreen extends StatelessWidget {
  const DriverSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: context.scaffoldBg,
        child: Column(
          children: [
            AppBar(
              title: Text(AppStrings.t('subscription')),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: context.textPrimary,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rebuilds whenever the shared plan changes elsewhere in
                    // the app (e.g. the parent/student subscription screen),
                    // so the badge below never disagrees with the real state.
                    ListenableBuilder(
                      listenable: SubscriptionProvider.instance,
                      builder: (context, _) => _buildActivePlan(context),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'UPGRADE YOUR PLAN',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // `isCurrent` used to be a hardcoded true/false pair —
                    // whatever the real plan was, "Standard Driver" always
                    // claimed to be it. There is no driver-specific tier
                    // inside `SubscriptionProvider` (it models the
                    // family/free/trial/premium plans parents and students
                    // choose), so this maps its two ends onto these two
                    // driver tiers: `premium`/`family` reads as the paid
                    // "Pro" tier, everything else as "Standard".
                    ListenableBuilder(
                      listenable: SubscriptionProvider.instance,
                      builder: (context, _) {
                        final isPro = const {
                          'premium',
                          'family',
                        }.contains(SubscriptionProvider.instance.plan);
                        return Column(
                          children: [
                            _buildPlanCard(
                              context,
                              title: 'Standard Driver',
                              price: 'Rs. 500/mo',
                              features: const [
                                'Basic route management',
                                'Student attendance',
                                'Daily trip history',
                              ],
                              isCurrent: !isPro,
                            ),
                            const SizedBox(height: 16),
                            _buildPlanCard(
                              context,
                              title: 'Pro Driver',
                              price: 'Rs. 1,200/mo',
                              features: const [
                                'Advanced performance analytics',
                                'Priority pickup requests',
                                'Detailed student feedback',
                                'Fuel consumption tracker',
                              ],
                              isCurrent: isPro,
                              accentColor: AppTheme.driverCyan,
                            ),
                          ],
                        );
                      },
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

  Widget _buildActivePlan(BuildContext context) {
    return GlassCard(
      gradient: LinearGradient(
        colors: [
          AppTheme.driverCyan.withValues(alpha: 0.15),
          AppTheme.driverCyan.withValues(alpha: 0.05),
        ],
      ),
      borderColor: AppTheme.driverCyan.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.driverCyan.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, color: AppTheme.driverCyan),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${SubscriptionProvider.instance.planDisplayName} Plan',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppStrings.t('subscription_active'),
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next billing date:',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              Text(
                'Oct 24, 2024',
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
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    required bool isCurrent,
    Color accentColor = Colors.grey,
  }) {
    return GlassCard(
      // Two of these render side by side as the bulk of this page's scroll
      // content, so the blur would be recomposited on every scroll frame for
      // no benefit over the flat card below — unlike the single, mostly
      // static plan summary above, which keeps its blur.
      enableBlur: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CURRENT',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: TextStyle(
              color: isCurrent ? context.textPrimary : accentColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    f,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!isCurrent)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Upgrade Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// No local extension needed, using theme/app_theme.dart instead.
