import 'package:flutter/material.dart';
import '../../app/language_provider.dart';
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
                  AppTheme.driverCyan.withOpacity(0.2),
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
    return GlassCard(
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
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Parent: ${passenger.parentPhone}',
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.driverCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.driverCyan.withOpacity(0.3)),
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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
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
  final String parentPhone;
  final String avatar;

  const _BookedPassenger({
    required this.name,
    required this.grade,
    required this.school,
    required this.stop,
    required this.busNumber,
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
    parentPhone: '+1 555-0101',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'Liam Williams',
    grade: 'Grade 3',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Defence Pickup Point, Lahore',
    busNumber: 'Bus #42',
    parentPhone: '+1 555-0102',
    avatar: '👦',
  ),
  _BookedPassenger(
    name: 'Olivia Davis',
    grade: 'Grade 4',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Model Town Centre, Lahore',
    busNumber: 'Bus #42',
    parentPhone: '+1 555-0103',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'Noah Brown',
    grade: 'Grade 6',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Model Town Centre, Lahore',
    busNumber: 'Bus #42',
    parentPhone: '+1 555-0104',
    avatar: '👦',
  ),
  _BookedPassenger(
    name: 'Ava Martinez',
    grade: 'Grade 2',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Canal Road Junction, Lahore',
    busNumber: 'Bus #42',
    parentPhone: '+1 555-0105',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'William Wilson',
    grade: 'Grade 5',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Canal Road Junction, Lahore',
    busNumber: 'Bus #42',
    parentPhone: '+1 555-0106',
    avatar: '👦',
  ),
  _BookedPassenger(
    name: 'Sophia Anderson',
    grade: 'Grade 3',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Aitchison College Entrance, Lahore',
    busNumber: 'Bus #42',
    parentPhone: '+1 555-0107',
    avatar: '👧',
  ),
  _BookedPassenger(
    name: 'James Taylor',
    grade: 'Grade 4',
    school: 'Lahore Grammar School - Askari Campus',
    stop: 'Aitchison College Entrance, Lahore',
    busNumber: 'Bus #42',
    parentPhone: '+1 555-0108',
    avatar: '👦',
  ),
];
