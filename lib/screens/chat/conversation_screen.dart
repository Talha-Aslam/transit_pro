import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/chat_service.dart';
import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_image.dart';

/// A real conversation between two accounts, backed by
/// `chats/{chatId}/messages`.
///
/// There were two of these before, one on the parent side and one on the
/// student side, and neither sent anything: each kept a `List` in memory,
/// appended what you typed, and two seconds later appended
/// "`<driver>` has received it and will reply shortly" — from a `Timer`, not
/// from the driver, who was never told a message existed. The driver had no
/// chat screen at all. This is one screen, used by all three roles, writing
/// to the thread both ends read, and alerting the recipient so a closed app
/// still rings.
class ConversationScreen extends StatefulWidget {
  /// The other participant's uid. Empty means there is nobody to talk to
  /// yet (no driver assigned), which the screen says rather than silently
  /// failing on send.
  final String peerId;

  /// Shown in the header, and used as the notification's title on the
  /// recipient's lock screen.
  final String peerName;

  /// Secondary header line — a bus number, a child's name, a grade.
  final String? subtitle;

  /// Whose colours to wear. Parents and students get the purple scheme,
  /// drivers the cyan one, so the screen looks like the app around it.
  final Gradient accentGradient;

  /// `parent` / `student` / `driver`, stored on the message so a future
  /// screen can tell a driver's reply from an admin's.
  final String senderRole;

  /// The child this conversation is about, when there is one. Two children
  /// with the same driver get two threads, so neither side has to guess
  /// which one a message means.
  final String? studentId;

  const ConversationScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.senderRole,
    required this.accentGradient,
    this.subtitle,
    this.studentId,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<ChatMessage>>? _sub;
  List<ChatMessage> _messages = const [];
  String? _chatId;
  bool _loading = true;
  bool _sending = false;

  String? get _uid => SessionService.instance.uid;
  bool get _hasPeer => widget.peerId.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _openThread();
  }

  @override
  void dispose() {
    _sub?.cancel();
    LanguageProvider.instance.removeListener(_onLangChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  /// Creates the thread if this is the first message between the two, then
  /// streams it. Done on open rather than on first send so both sides see
  /// the same (empty) thread and the unread badge can be cleared here.
  Future<void> _openThread() async {
    final uid = _uid;
    if (uid == null || !_hasPeer) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final chatId = await MessagingRepository.instance.ensureThread(
        uid,
        widget.peerId,
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        _chatId = chatId;
        _loading = false;
      });
      _sub = MessagingRepository.instance.watchMessages(chatId).listen((msgs) {
        if (!mounted) return;
        setState(() => _messages = msgs);
        _scrollToBottom();
        // Reading them here is what stops the badge counting messages the
        // user is currently looking at.
        unawaited(MessagingRepository.instance.markThreadRead(chatId, uid));
      }, onError: (Object e) => debugPrint('conversation stream: $e'));
    } catch (e) {
      debugPrint('conversation openThread failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final uid = _uid;
    if (text.isEmpty || uid == null || !_hasPeer || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await ChatService.instance.send(
        senderId: uid,
        recipientId: widget.peerId,
        text: text,
        senderName: _ownName(),
        senderRole: widget.senderRole,
        studentId: widget.studentId,
      );
    } catch (e) {
      debugPrint('conversation send failed: $e');
      if (!mounted) return;
      // Put the text back rather than losing what was typed.
      _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t('message_send_failed')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// What the recipient sees as the notification title.
  String _ownName() {
    final session = SessionService.instance;
    final name = session.user.value?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    return switch (widget.senderRole) {
      'driver' => 'Your driver',
      'student' => 'Your rider',
      _ => 'A parent',
    };
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : !_hasPeer
                    ? _EmptyState(
                        emoji: '🫥',
                        title: AppStrings.t('chat_no_peer_title'),
                        body: AppStrings.t('chat_no_peer_body'),
                      )
                    : _messages.isEmpty
                    ? _EmptyState(
                        emoji: '💬',
                        title: AppStrings.t('chat_empty_title'),
                        body: AppStrings.t('chat_empty_body'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          return _MessageBubble(
                            text: m.text,
                            time: _timeLabel(m.sentAt),
                            mine: m.senderId == uid,
                            accent: widget.accentGradient,
                          );
                        },
                      ),
              ),
              _composer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: widget.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('💬', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.peerName.trim().isEmpty
                    ? AppStrings.t('driver_chat_title')
                    : widget.peerName.trim(),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((widget.subtitle ?? '').trim().isNotEmpty)
                Text(
                  widget.subtitle!.trim(),
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _composer(BuildContext context) {
    final enabled = _hasPeer && _chatId != null && !_sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        border: Border(top: BorderSide(color: context.surfaceBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.inputFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.inputBorder),
              ),
              child: TextField(
                controller: _controller,
                enabled: enabled,
                style: TextStyle(color: context.textPrimary, fontSize: 13),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: AppStrings.t('type_driver_message'),
                  hintStyle: TextStyle(
                    color: context.textTertiary,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: enabled ? _send : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: widget.accentGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: _sending
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool mine;
  final Gradient accent;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.mine,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🚌', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: mine ? accent : null,
                    color: mine ? null : context.cardBgElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 16),
                    ),
                    border: mine
                        ? null
                        : Border.all(color: context.surfaceBorder),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: mine ? Colors.white : context.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(color: context.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;

  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    ),
  );
}

/// The driver's side: every family this driver carries, newest message
/// first, with an unread count.
///
/// The driver had no way to read a message at all before this. A parent
/// could type into a screen that pretended to send; nothing arrived, and
/// there was nowhere for it to arrive to.
class DriverConversationsScreen extends StatefulWidget {
  const DriverConversationsScreen({super.key});

  @override
  State<DriverConversationsScreen> createState() =>
      _DriverConversationsScreenState();
}

class _DriverConversationsScreenState extends State<DriverConversationsScreen> {
  StreamSubscription<List<ChatThread>>? _sub;
  List<ChatThread> _threads = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final uid = SessionService.instance.uid;
    if (uid == null) {
      _loading = false;
      return;
    }
    _sub = MessagingRepository.instance.watchThreadsFor(uid).listen((list) {
      if (!mounted) return;
      setState(() {
        _threads = list;
        _loading = false;
      });
    }, onError: (Object e) {
      debugPrint('driver conversations stream: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// A thread's other participant. Threads are two-party here, so this is
  /// whichever uid is not the signed-in one.
  String _peerOf(ChatThread t, String uid) =>
      t.participants.firstWhere((p) => p != uid, orElse: () => '');

  /// The rider behind a thread, from the roster this driver already has in
  /// memory.
  ///
  /// A driver cannot read arbitrary `users/` documents — that rule keeps
  /// every account's phone and email private, and widening it to put a
  /// parent's photo on this row would not be worth that. The child is the
  /// face the driver actually knows, and `students/` *is* readable for
  /// their own roster, so the row wears the rider's photo and name.
  /// The child a thread is about.
  ///
  /// Prefers the thread's own `studentId` — a parent with two children
  /// riding with this driver has two threads, and matching on the parent's
  /// uid alone would name both of them after whichever child the roster
  /// happened to list first.
  Student? _riderFor(ChatThread thread, String peerId) {
    final session = SessionService.instance;
    final roster = [...session.roster.value, ...session.routeStudents.value];
    final childId = thread.studentId;
    if (childId != null && childId.isNotEmpty) {
      for (final s in roster) {
        if (s.id == childId) return s;
      }
    }
    for (final s in roster) {
      if (s.parentId == peerId || s.id == peerId) return s;
    }
    return null;
  }

  String _nameFor(ChatThread thread, String peerId) {
    final rider = _riderFor(thread, peerId);
    if (rider == null) return 'A family';
    return rider.parentId == peerId ? "${rider.name}'s parent" : rider.name;
  }

  @override
  Widget build(BuildContext context) {
    final uid = SessionService.instance.uid;
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
                      AppTheme.driverCyan.withValues(alpha: 0.2),
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
                    const SizedBox(width: 14),
                    Text(
                      AppStrings.t('messages_title'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _threads.isEmpty || uid == null
                    ? _EmptyState(
                        emoji: '💬',
                        title: AppStrings.t('chat_empty_title'),
                        body: AppStrings.t('driver_chat_inbox_empty'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _threads.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final t = _threads[i];
                          final peer = _peerOf(t, uid);
                          final name = _nameFor(t, peer);
                          final unread = t.unreadCounts[uid] ?? 0;
                          final rider = _riderFor(t, peer);
                          return _ThreadRow(
                            name: name,
                            photoUrl: rider?.photoUrl,
                            instituteType: rider?.instituteType ?? '',
                            preview: t.lastMessage,
                            unread: unread,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ConversationScreen(
                                  peerId: peer,
                                  peerName: name,
                                  subtitle: rider == null
                                      ? null
                                      : [
                                          if (rider.grade.isNotEmpty)
                                            rider.grade,
                                          if (rider.school.isNotEmpty)
                                            rider.school,
                                        ].join(' · '),
                                  studentId: t.studentId,
                                  senderRole: 'driver',
                                  accentGradient: AppTheme.driverGradient,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String instituteType;
  final String preview;
  final int unread;
  final VoidCallback onTap;

  const _ThreadRow({
    required this.name,
    required this.photoUrl,
    required this.instituteType,
    required this.preview,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.driverGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AvatarImage(
                localFile: null,
                photoUrl: photoUrl,
                size: 44,
                borderRadius: BorderRadius.circular(14),
                fallback: riderGlyph(instituteType, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview.isEmpty ? '—' : preview,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
