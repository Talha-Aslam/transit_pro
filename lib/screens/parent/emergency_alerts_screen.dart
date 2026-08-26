import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../app/notification_service.dart';
import '../../app/parent_data_service.dart';
import '../../theme/app_theme.dart';

class EmergencyAlertsScreen extends StatefulWidget {
  const EmergencyAlertsScreen({super.key});

  @override
  State<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends State<EmergencyAlertsScreen> {
  final _notifSvc = NotificationService.instance;

  /// `AppNotification.id` values the user has tapped "Mark Resolved" on this
  /// session. Needed alongside `n.read`: [NotificationService.markRead] can
  /// only persist a read flag for notifications with a Firestore document
  /// behind them (`docId != null`); a device-local alert (e.g. a geofence
  /// "approaching" alert, see [NotificationService.fromGeofence]) has nowhere
  /// to persist to, so it's tracked here instead so it still visibly moves to
  /// "Resolved" for the rest of this session.
  final Set<int> _locallyResolvedIds = {};

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _notifSvc.history.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _notifSvc.history.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});
  void _onHistoryChanged() => setState(() {});

  bool _isResolved(AppNotification n) =>
      n.read || _locallyResolvedIds.contains(n.id);

  void _markAsResolved(AppNotification n) {
    setState(() => _locallyResolvedIds.add(n.id));
    // Best-effort: persists for a remote (Firestore-backed) alert; a no-op
    // for a local one, which is why the local set above is the source of
    // truth for the UI split.
    _notifSvc.markRead(n);

    _notifSvc.show(
      title: '✅ Alert Resolved',
      body: 'Emergency alert has been marked as resolved.',
      type: 'alert_resolved',
      icon: '✅',
      color: AppTheme.success,
    );
  }

  void _contactDriver(String driverName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContactDriverSheet(driverName: driverName),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Real alert-type notifications from the same inbox
    // parent_notifications.dart streams, filtered to the 'alert' bucket the
    // service already classifies boarding/delay/emergency events into (see
    // NotificationService._uiTypeFor) — no more invented breakdown/route
    // change/accident entries.
    final alerts = _notifSvc.history.value
        .where((n) => n.type == 'alert')
        .toList();
    final activeAlerts = alerts.where((n) => !_isResolved(n)).toList();
    final resolvedAlerts = alerts.where(_isResolved).toList();
    final driverName = ParentDataService.instance.selectedChild?.driver
                .trim()
                .isNotEmpty ==
            true
        ? ParentDataService.instance.selectedChild!.driver.trim()
        : 'Driver';

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Alerts',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${activeAlerts.length} active, ${resolvedAlerts.length} resolved',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Alerts list ────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeAlerts.isNotEmpty) ...[
                        Text(
                          'Active Alerts',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...activeAlerts.map((alert) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AlertCard(
                              alert: alert,
                              onResolve: () => _markAsResolved(alert),
                              onContact: () => _contactDriver(driverName),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                      if (resolvedAlerts.isNotEmpty) ...[
                        Text(
                          'Resolved Alerts',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...resolvedAlerts.map((alert) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.cardBg.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: context.surfaceBorder.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    alert.icon,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              alert.title,
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              '✓',
                                              style: TextStyle(
                                                color: AppTheme.success,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${alert.date} · ${alert.time}',
                                          style: TextStyle(
                                            color: context.textTertiary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      if (activeAlerts.isEmpty && resolvedAlerts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Text(
                                  '😊',
                                  style: TextStyle(fontSize: 48),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Alerts',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Everything looks good!',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// UI Components
// ─────────────────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final AppNotification alert;
  final VoidCallback onResolve;
  final VoidCallback onContact;

  const _AlertCard({
    required this.alert,
    required this.onResolve,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alert.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: alert.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(alert.icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${alert.date} · ${alert.time}',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Every real alert offers both actions now — `AppNotification`
              // carries no "action required" flag the way the old mock data
              // did, and a parent may reasonably want to reach the driver
              // about any alert, not just a subset of them.
              Expanded(
                child: GestureDetector(
                  onTap: onContact,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: alert.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.phone_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Contact Driver',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onResolve,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.cardBgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: alert.color.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: alert.color, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Mark Resolved',
                          style: TextStyle(
                            color: alert.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactDriverSheet extends StatefulWidget {
  final String driverName;

  const _ContactDriverSheet({required this.driverName});

  @override
  State<_ContactDriverSheet> createState() => _ContactDriverSheetState();
}

class _ContactDriverSheetState extends State<_ContactDriverSheet> {
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageCtrl.text.trim().isEmpty) return;

    setState(() => _sending = true);
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent to ${widget.driverName}'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Contact ${widget.driverName}',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Type your message...',
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.cardBgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.parentPurple, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: context.cardBgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.surfaceBorder),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _sending
                            ? [Colors.grey, Colors.grey]
                            : [AppTheme.parentPurple, AppTheme.parentAccent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Send',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
