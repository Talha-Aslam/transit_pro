import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverNotifications extends StatefulWidget {
  final VoidCallback onBack;
  const DriverNotifications({super.key, required this.onBack});

  @override
  State<DriverNotifications> createState() => _DriverNotificationsState();
}

class _DriverNotificationsState extends State<DriverNotifications> {
  late List<_Message> _msgs;
  String _activeTab = 'All';
  _Message? _selectedMsg;
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _msgs = List.from(_allMessages);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  int get _unread => _msgs.where((m) => !m.read).length;

  List<_Message> get _filtered => _msgs.where((m) {
    return switch (_activeTab) {
      'Parents' => m.type == 'parent',
      'Admin'   => m.type == 'admin',
      'System'  => m.type == 'system',
      _         => true,
    };
  }).toList();

  void _openMsg(_Message msg) {
    setState(() {
      final i = _msgs.indexWhere((m) => m.id == msg.id);
      _msgs[i] = _msgs[i].copyWith(read: true);
      _selectedMsg = _msgs[i];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Detail view
    if (_selectedMsg != null) {
      return _DetailView(
        msg: _selectedMsg!,
        replyCtrl: _replyCtrl,
        onBack: () => setState(() { _selectedMsg = null; _replyCtrl.clear(); }),
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
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.driverCyan.withOpacity(0.2), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(onTap: widget.onBack, child: _backBtn()),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Text('Messages',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      if (_unread > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
                          child: Text('$_unread',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_unread > 0)
                  GestureDetector(
                    onTap: () => setState(() {
                      _msgs = _msgs.map((m) => m.copyWith(read: true)).toList();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.driverAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.driverAccent.withOpacity(0.3)),
                      ),
                      child: Text('Mark all read',
                          style: TextStyle(color: AppTheme.driverAccent, fontSize: 12)),
                    ),
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
                  children: ['All', 'Parents', 'Admin', 'System'].map((tab) {
                    final active = _activeTab == tab;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = tab),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppTheme.driverCyan.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active
                                    ? AppTheme.driverCyan.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Center(
                              child: Text(tab,
                                  style: TextStyle(
                                    color: active ? AppTheme.driverAccent : Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                                  )),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Message list
                ..._filtered.map((msg) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => _openMsg(msg),
                        child: AnimatedOpacity(
                          opacity: msg.read ? 0.7 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border(
                                left: BorderSide(
                                  color: msg.read ? Colors.transparent : msg.color,
                                  width: msg.read ? 1 : 3,
                                ),
                                top: BorderSide(color: Colors.white.withOpacity(0.10)),
                                right: BorderSide(color: Colors.white.withOpacity(0.10)),
                                bottom: BorderSide(color: Colors.white.withOpacity(0.10)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: msg.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: msg.color.withOpacity(0.25)),
                                  ),
                                  child: Center(child: Text(msg.avatar, style: const TextStyle(fontSize: 22))),
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
                                            child: Text(msg.sender,
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: msg.read ? FontWeight.w500 : FontWeight.w700),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          Text(msg.time,
                                              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(msg.msg,
                                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (!msg.read) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8, height: 8, margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(color: msg.color, shape: BoxShape.circle),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  final _Message msg;
  final TextEditingController replyCtrl;
  final VoidCallback onBack;

  const _DetailView({required this.msg, required this.replyCtrl, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.driverCyan.withOpacity(0.2), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(onTap: onBack, child: _backBtn()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.sender,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${msg.type.capitalize()} · ${msg.time}',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: msg.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: msg.color.withOpacity(0.25)),
                  ),
                  child: Center(child: Text(msg.avatar, style: const TextStyle(fontSize: 22))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.msg,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.6)),
                      const SizedBox(height: 12),
                      Text('Received: ${msg.time}',
                          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                    ],
                  ),
                ),
                if (msg.type == 'parent') ...[
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REPLY',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11,
                                fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: replyCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Type your reply...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.driverAccent),
                            ),
                            contentPadding: const EdgeInsets.all(12),
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
                            child: const Center(
                              child: Text('📤  Send Reply',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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

Widget _backBtn() => Container(
  width: 38, height: 38,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withOpacity(0.12)),
  ),
  child: const Center(child: Text('←', style: TextStyle(color: Colors.white, fontSize: 16))),
);

extension _StrExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class _Message {
  final int id;
  final String type, sender, avatar, msg, time;
  final Color color;
  final bool read;

  const _Message({required this.id, required this.type, required this.sender, required this.avatar,
      required this.msg, required this.time, required this.color, required this.read});

  _Message copyWith({bool? read}) => _Message(id: id, type: type, sender: sender, avatar: avatar,
      msg: msg, time: time, color: color, read: read ?? this.read);
}

const _allMessages = [
  _Message(id: 1, type: 'parent', read: false,
      sender: "Sarah Johnson (Emma's Mom)", avatar: '👩',
      msg: 'Hi Mike, Emma will not be coming to school today. Please note her as absent.',
      time: '07:05 AM', color: AppTheme.parentAccent),
  _Message(id: 2, type: 'admin', read: false,
      sender: 'Transport Admin', avatar: '🏢',
      msg: 'Please be aware: road works on Pine Road today. Use alternate route via Oak Ave.',
      time: '06:45 AM', color: AppTheme.driverAccent),
  _Message(id: 3, type: 'parent', read: true,
      sender: "David Martinez (Ava's Dad)", avatar: '👨',
      msg: 'Thank you for the on-time service today! Ava was very happy.',
      time: 'Yesterday', color: AppTheme.parentAccent),
  _Message(id: 4, type: 'system', read: true,
      sender: 'System Alert', avatar: '⚙️',
      msg: 'Your morning route is complete. 22/22 students delivered safely. Great job!',
      time: 'Yesterday', color: AppTheme.success),
  _Message(id: 5, type: 'admin', read: true,
      sender: 'Transport Admin', avatar: '🏢',
      msg: 'Reminder: Monthly vehicle inspection is scheduled for Friday, Feb 28.',
      time: 'Mon, Feb 23', color: AppTheme.driverAccent),
  _Message(id: 6, type: 'parent', read: true,
      sender: "Emily Wilson (William's Mom)", avatar: '👩',
      msg: "William will need to be picked up at the alternate stop on Cedar Ave tomorrow.",
      time: 'Mon, Feb 23', color: AppTheme.parentAccent),
];
