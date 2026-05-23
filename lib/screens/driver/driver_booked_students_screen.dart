import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
import '../../app/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverBookedStudentsScreen extends StatefulWidget {
  final VoidCallback onBack;
  const DriverBookedStudentsScreen({super.key, required this.onBack});

  @override
  State<DriverBookedStudentsScreen> createState() =>
      _DriverBookedStudentsScreenState();
}

class _DriverBookedStudentsScreenState
    extends State<DriverBookedStudentsScreen> {
  late List<_BookedPassenger> _booked;
  String _search = '';

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _booked = List.from(_initialBookedPassengers);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  List<_BookedPassenger> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _booked;
    return _booked
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.stop.toLowerCase().contains(q) ||
              p.parentPhone.toLowerCase().contains(q) ||
              p.school.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filtered.map((p) => p.stop).toSet().toList();

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
                GestureDetector(onTap: widget.onBack, child: _backBtn(context)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booked Children & Students',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'All passengers booked with this driver',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      _SummaryPill(
                        label: 'Booked',
                        value: _booked.length,
                        color: AppTheme.driverCyan,
                      ),
                      const SizedBox(width: 10),
                      _SummaryPill(
                        label: 'Stops',
                        value: groups.length,
                        color: AppTheme.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Icon(
                          Icons.search_rounded,
                          color: context.textTertiary,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search child, school, stop or phone',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintStyle: TextStyle(color: context.textHint),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Text('🚌', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            'No booked passengers found',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...groups.map((stop) {
                    final stopPassengers = _filtered
                        .where((p) => p.stop == stop)
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                '📍 $stop',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: context.cardBgElevated,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...stopPassengers.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BookedPassengerCard(passenger: p),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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

class _BookedPassengerCard extends StatelessWidget {
  final _BookedPassenger passenger;
  const _BookedPassengerCard({required this.passenger});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPassengerDetails(context),
        child: GlassCard(
          enableBlur: false,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.cardBgElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    passenger.avatar,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passenger.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${passenger.grade} · ${passenger.school}',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Parent: ${passenger.parentName}',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.driverCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.driverCyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  passenger.busNumber,
                  style: const TextStyle(
                    color: AppTheme.driverAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPassengerDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PassengerDetailSheet(passenger: passenger),
    );
  }
}

class _PassengerDetailSheet extends StatefulWidget {
  final _BookedPassenger passenger;

  const _PassengerDetailSheet({required this.passenger});

  @override
  State<_PassengerDetailSheet> createState() => _PassengerDetailSheetState();
}

class _PassengerDetailSheetState extends State<_PassengerDetailSheet> {
  late final TextEditingController _messageController;
  late final List<_ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messages = [
      _ChatMessage(
        sender: widget.passenger.parentName,
        text: 'Please let me know when the bus reaches the stop.',
        time: '07:05 AM',
        isMe: false,
      ),
      _ChatMessage(
        sender: widget.passenger.name,
        text: 'I am ready at the pickup point.',
        time: '07:07 AM',
        isMe: false,
      ),
      _ChatMessage(
        sender: 'Driver',
        text: 'We are 5 minutes away.',
        time: '07:08 AM',
        isMe: true,
      ),
    ];
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert({
    required String title,
    required String body,
    required String icon,
    required Color color,
    String type = 'info',
  }) async {
    await NotificationService.instance.show(
      title: '$icon $title',
      body: body,
      type: type,
      icon: icon,
      color: color,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title sent to ${widget.passenger.parentName}')),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          sender: 'Driver',
          text: text,
          time: _timeNow(),
          isMe: true,
        ),
      );
      _messageController.clear();
    });
  }

  String _timeNow() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final passenger = widget.passenger;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.inputBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.driverCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            passenger.avatar,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              passenger.name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${passenger.grade} · ${passenger.school}',
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
                  const SizedBox(height: 16),
                  GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(label: 'Grade', value: passenger.grade),
                        _DetailRow(label: 'Stop', value: passenger.stop),
                        _DetailRow(label: 'Bus', value: passenger.busNumber),
                        _DetailRow(
                          label: 'Parent',
                          value: passenger.parentName,
                        ),
                        _DetailRow(
                          label: 'Parent contact',
                          value: passenger.parentPhone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Chat with parent and child',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        ..._messages.map(
                          (message) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChatBubble(message: message),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 3,
                                style: TextStyle(color: context.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Write a message...',
                                  hintStyle: TextStyle(color: context.textHint),
                                  filled: true,
                                  fillColor: context.cardBgElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppTheme.driverCyan,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Quick alerts to parent',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _AlertChip(
                        label: 'Arrived',
                        icon: '🏫',
                        color: AppTheme.info,
                        onTap: () => _sendAlert(
                          title: '${passenger.name} arrived',
                          body:
                              '${passenger.name} has reached the destination stop.',
                          icon: '🏫',
                          color: AppTheme.info,
                          type: 'info',
                        ),
                      ),
                      _AlertChip(
                        label: 'Delayed',
                        icon: '⏳',
                        color: const Color(0xFFF59E0B),
                        onTap: () => _sendAlert(
                          title: '${passenger.name} delayed',
                          body:
                              'Bus update for ${passenger.name}: arrival will be about 10 minutes late.',
                          icon: '⏳',
                          color: const Color(0xFFF59E0B),
                          type: 'alert',
                        ),
                      ),
                      _AlertChip(
                        label: 'Emergency',
                        icon: '🚨',
                        color: AppTheme.error,
                        onTap: () => _sendAlert(
                          title: '${passenger.name} emergency',
                          body:
                              'Urgent update regarding ${passenger.name}. Please contact the driver immediately.',
                          icon: '🚨',
                          color: AppTheme.error,
                          type: 'alert',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.cardBgElevated,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isMe
        ? AppTheme.driverCyan.withValues(alpha: 0.2)
        : context.cardBgElevated;

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: message.isMe
                ? AppTheme.driverCyan.withValues(alpha: 0.25)
                : context.inputBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: message.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: TextStyle(
                color: message.isMe
                    ? AppTheme.driverAccent
                    : context.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: TextStyle(color: context.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const _AlertChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String sender;
  final String text;
  final String time;
  final bool isMe;

  const _ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
    required this.isMe,
  });
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    child: Text(
      '←',
      style: TextStyle(color: context.textPrimary, fontSize: 16),
    ),
  ),
);

class _BookedPassenger {
  final String name;
  final String grade;
  final String school;
  final String stop;
  final String busNumber;
  final String parentName;
  final String parentPhone;
  final String avatar;

  const _BookedPassenger({
    required this.name,
    required this.grade,
    required this.school,
    required this.stop,
    required this.busNumber,
    required this.parentName,
    required this.parentPhone,
    required this.avatar,
  });
}

const _initialBookedPassengers = [
  _BookedPassenger(
    name: 'Emma Johnson',
    grade: 'Grade 5',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Defence Pickup Point, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Sarah Johnson',
    parentPhone: '+1 555-0101',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'Liam Williams',
    grade: 'Grade 3',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Defence Pickup Point, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Michael Williams',
    parentPhone: '+1 555-0102',
    avatar: '👦',
  ),
  _BookedPassenger(
    name: 'Olivia Davis',
    grade: 'Grade 4',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Model Town Centre, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Rebecca Davis',
    parentPhone: '+1 555-0103',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'Noah Brown',
    grade: 'Grade 6',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Model Town Centre, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Daniel Brown',
    parentPhone: '+1 555-0104',
    avatar: '👦',
  ),
  _BookedPassenger(
    name: 'Ava Martinez',
    grade: 'Grade 2',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Canal Road Junction, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Maria Martinez',
    parentPhone: '+1 555-0105',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'William Wilson',
    grade: 'Grade 5',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Canal Road Junction, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Robert Wilson',
    parentPhone: '+1 555-0106',
    avatar: '👦',
  ),
  _BookedPassenger(
    name: 'Sophia Anderson',
    grade: 'Grade 3',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Aitchison College Entrance, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Nadia Anderson',
    parentPhone: '+1 555-0107',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'James Taylor',
    grade: 'Grade 4',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Aitchison College Entrance, Lahore',
    busNumber: 'Bus #42',
    parentName: 'Thomas Taylor',
    parentPhone: '+1 555-0108',
    avatar: '👦',
  ),
  _BookedPassenger(
    name: 'Ali Khan',
    grade: 'Undergraduate',
    school: 'University of Lahore',
    stop: 'UOL Main Gate, Johar Town',
    busNumber: 'Bus #U1',
    parentName: 'Self',
    parentPhone: '+92 300 7001001',
    avatar: '🎓',
  ),
  _BookedPassenger(
    name: 'Zara Ahmed',
    grade: 'Undergraduate',
    school: 'Lahore University of Management Sciences',
    stop: 'LUMS Main Gate, DHA',
    busNumber: 'Bus #U2',
    parentName: 'Self',
    parentPhone: '+92 300 7001002',
    avatar: '🎓',
  ),
  _BookedPassenger(
    name: 'Hassan Raza',
    grade: 'Postgraduate',
    school: 'National University of Sciences & Technology',
    stop: 'NUST Campus Stop, Islamabad',
    busNumber: 'Bus #U3',
    parentName: 'Self',
    parentPhone: '+92 300 7001003',
    avatar: '🎓',
  ),
  _BookedPassenger(
    name: 'Maya Singh',
    grade: 'Undergraduate',
    school: 'Forman Christian College',
    stop: 'FCCU Main Gate, Lahore',
    busNumber: 'Bus #U4',
    parentName: 'Self',
    parentPhone: '+92 300 7001004',
    avatar: '🎓',
  ),
];
