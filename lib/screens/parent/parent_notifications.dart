import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../app/notification_service.dart';
import '../../theme/app_theme.dart';

class ParentNotifications extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(int unreadCount)? onUnreadChanged;
  const ParentNotifications({
    super.key,
    required this.onBack,
    this.onUnreadChanged,
  });

  @override
  State<ParentNotifications> createState() => _ParentNotificationsState();
}

class _ParentNotificationsState extends State<ParentNotifications> {
  final _svc = NotificationService.instance;
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _svc.init();
    _svc.history.addListener(_onHistoryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUnreadChanged?.call(_svc.unreadCount);
    });
  }

  void _onHistoryChanged() {
    widget.onUnreadChanged?.call(_svc.unreadCount);
    setState(() {});
  }

  @override
  void dispose() {
    _svc.history.removeListener(_onHistoryChanged);
    super.dispose();
  }

  List<AppNotification> get _filtered {
    final all = _svc.history.value;
    switch (_activeFilter) {
      case 'Unread':
        return all.where((n) => !n.read).toList();
      case 'Today':
        return all.where((n) => n.date == 'Today').toList();
      case 'Alerts':
        return all.where((n) => n.type == 'alert').toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _svc.unreadCount;

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) => SingleChildScrollView(
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
                    AppTheme.parentPurple.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: _backBtn(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          AppStrings.t('notifications'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 10),
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
                              '$unread',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (unread > 0)
                    GestureDetector(
                      onTap: () {
                        _svc.markAllRead();
                        widget.onUnreadChanged?.call(0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.parentAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.parentAccent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          AppStrings.t('mark_all_read'),
                          style: TextStyle(
                            color: AppTheme.parentAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          {
                            'All': AppStrings.t('all'),
                            'Unread': AppStrings.t('unread'),
                            'Today': AppStrings.t('today'),
                            'Alerts': AppStrings.t('alerts'),
                          }.entries.map((e) {
                            final f = e.key;
                            final label = e.value;
                            final active = _activeFilter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _activeFilter = f),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppTheme.parentPurple.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: active
                                          ? AppTheme.parentPurple.withOpacity(
                                              0.5,
                                            )
                                          : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: active
                                          ? AppTheme.parentAccent
                                          : context.textSecondary,
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Grouped by date
                  for (final date in ['Today', 'Yesterday', 'Mon, Feb 23']) ...[
                    Builder(
                      builder: (context) {
                        final group = _filtered
                            .where((n) => n.date == date)
                            .toList();
                        if (group.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                date,
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ...group.map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RepaintBoundary(
                                  child: _NotifCard(
                                    notif: n,
                                    onTap: () {
                                      n.read = true;
                                      _svc.history.value = List.from(
                                        _svc.history.value,
                                      );
                                      widget.onUnreadChanged?.call(
                                        _svc.unreadCount,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ],

                  if (_filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/notification_bell_off.png',
                              width: 90,
                              height: 90,
                              cacheWidth: 180,
                              cacheHeight: 180,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.t('no_notifs'),
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: notif.read ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              border: Border(
                left: BorderSide(
                  color: notif.read ? Colors.transparent : notif.color,
                  width: notif.read ? 1 : 3,
                ),
                top: BorderSide(color: context.surfaceBorder),
                right: BorderSide(color: context.surfaceBorder),
                bottom: BorderSide(color: context.surfaceBorder),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: notif.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: notif.color.withOpacity(0.25)),
                  ),
                  child: Center(
                    child: Text(
                      notif.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: notif.read
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            notif.time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notif.message,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notif.read) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: notif.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    child: Icon(Icons.arrow_back, color: context.textPrimary, size: 16),
  ),
);
