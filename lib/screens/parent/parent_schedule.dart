import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentSchedule extends StatefulWidget {
  final VoidCallback onBack;
  const ParentSchedule({super.key, required this.onBack});

  @override
  State<ParentSchedule> createState() => _ParentScheduleState();
}

class _ParentScheduleState extends State<ParentSchedule> {
  int _selectedDay = 2; // Wednesday (today)

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const _dates = [23, 24, 25, 26, 27];

  static const _schedule = [
    _DaySchedule(
      day: 'Mon',
      pickup: '07:15',
      dropoff: '03:30',
      status: 'done',
      note: '',
    ),
    _DaySchedule(
      day: 'Tue',
      pickup: '07:15',
      dropoff: '03:30',
      status: 'done',
      note: '',
    ),
    _DaySchedule(
      day: 'Wed',
      pickup: '07:15',
      dropoff: '03:30',
      status: 'today',
      note: 'On the bus now',
    ),
    _DaySchedule(
      day: 'Thu',
      pickup: '07:15',
      dropoff: '03:30',
      status: 'upcoming',
      note: '',
    ),
    _DaySchedule(
      day: 'Fri',
      pickup: '07:30',
      dropoff: '03:15',
      status: 'upcoming',
      note: 'Early dismissal',
    ),
  ];

  static const _stops = [
    _RouteStop(
      name: 'Oak Street',
      morning: '07:15 AM',
      evening: '03:30 PM',
      type: 'pickup',
    ),
    _RouteStop(
      name: 'Maple Avenue',
      morning: '07:22 AM',
      evening: '03:22 PM',
      type: 'stop',
    ),
    _RouteStop(
      name: 'Pine Road',
      morning: '07:30 AM',
      evening: '03:15 PM',
      type: 'stop',
    ),
    _RouteStop(
      name: 'Cedar Blvd',
      morning: '07:37 AM',
      evening: '03:08 PM',
      type: 'stop',
    ),
    _RouteStop(
      name: 'Lincoln Elementary',
      morning: '07:45 AM',
      evening: '03:00 PM',
      type: 'school',
    ),
  ];

  static const _holidays = [
    _Holiday(
      date: 'Mar 3, 2026',
      name: 'Spring Break Starts',
      color: AppTheme.warning,
    ),
    _Holiday(
      date: 'Mar 14, 2026',
      name: 'School Resumes',
      color: AppTheme.success,
    ),
    _Holiday(
      date: 'Apr 10, 2026',
      name: 'Easter Holiday',
      color: AppTheme.pink,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sel = _schedule[_selectedDay];

    Color statusColor;
    String statusLabel;
    switch (sel.status) {
      case 'done':
        statusColor = AppTheme.success;
        statusLabel = '✓ Completed';
        break;
      case 'today':
        statusColor = AppTheme.purple;
        statusLabel = '● Active';
        break;
      default:
        statusColor = Colors.white.withOpacity(0.4);
        statusLabel = '⏰ Upcoming';
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
                  AppTheme.parentPurple.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(onTap: widget.onBack, child: _backBtn()),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Feb 23–27, 2026',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
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
              children: [
                // ── Day selector ─────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: List.generate(5, (i) {
                      final isSelected = _selectedDay == i;
                      final isToday = _schedule[i].status == 'today';
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDay = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.parentPurple.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.parentPurple.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _weekDays[i],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: isToday
                                        ? AppTheme.mainGradient
                                        : null,
                                    color: isToday
                                        ? null
                                        : isSelected
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_dates[i]}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _schedule[i].status == 'done'
                                        ? AppTheme.success
                                        : _schedule[i].status == 'today'
                                        ? AppTheme.purple
                                        : Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Day detail ───────────────────────────────────────────
                GlassCard(
                  gradient: sel.status == 'today'
                      ? LinearGradient(
                          colors: [
                            AppTheme.parentPurple.withOpacity(0.12),
                            AppTheme.info.withOpacity(0.06),
                          ],
                        )
                      : null,
                  borderColor: sel.status == 'today'
                      ? AppTheme.parentPurple.withOpacity(0.25)
                      : null,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_weekDays[_selectedDay]}day Schedule',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (sel.note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '⚡ ${sel.note}',
                                  style: const TextStyle(
                                    color: AppTheme.parentAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _TimeCard(
                            emoji: '🌅',
                            label: 'MORNING PICKUP',
                            time: sel.pickup,
                            sub: 'Oak Street Stop',
                          ),
                          const SizedBox(width: 12),
                          _TimeCard(
                            emoji: '🌇',
                            label: 'EVENING DROP',
                            time: sel.dropoff,
                            sub: 'Oak Street Stop',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Route A timetable ────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Route A Timetable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'STOP',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Center(
                              child: Text(
                                '🌅 AM',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Center(
                              child: Text(
                                '🌇 PM',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._stops.map(
                        (stop) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: stop.type == 'school'
                                ? AppTheme.warning.withOpacity(0.08)
                                : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: stop.type == 'school'
                                  ? AppTheme.warning.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      stop.type == 'pickup'
                                          ? '📍'
                                          : stop.type == 'school'
                                          ? '🏫'
                                          : '⭕',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        stop.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: stop.type == 'school'
                                              ? AppTheme.warning
                                              : Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                          fontWeight: stop.type == 'school'
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Center(
                                  child: Text(
                                    stop.morning,
                                    style: const TextStyle(
                                      color: AppTheme.successLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Center(
                                  child: Text(
                                    stop.evening,
                                    style: const TextStyle(
                                      color: Color(0xFF60A5FA),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                const SizedBox(height: 12),

                // ── Upcoming events ──────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Events',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._holidays.map(
                        (h) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: h.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    h.date,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String emoji, label, time, sub;
  const _TimeCard({
    required this.emoji,
    required this.label,
    required this.time,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _backBtn() => Container(
  width: 38,
  height: 38,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withOpacity(0.12)),
  ),
  child: const Center(
    child: Text('←', style: TextStyle(color: Colors.white, fontSize: 16)),
  ),
);

class _DaySchedule {
  final String day, pickup, dropoff, status, note;
  const _DaySchedule({
    required this.day,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.note,
  });
}

class _RouteStop {
  final String name, morning, evening, type;
  const _RouteStop({
    required this.name,
    required this.morning,
    required this.evening,
    required this.type,
  });
}

class _Holiday {
  final String date, name;
  final Color color;
  const _Holiday({required this.date, required this.name, required this.color});
}
