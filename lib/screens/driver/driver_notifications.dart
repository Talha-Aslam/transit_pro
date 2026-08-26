import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/driver_alerts_service.dart';
import '../../app/language_provider.dart';
import '../../app/missed_bus_service.dart';
import '../../app/session_service.dart';
import '../../data/messaging_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// Icon + accent colour for a notification, by its domain type.
(String, Color) _appearanceFor(NotificationType type) => switch (type) {
      NotificationType.emergency => ('🚨', AppTheme.error),
      NotificationType.missedBus => ('🚌', AppTheme.error),
      NotificationType.absent => ('⚠️', AppTheme.warning),
      NotificationType.delay => ('⏰', AppTheme.warning),
      NotificationType.boarded => ('✅', AppTheme.success),
      NotificationType.busArrived => ('🏫', AppTheme.success),
      NotificationType.busApproaching => ('🔔', AppTheme.warning),
      NotificationType.busDeparted => ('🚌', AppTheme.info),
      NotificationType.routeStarted => ('📍', AppTheme.info),
      NotificationType.routeCompleted => ('🌇', AppTheme.success),
      NotificationType.pickupAssigned => ('🧑‍✈️', AppTheme.success),
      NotificationType.rideRequest => ('📬', AppTheme.warning),
      NotificationType.rideRequestAnswered => ('📨', AppTheme.info),
      NotificationType.payment => ('💳', AppTheme.success),
      NotificationType.document => ('📜', AppTheme.purple),
      NotificationType.chat => ('💬', AppTheme.info),
      NotificationType.system => ('🔔', AppTheme.info),
    };

/// Which of this screen's three tabs a notification falls under.
///
/// `UserNotification` carries no sender-role field — it is a one-way inbox
/// item, not a chat message with a known author — so this is an approximation
/// by domain type rather than a real "who sent this" read. A family's seat
/// request or chat message reads as `Parents`; records an admin action would
/// produce read as `Admin`; the fully automated bus/route/attendance events
/// read as `System`.
String _tabFor(NotificationType type) => switch (type) {
      NotificationType.chat || NotificationType.rideRequest => 'Parents',
      NotificationType.document ||
      NotificationType.payment ||
      NotificationType.rideRequestAnswered ||
      NotificationType.pickupAssigned =>
        'Admin',
      _ => 'System',
    };

String _timeLabel(DateTime? when) {
  if (when == null) return 'Just now';
  final hour12 = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final minute = when.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${when.hour < 12 ? 'AM' : 'PM'}';
}

class DriverNotifications extends StatefulWidget {
  const DriverNotifications({super.key});

  @override
  State<DriverNotifications> createState() => _DriverNotificationsState();
}

class _DriverNotificationsState extends State<DriverNotifications> {
  final _session = SessionService.instance;

  List<UserNotification> _notifications = const [];
  String _activeTab = 'All';
  UserNotification? _selectedMsg;

  final _replyCtrl = TextEditingController();

  String? _subUid;
  StreamSubscription<List<UserNotification>>? _sub;

  @override
  void initState() {
    super.initState();
    _session.addListener(_ensureSubscription);
    _ensureSubscription();
  }

  @override
  void dispose() {
    _session.removeListener(_ensureSubscription);
    _sub?.cancel();
    _replyCtrl.dispose();
    super.dispose();
  }

  /// (Re)subscribes to this driver's real inbox whenever the signed-in uid
  /// changes — including the first time it becomes available, since the
  /// session may still be loading when this screen opens.
  void _ensureSubscription() {
    final uid = _session.uid;
    if (uid == _subUid) return;
    _subUid = uid;
    _sub?.cancel();
    _sub = null;
    if (uid == null) {
      setState(() => _notifications = const []);
      return;
    }
    _sub = MessagingRepository.instance.watchNotifications(uid).listen((list) {
      if (!mounted) return;
      setState(() {
        _notifications = list;
        if (_selectedMsg != null) {
          final match = list.where((m) => m.id == _selectedMsg!.id);
          _selectedMsg = match.isEmpty ? null : match.first;
        }
      });
      DriverAlertsService.instance.setUnreadCount(
        list.where((m) => !m.read).length,
      );
    });
  }

  int get _unread => _notifications.where((m) => !m.read).length;

  List<UserNotification> get _filtered => _notifications.where((m) {
        return switch (_activeTab) {
          'Parents' => _tabFor(m.type) == 'Parents',
          'Admin' => _tabFor(m.type) == 'Admin',
          'System' => _tabFor(m.type) == 'System',
          _ => true,
        };
      }).toList();

  void _openMsg(UserNotification msg) {
    setState(() => _selectedMsg = msg);
    if (msg.read) return;
    final uid = _session.uid;
    if (uid == null) return;
    // Optimistic — the live inbox stream confirms within a frame or two.
    setState(() {
      _notifications = _notifications
          .map((m) => m.id == msg.id ? m.copyWith(read: true) : m)
          .toList();
    });
    MessagingRepository.instance.markRead(uid, msg.id).catchError((e) {
      debugPrint('markRead failed: $e');
    });
    DriverAlertsService.instance.setUnreadCount(_unread);
  }

  Future<void> _markAllRead() async {
    final uid = _session.uid;
    setState(() {
      _notifications =
          _notifications.map((m) => m.copyWith(read: true)).toList();
    });
    DriverAlertsService.instance.setUnreadCount(0);
    if (uid == null) return;
    try {
      await MessagingRepository.instance.markAllRead(uid);
    } catch (e) {
      debugPrint('markAllRead failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedMsg != null) {
      return _DetailView(
        msg: _selectedMsg!,
        replyCtrl: _replyCtrl,
        onBack: () => setState(() {
          _selectedMsg = null;
          _replyCtrl.clear();
        }),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.driverCyan.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        AppStrings.t('messages'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Mark all read — compact icon button, only shown when there are unreads
                if (_unread > 0) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _markAllRead,
                    child: Tooltip(
                      message: AppStrings.t('mark_all_read'),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.driverAccent.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.driverAccent.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.done_all_rounded,
                          color: AppTheme.driverAccent,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                ValueListenableBuilder(
                  valueListenable:
                      MissedBusService.instance.driverIncomingRequests,
                  builder: (_, list, _) {
                    final count = list.length;
                    return GestureDetector(
                      onTap: () => context.push('/driver/pickup-requests'),
                      child: Tooltip(
                        message: AppStrings.t('mark_all_read'),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? AppTheme.error.withValues(alpha: 0.15)
                                    : context.cardBgElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: count > 0
                                      ? AppTheme.error.withValues(
                                          alpha: 0.4,
                                        )
                                      : context.surfaceBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.directions_bus_rounded,
                                    color: count > 0
                                        ? AppTheme.error
                                        : context.textTertiary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.t('pickups'),
                                    style: TextStyle(
                                      color: count > 0
                                          ? AppTheme.error
                                          : context.textTertiary,
                                      fontSize: 12,
                                      fontWeight: count > 0
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (count > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Tabs
                Row(
                  children: {
                    'All': AppStrings.t('all'),
                    'Parents': AppStrings.t('parents_tab'),
                    'Admin': AppStrings.t('admin_tab'),
                    'System': AppStrings.t('system_tab'),
                  }.entries.map((e) {
                    final tab = e.key;
                    final label = e.value;
                    final active = _activeTab == tab;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = tab),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppTheme.driverCyan.withValues(
                                      alpha: 0.15,
                                    )
                                  : context.cardBgElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active
                                    ? AppTheme.driverCyan.withValues(
                                        alpha: 0.4,
                                      )
                                    : context.surfaceBorder,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: active
                                      ? AppTheme.driverAccent
                                      : context.textTertiary,
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Message list
                if (_notifications.isEmpty && _session.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.driverCyan,
                      ),
                    ),
                  )
                else if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No messages here yet.',
                        style: TextStyle(color: context.textTertiary),
                      ),
                    ),
                  )
                else
                  ..._filtered.map((msg) {
                    final (icon, color) = _appearanceFor(msg.type);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RepaintBoundary(
                        child: GestureDetector(
                          onTap: () => _openMsg(msg),
                          child: AnimatedOpacity(
                            opacity: msg.read ? 0.7 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: context.cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: context.surfaceBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: color.withValues(
                                                alpha: 0.25,
                                              ),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              icon,
                                              style: const TextStyle(
                                                fontSize: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      msg.title.isEmpty
                                                          ? 'Notification'
                                                          : msg.title,
                                                      style: TextStyle(
                                                        color: context
                                                            .textPrimary,
                                                        fontSize: 13,
                                                        fontWeight: msg.read
                                                            ? FontWeight.w500
                                                            : FontWeight.w700,
                                                      ),
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    _timeLabel(msg.createdAt),
                                                    style: TextStyle(
                                                      color:
                                                          context.textTertiary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                msg.body,
                                                style: TextStyle(
                                                  color:
                                                      context.textSecondary,
                                                  fontSize: 12,
                                                  height: 1.4,
                                                ),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!msg.read) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!msg.read)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 3,
                                        color: color,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  final UserNotification msg;
  final TextEditingController replyCtrl;
  final VoidCallback onBack;

  const _DetailView({
    required this.msg,
    required this.replyCtrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _appearanceFor(msg.type);
    final tab = _tabFor(msg.type);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.driverCyan.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(onTap: onBack, child: _backBtn(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.title.isEmpty ? 'Notification' : msg.title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${AppStrings.t(tab == 'Parents'
                            ? 'parents_tab'
                            : tab == 'Admin'
                            ? 'admin_tab'
                            : 'system_tab')} · ${_timeLabel(msg.createdAt)}',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                GlassCard(
                  // This detail view's scroll body is essentially just this
                  // card (plus the reply card below, for a parent message).
                  enableBlur: false,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.body,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${AppStrings.t('received')}: ${_timeLabel(msg.createdAt)}',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tab == 'Parents') ...[
                  const SizedBox(height: 12),
                  GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('reply'),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: replyCtrl,
                          maxLines: 3,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: AppStrings.t('type_reply'),
                            hintStyle: TextStyle(color: context.textHint),
                            filled: true,
                            fillColor: context.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: context.inputBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: context.inputBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.driverAccent,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // TODO(messaging): `UserNotification` carries no
                        // sender/parent uid, only a title and body, so there
                        // is no `recipientId` to hand `MessagingRepository
                        // .sendMessage`. Wiring a real reply needs either the
                        // notification payload to carry the sender's uid, or
                        // this button to open the real chat thread for that
                        // family instead of replying in place. Left as a
                        // no-op (just closes the message) rather than a
                        // dead-end network call.
                        Text(
                          'Replying here is not wired up yet — this closes '
                          'the message without sending anything.',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: onBack,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: AppTheme.driverGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '📤  ${AppStrings.t('send_reply')}',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _backBtn(BuildContext context) => Container(
  width: 38,
  height: 38,
  decoration: BoxDecoration(
    color: context.cardBgElevated,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: context.inputBorder),
  ),
  child: Center(
    child: Text(
      '←',
      style: TextStyle(color: context.textPrimary, fontSize: 16),
    ),
  ),
);
