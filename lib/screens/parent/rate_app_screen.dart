import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class RateAppScreen extends StatefulWidget {
  const RateAppScreen({super.key});

  @override
  State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> {
  int _stars = 0;
  final _ctrl = TextEditingController();
  bool _submitted = false;

  List<String> get _starLabels => [
    '',
    AppStrings.t('star_poor'),
    AppStrings.t('star_fair'),
    AppStrings.t('star_good'),
    AppStrings.t('star_very_good'),
    AppStrings.t('star_excellent'),
  ];

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() => setState(() {});

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _ctrl.dispose();
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
                      AppStrings.t('rate_app_title'),
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
                  child: _submitted
                      ? _ThankYouView(stars: _stars)
                      : Column(
                          children: [
                            const SizedBox(height: 10),
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/images/profile_page/rating.png',
                                    width: 66,
                                    height: 66,
                                    filterQuality: FilterQuality.high,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    AppStrings.t('enjoying_transitpro'),
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AppStrings.t('feedback_helps'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Star row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (i) {
                                      final filled = i < _stars;
                                      return GestureDetector(
                                        onTap: () =>
                                            setState(() => _stars = i + 1),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: AnimatedScale(
                                            scale: filled ? 1.15 : 1.0,
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            child: Icon(
                                              Icons.star_rounded,
                                              size: 44,
                                              color: filled
                                                  ? const Color(0xFFF59E0B)
                                                  : context.surfaceBorder,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_stars > 0)
                                    Text(
                                      _starLabels[_stars],
                                      style: TextStyle(
                                        color: const Color(0xFFF59E0B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.t('leave_comment'),
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: context.inputFill,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: context.inputBorder,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _ctrl,
                                      maxLines: 4,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: AppStrings.t('tell_us_what'),
                                        hintStyle: TextStyle(
                                          color: context.textTertiary,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            GestureDetector(
                              onTap: _stars == 0
                                  ? null
                                  : () => setState(() => _submitted = true),
                              child: AnimatedOpacity(
                                opacity: _stars == 0 ? 0.5 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.parentGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      AppStrings.t('submit_rating'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
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

class _ThankYouView extends StatelessWidget {
  final int stars;
  const _ThankYouView({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: AppTheme.parentGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check, color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${AppStrings.t('thank_you')} 🎉',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You rated us $stars star${stars == 1 ? '' : 's'}.',
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.t('better_app'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.parentGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                AppStrings.t('back_to_profile'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
