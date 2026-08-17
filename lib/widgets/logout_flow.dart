import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/auth_service.dart';
import '../theme/app_theme.dart';

/// Confirms, then really ends the session.
///
/// All three role layouts previously did this inline as:
///
/// ```dart
/// AuthService.instance.clearRole();
/// context.go('/role-select');
/// ```
///
/// which removed a SharedPreferences key and nothing else. The Firebase session
/// survived, so `isSignedIn` stayed true, the Firestore listeners kept running,
/// and relaunching the app dropped the user straight back into the dashboard
/// they thought they had left.
///
/// Sharing one implementation is what stops that drifting apart again.
Future<void> confirmAndSignOut(
  BuildContext context, {
  Color accentColor = AppTheme.parentPurple,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: dialogContext.cardBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: Text(
        'Sign out?',
        style: TextStyle(
          color: dialogContext.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'You will need to sign in again to track your journey.',
        style: TextStyle(color: dialogContext.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel', style: TextStyle(color: accentColor)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Sign out',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  if (!context.mounted) return;

  // Block interaction while the session tears down. Cancelling Firestore
  // listeners and revoking the Google grant are both awaited, and a second tap
  // during that window would run the whole thing twice.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the spinner
    context.go('/role-select');
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not sign out: $e'),
        backgroundColor: AppTheme.error,
      ),
    );
  }
}
