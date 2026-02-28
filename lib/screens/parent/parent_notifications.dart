import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ParentNotifications extends StatefulWidget {
  final VoidCallback onBack;
  const ParentNotifications({super.key, required this.onBack});

  @override
  State<ParentNotifications> createState() => _ParentNotificationsState();
}

class _ParentNotificationsState extends State<ParentNotifications> {
  String _activeFilter = 'All';
  late List<_Notif> _notifs;

  @override
  void initState() {
    super.initState();
    _notifs = List.from(_allNotifs);
  }

  int get _unreadCount => _notifs.where((n) => !n.read).length;

  List<_Notif> get _filtered {
    switch (_activeFilter) {
      case 'Unread': return _notifs.where((n) => !n.read).toList();
      case 'Today':  return _notifs.where((n) => n.date == 'Today').toList();
      case 'Alerts': return _notifs.where((n) => n.type == 'alert').toList();
      default:       return _notifs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.parentPurple.withOpacity(0.2), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: _backBtn(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Text('Notifications',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$_unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_unreadCount > 0)
                  GestureDetector(
                    onTap: () => setState(() {
                      _notifs = _notifs.map((n) => n.copyWith(read: true)).toList();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.parentAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.parentAccent.withOpacity(0.3)),
                      ),
                      child: Text('Mark all read',
                          style: TextStyle(color: AppTheme.parentAccent, fontSize: 12)),
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
                    children: ['All', 'Unread', 'Today', 'Alerts'].map((f) {
                      final active = _activeFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeFilter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppTheme.parentPurple.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active
                                    ? AppTheme.parentPurple.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(f,
                                style: TextStyle(
                                  color: active ? AppTheme.parentAccent : Colors.white.withOpacity(0.5),
                                  fontSize: 13,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Grouped by date
                for (final date in ['Today', 'Yesterday', 'Mon, Feb 23']) ...[
                  Builder(builder: (context) {
                    final group = _filtered.where((n) => n.date == date).toList();
                    if (group.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(date,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                        ),
                        ...group.map((n) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _NotifCard(
                                notif: n,
                                onTap: () => setState(() {
                                  final i = _notifs.indexWhere((x) => x.id == n.id);
                                  _notifs[i] = _notifs[i].copyWith(read: true);
                                }),
                              ),
                            )),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],

                if (_filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Text('🔔', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text('No notifications in this category',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final _Notif notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: notif.read ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border(
              left: BorderSide(
                color: notif.read ? Colors.transparent : notif.color,
                width: notif.read ? 1 : 3,
              ),
              top: BorderSide(color: Colors.white.withOpacity(0.10)),
              right: BorderSide(color: Colors.white.withOpacity(0.10)),
              bottom: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: notif.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: notif.color.withOpacity(0.25)),
                ),
                child: Center(child: Text(notif.icon, style: const TextStyle(fontSize: 20))),
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
                          child: Text(notif.title,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: notif.read ? FontWeight.w500 : FontWeight.w700)),
                        ),
                        Text(notif.time,
                            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(notif.msg,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55), fontSize: 12, height: 1.5)),
                  ],
                ),
              ),
              if (!notif.read) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: notif.color, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _backBtn() => Container(
  width: 38, height: 38,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withOpacity(0.12)),
  ),
  child: const Center(child: Text('←', style: TextStyle(color: Colors.white, fontSize: 16))),
);

class _Notif {
  final int id;
  final String type, icon, title, msg, time, date;
  final Color color;
  final bool read;

  const _Notif({
    required this.id, required this.type, required this.icon,
    required this.title, required this.msg, required this.time,
    required this.date, required this.color, required this.read,
  });

  _Notif copyWith({bool? read}) => _Notif(
    id: id, type: type, icon: icon, title: title, msg: msg,
    time: time, date: date, color: color, read: read ?? this.read,
  );
}

const _allNotifs = [
  _Notif(id: 1, type: 'success', icon: '✅', read: false, title: 'Emma Boarded the Bus',
      msg: 'Your child has safely boarded Bus #42 at Oak Street stop.',
      time: '07:18 AM', date: 'Today', color: AppTheme.success),
  _Notif(id: 2, type: 'info', icon: '🚌', read: false, title: 'Bus Running Ahead',
      msg: 'Bus #42 is running 3 minutes ahead of schedule today.',
      time: '07:10 AM', date: 'Today', color: AppTheme.info),
  _Notif(id: 3, type: 'alert', icon: '🔔', read: false, title: 'Bus Approaching Stop',
      msg: 'Bus #42 will arrive at Pine Road stop in approximately 5 minutes.',
      time: '06:55 AM', date: 'Today', color: AppTheme.warning),
  _Notif(id: 4, type: 'success', icon: '🏫', read: true, title: 'Emma Arrived at School',
      msg: 'Emma has safely arrived at Lincoln Elementary School.',
      time: '07:45 AM', date: 'Yesterday', color: AppTheme.success),
  _Notif(id: 5, type: 'info', icon: '📍', read: true, title: 'Route Update',
      msg: 'Due to road works, Route A will use alternate path via Oak Avenue.',
      time: '06:30 PM', date: 'Yesterday', color: AppTheme.purple),
  _Notif(id: 6, type: 'success', icon: '🌇', read: true, title: 'Emma Dropped Off',
      msg: 'Emma has been safely dropped off at Oak Street stop.',
      time: '03:35 PM', date: 'Yesterday', color: AppTheme.success),
  _Notif(id: 7, type: 'alert', icon: '⚠️', read: true, title: 'Schedule Change',
      msg: "Tomorrow's pickup time has been moved to 07:30 AM due to a school event.",
      time: '04:00 PM', date: 'Mon, Feb 23', color: AppTheme.warning),
];
