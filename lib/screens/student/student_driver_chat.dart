import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';

class StudentDriverChat extends StatefulWidget {
  final String driverName;
  final String busNumber;

  const StudentDriverChat({
    super.key,
    required this.driverName,
    required this.busNumber,
  });

  @override
  State<StudentDriverChat> createState() => _StudentDriverChatState();
}

class _StudentDriverChatState extends State<StudentDriverChat>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  Timer? _replyTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_rebuild);
    _messages.add(
      _ChatMessage(
        text: 'Hi, this is ${widget.driverName}. How can I help you today?',
        isDriver: true,
        time: _formattedTime(DateTime.now()),
      ),
    );
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    LanguageProvider.instance.removeListener(_rebuild);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  static String _formattedTime(DateTime dt) {
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

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isDriver: false,
          time: _formattedTime(DateTime.now()),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          _ChatMessage(
            text:
                'Thanks for your message. ${widget.driverName} has received it and will reply shortly.',
            isDriver: true,
            time: _formattedTime(DateTime.now()),
          ),
        );
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('driver_chat_title'),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.driverName} · ${widget.busNumber}',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.t('driver_online_status'),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                      return _TypingIndicator(vsync: this);
                    }
                    return _MessageBubble(message: _messages[index]);
                  },
                ),
              ),
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
                      onTap: _sendMessage,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.parentGradient,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
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

class _ChatMessage {
  final String text;
  final bool isDriver;
  final String time;

  const _ChatMessage({
    required this.text,
    required this.isDriver,
    required this.time,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDriver = message.isDriver;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isDriver
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isDriver) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppTheme.parentGradient,
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
              crossAxisAlignment: isDriver
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isDriver ? null : AppTheme.parentGradient,
                    color: isDriver ? context.cardBgElevated : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isDriver ? 4 : 16),
                      bottomRight: Radius.circular(isDriver ? 16 : 4),
                    ),
                    border: isDriver
                        ? Border.all(color: context.surfaceBorder)
                        : null,
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isDriver ? context.textPrimary : Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.time,
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

class _TypingIndicator extends StatefulWidget {
  final TickerProvider vsync;
  const _TypingIndicator({required this.vsync});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: widget.vsync,
        duration: const Duration(milliseconds: 400),
      );
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -6,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: AppTheme.parentGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🚌', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.cardBgElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.surfaceBorder),
            ),
            child: Row(
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _anims[i],
                  builder: (_, _) => Transform.translate(
                    offset: Offset(0, _anims[i].value),
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.parentAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
