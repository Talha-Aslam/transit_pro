import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';
import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../theme/app_theme.dart';

/// Real-time support chat, backed by the same `chats`/`chats/{id}/messages`
/// Firestore structure — and the same `MessagingRepository` — already used
/// for driver↔parent chat (`driver_chat_screen.dart`). That repository
/// existed, fully built and tested-looking, before this screen used it; this
/// screen (and `driver_chat_screen.dart`, `student_driver_chat.dart`) were
/// the dummy, in-memory, canned-bot-reply UI it was apparently built for but
/// never wired up to.
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _messaging = MessagingRepository.instance;

  String? _chatId;
  bool _sending = false;

  /// Set when [_init] fails, so the screen can show a real error state
  /// instead of leaving the caller stuck on a spinner forever — that
  /// silence (an unhandled exception inside an un-awaited `initState`
  /// call) is what previously took the whole app down instead of just
  /// this screen.
  Object? _initError;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _init();
  }

  void _onLangChanged() => setState(() {});

  Future<void> _init() async {
    final uid = SessionService.instance.uid;
    if (uid == null) return;
    try {
      final chatId = await _messaging.ensureThread(uid, kSupportParticipantId);
      if (!mounted) return;
      setState(() => _chatId = chatId);
      // Best-effort: opening the thread is what "reading" it means here,
      // not a failure worth surfacing to the user if the write doesn't
      // land.
      unawaited(_messaging.markThreadRead(chatId, uid));
    } on FirebaseException catch (e) {
      // Distinct from the catch-all below so a rule denial reads as
      // exactly that in the console instead of a generic failure — same
      // pattern as `find_drivers_screen.dart`'s `_request()`.
      debugPrint(
        'live chat ensureThread failed — Firebase ${e.code}: ${e.message}',
      );
      if (mounted) setState(() => _initError = e);
    } catch (e) {
      debugPrint('live chat ensureThread failed: $e');
      if (mounted) setState(() => _initError = e);
    }
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static String _formattedTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final uid = SessionService.instance.uid;
    final chatId = _chatId;
    if (text.isEmpty || uid == null || chatId == null || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await _messaging.sendMessage(
        chatId: chatId,
        senderId: uid,
        recipientId: kSupportParticipantId,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('live chat sendMessage failed: $e');
      if (!mounted) return;
      // The text is already cleared from the field; put it back so nothing
      // typed is lost to a failed send.
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
                        gradient: AppTheme.parentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('💬', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('live_chat'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppStrings.t('live_chat_hours'),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Messages list
              Expanded(
                child: _initError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            AppStrings.t('chat_load_failed'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.textSecondary),
                          ),
                        ),
                      )
                    : (uid == null || _chatId == null)
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<List<ChatMessage>>(
                        stream: _messaging.watchMessages(_chatId!),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            debugPrint(
                              'live chat watchMessages failed: ${snapshot.error}',
                            );
                            return Center(
                              child: Text(
                                AppStrings.t('chat_load_failed'),
                                style: TextStyle(color: context.textSecondary),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final messages = snapshot.data!;
                          if (messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Text(
                                  AppStrings.t('live_chat_empty'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToBottom(),
                          );
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) => _MessageBubble(
                              message: messages[index],
                              isMine: messages[index].senderId == uid,
                              timeLabel: _formattedTime(messages[index].sentAt),
                            ),
                          );
                        },
                      ),
              ),

              // Input area
              Container(
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
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: AppStrings.t('type_message'),
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
                      onTap: _sending ? null : _sendMessage,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.parentGradient,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final String timeLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    // "Mine" (the signed-in user) aligns right, exactly as before; the
    // other side (support, whichever admin replies) aligns left — same
    // visual language as the driver chat, just keyed off a real senderId
    // comparison instead of a hardcoded isSupport flag.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppTheme.parentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('💬', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMine ? AppTheme.parentGradient : null,
                    color: isMine ? null : context.cardBgElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    border: isMine
                        ? null
                        : Border.all(color: context.surfaceBorder),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMine ? Colors.white : context.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
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
