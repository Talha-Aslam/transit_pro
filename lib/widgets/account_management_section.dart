import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../app/account_service.dart';
import '../theme/app_theme.dart';

/// Deactivate / Delete Account: confirm-then-act flows shared by all three
/// role profile screens, the same way `confirmAndSignOut` (`logout_flow.dart`)
/// already is — so the copy and the confirm-then-act ordering can't drift
/// apart between Parent, Driver and Student.
///
/// There is deliberately no standalone "Account Management" widget here.
/// Each profile screen renders "Deactivate Account" / "Delete Account" as
/// two more rows in its own existing settings list (its own `_MenuItem` /
/// `_SettingTile`, right after Help & Support / Terms), matching that
/// list's styling exactly — a separate card for two destructive actions
/// read as visually disconnected from the rest of the screen, and gave two
/// different row-styles for what a user experiences as one list.

/// Confirms, explains the consequence, then really deactivates the account.
///
/// Mirrors `confirmAndSignOut`'s shape deliberately — same dialog structure,
/// same "leave the screen, then await teardown" ordering on success — so a
/// reader who already knows that flow recognises this one immediately.
Future<void> confirmAndDeactivateAccount(
  BuildContext context, {
  Color accentColor = AppTheme.parentPurple,
}) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Deactivate your account?',
    body:
        'Deactivating will pause your account and sign you out. Your data '
        'stays intact, and an administrator can reactivate it — this is not '
        'permanent, unlike deleting your account.',
    confirmLabel: 'Deactivate',
    confirmColor: AppTheme.warning,
    accentColor: accentColor,
  );
  if (confirmed != true || !context.mounted) return;

  await _runDestructiveAction(
    context,
    action: () => AccountService.instance.deactivate(),
    successMessage: 'Your account has been deactivated.',
  );
}

/// Confirms — twice as emphatically as deactivation — then permanently
/// deletes the account.
Future<void> confirmAndDeleteAccount(
  BuildContext context, {
  required UserRole role,
  Color accentColor = AppTheme.parentPurple,
}) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Delete your account?',
    body:
        'Deleting is permanent: your login, profile, and account data are '
        'removed and cannot be recovered. Deactivating is the reversible '
        'option, if you just need a break.',
    confirmLabel: 'Delete permanently',
    confirmColor: AppTheme.error,
    accentColor: accentColor,
  );
  if (confirmed != true || !context.mounted) return;

  await _runDestructiveAction(
    context,
    action: () => AccountService.instance.delete(role: role),
    successMessage: 'Your account has been deleted.',
  );
}

/// One reusable `showDialog`, parameterised by copy and color, rather than
/// two near-identical `AlertDialog`s drifting apart over time the way the
/// prototype's screens used to (see `logout_flow.dart`'s own doc comment for
/// that exact failure mode with three separate sign-out implementations).
Future<bool?> _confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required Color confirmColor,
  required Color accentColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: dialogContext.cardBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: TextStyle(
          color: dialogContext.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(body, style: TextStyle(color: dialogContext.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel', style: TextStyle(color: accentColor)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// Runs [action] behind a non-dismissible spinner, then either routes to
/// `/role-select` (the same destination `confirmAndSignOut` uses — both end
/// the session the same way) or surfaces [AccountException.message].
Future<void> _runDestructiveAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String successMessage,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await action();
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the spinner
    context.go('/role-select');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  } on AccountException catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the spinner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the spinner
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Something went wrong. Please try again.'),
        backgroundColor: AppTheme.error,
      ),
    );
  }
}
