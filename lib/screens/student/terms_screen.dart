import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t('terms_lbl'),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.t('terms_content'),
                style: TextStyle(color: context.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Text(
                'Version 2.4.1',
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
