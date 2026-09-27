import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../app/subscription_provider.dart';
import '../../data/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime d) =>
    '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Guards the expiry dialog so it pops once per visit to this screen
  // rather than every time `_onUserChanged` fires a rebuild.
  bool _shownExpiredDialog = false;

  void _onProviderChanged() => setState(() {});

  void _onUserChanged() {
    setState(() {});
    _maybeShowExpiredDialog();
  }

  @override
  void initState() {
    super.initState();
    SubscriptionProvider.instance.addListener(_onProviderChanged);
    LanguageProvider.instance.addListener(_onLangChanged);
    SessionService.instance.user.addListener(_onUserChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowExpiredDialog(),
    );
  }

  void _onLangChanged() => setState(() {});

  @override
  void dispose() {
    SubscriptionProvider.instance.removeListener(_onProviderChanged);
    LanguageProvider.instance.removeListener(_onLangChanged);
    SessionService.instance.user.removeListener(_onUserChanged);
    super.dispose();
  }

  void _maybeShowExpiredDialog() {
    if (_shownExpiredDialog || !mounted) return;
    final user = SessionService.instance.user.value;
    final trialEndDate = user?.trialEndDate;
    final expired =
        user?.subscriptionStatus == 'trial' &&
        trialEndDate != null &&
        DateTime.now().isAfter(trialEndDate);
    if (!expired) return;
    _shownExpiredDialog = true;
    showDialog(context: context, builder: (_) => const _TrialExpiredDialog());
  }

  Future<void> _buySubscription() async {
    final uid = SessionService.instance.uid;
    if (uid == null) return;
    SubscriptionProvider.instance.setPlan('premium');
    await UserRepository.instance.updateUser(uid, {
      'subscriptionStatus': 'active',
      'trialEndDate': DateTime.now().add(const Duration(days: 30)),
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${AppStrings.t('buy_subscription')}: ${SubscriptionProvider.instance.planDisplayName}',
        ),
        backgroundColor: AppTheme.parentPurple,
        duration: const Duration(seconds: 2),
      ),
    );
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
                      AppStrings.t('subscription_title'),
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
                  child: Builder(
                    builder: (context) {
                      final user = SessionService.instance.user.value;
                      final isTrial = user?.subscriptionStatus != 'active';
                      final periodDate = user?.trialEndDate;
                      final statusTitle = isTrial
                          ? AppStrings.t('free_trial_status')
                          : AppStrings.t('active_subscription_status');
                      final statusSubtitle = periodDate == null
                          ? ''
                          : '${isTrial ? AppStrings.t('trial_ends_label') : AppStrings.t('renews_label')} ${_formatDate(periodDate)}';
                      final badgeColor = isTrial
                          ? AppTheme.warning
                          : AppTheme.success;
                      final badgeLabel = isTrial
                          ? AppStrings.t('trial_badge')
                          : AppStrings.t('active');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current plan banner — reads live subscription
                          // state off `SessionService.instance.user` (the
                          // Firestore-backed record) rather than the purely
                          // local `SubscriptionProvider`, so it reflects what
                          // was actually granted at sign-up or bought, not
                          // just this session's UI selection.
                          GlassCard(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.parentPurple.withValues(alpha: 0.3),
                                AppTheme.parentIndigo.withValues(alpha: 0.15),
                              ],
                            ),
                            borderColor: AppTheme.parentPurple.withValues(
                              alpha: 0.4,
                            ),
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
                                            statusTitle,
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            statusSubtitle,
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
                                        color: badgeColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: badgeColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        badgeLabel,
                                        style: TextStyle(
                                          color: badgeColor,
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
                            AppStrings.t('change_plan'),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Single plan card — nothing to select between anymore,
                          // so tapping it directly buys/activates the plan
                          // instead of staging a choice for a separate confirm
                          // button.
                          _PlanCard(
                            name: AppStrings.t('buy_subscription'),
                            price: 'Rs. 299/mo',
                            badge: isTrial
                                ? null
                                : AppStrings.t('current_badge'),
                            features: [
                              AppStrings.t('feat_live_gps'),
                              AppStrings.t('feat_3_profiles'),
                              AppStrings.t('feat_push_sms'),
                              AppStrings.t('feat_trip_history'),
                              AppStrings.t('feat_emergency'),
                            ],
                            color: AppTheme.parentPurple,
                            onTap: isTrial ? _buySubscription : null,
                          ),
                        ],
                      );
                    },
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

class _TrialExpiredDialog extends StatelessWidget {
  const _TrialExpiredDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.cardBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_off_outlined,
                color: AppTheme.warning,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppStrings.t('trial_expired_title'),
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t('trial_expired_message'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.parentPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.t('buy_subscription')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name, price;
  final String? badge;
  final List<String> features;
  final Color color;
  final VoidCallback? onTap;

  const _PlanCard({
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
          color: context.cardBgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
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
                      color: color.withValues(alpha: 0.2),
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
            const SizedBox(height: 10),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: color.withValues(alpha: 0.8),
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
