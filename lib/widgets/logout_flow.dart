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

  // Leave the signed-in screens first, *then* tear the session down.
  // `AuthService.signOut()` cancels every Firestore listener and revokes the
  // Google grant — real network round trips — and awaiting that under a
  // blocking spinner meant the (often map- or image-heavy) screen underneath
  // had to stay mounted and get disposed in the middle of it. That's what
  // made logout visibly freeze every time. Navigating away first lets all of
  // that teardown happen behind the lightweight role-select screen instead.
  context.go('/role-select');
  try {
    await AuthService.instance.signOut();
  } catch (e) {
    debugPrint('Sign out failed: $e');
  }
}
