import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverTripHistoryScreen extends StatefulWidget {
  const DriverTripHistoryScreen({super.key});

  @override
  State<DriverTripHistoryScreen> createState() =>
      _DriverTripHistoryScreenState();
}

class _DriverTripHistoryScreenState extends State<DriverTripHistoryScreen> {
  int _filterIndex = 0;

  final _filters = ['All', 'Morning', 'Afternoon', 'This Week'];

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  static const _trips = [
    _Trip(
      'Mon, Mar 3 2026',
      'Morning Route',
      'Bus Depot',
      'Lincoln Elementary',
      '06:55 AM',
      '42 min',
      'On Time',
      true,
      true,
    ),
    _Trip(
      'Mon, Mar 3 2026',
      'Afternoon Route',
      'Lincoln Elementary',
      'Bus Depot',
      '03:30 PM',
      '38 min',
      'On Time',
      true,
      false,
    ),
    _Trip(
      'Tue, Mar 4 2026',
      'Morning Route',
      'Bus Depot',
      'Lincoln Elementary',
      '07:05 AM',
      '40 min',
      '5 min late',
      false,
      true,
    ),
    _Trip(
      'Tue, Mar 4 2026',
      'Afternoon Route',
      'Lincoln Elementary',
      'Bus Depot',
      '03:30 PM',
      '36 min',
      'On Time',
      true,
      false,
    ),
    _Trip(
      'Wed, Mar 5 2026',
      'Morning Route',
      'Bus Depot',
      'Lincoln Elementary',
      '06:53 AM',
      '41 min',
      '2 min early',
      true,
      true,
    ),
    _Trip(
      'Wed, Mar 5 2026',
      'Afternoon Route',
      'Lincoln Elementary',
      'Bus Depot',
      '03:32 PM',
      '39 min',
      'On Time',
      true,
      false,
    ),
    _Trip(
      'Thu, Mar 6 2026',
      'Morning Route',
      'Bus Depot',
      'Lincoln Elementary',
      '06:58 AM',
      '43 min',
      'On Time',
      true,
      true,
    ),
    _Trip(
      'Fri, Mar 7 2026',
      'Morning Route',
      'Bus Depot',
      'Lincoln Elementary',
      '06:55 AM',
      '40 min',
      'On Time',
      true,
      true,
    ),
    _Trip(
      'Fri, Mar 7 2026',
      'Afternoon Route',
      'Lincoln Elementary',
      'Bus Depot',
      '03:30 PM',
      '37 min',
      'On Time',
      true,
      false,
    ),
  ];

  List<_Trip> get _filtered {
    switch (_filterIndex) {
      case 1:
        return _trips.where((t) => t.isMorning).toList();
      case 2:
        return _trips.where((t) => !t.isMorning).toList();
      case 3:
        return _trips.take(6).toList();
      default:
        return _trips;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = _filtered;
    final onTime = trips.where((t) => t.statusOk).length;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                      AppStrings.t('trip_history'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              // Stats row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                        '${_trips.length}',
                        'Total Trips',
                        AppTheme.driverCyan,
                      ),
                      _vd(context),
                      _Stat('$onTime', 'On Time', AppTheme.success),
                      _vd(context),
                      _Stat(
                        '${trips.length - onTime}',
                        'Delayed',
                        AppTheme.error,
                      ),
                      _vd(context),
                      _Stat(
                        '${(onTime / trips.length * 100).round()}%',
                        'Rate',
                        AppTheme.warningLight,
                      ),
                    ],
                  ),
                ),
              ),

              // Filters
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final sel = i == _filterIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _filterIndex = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: sel ? AppTheme.driverGradient : null,
                          color: sel ? null : context.cardBgElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? Colors.transparent
                                : context.surfaceBorder,
                          ),
                        ),
                        child: Text(
                          _filters[i],
                          style: TextStyle(
                            color: sel ? Colors.white : context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Trip list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TripCard(trip: trips[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vd(BuildContext context) =>
      Container(width: 1, height: 30, color: context.cardBgElevated);
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(label, style: TextStyle(color: context.textTertiary, fontSize: 10)),
    ],
  );
}

class _TripCard extends StatelessWidget {
  final _Trip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (trip.isMorning ? AppTheme.warningLight : AppTheme.info)
                          .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trip.type,
                  style: TextStyle(
                    color: trip.isMorning
                        ? AppTheme.warningLight
                        : AppTheme.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (trip.statusOk ? AppTheme.success : AppTheme.error)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trip.status,
                  style: TextStyle(
                    color: trip.statusOk
                        ? AppTheme.successLight
                        : AppTheme.errorLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('🟢', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.from,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Container(
              width: 1,
              height: 14,
              color: context.textTertiary.withOpacity(0.3),
            ),
          ),
          Row(
            children: [
              const Text('🔴', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.to,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                trip.date,
                style: TextStyle(color: context.textTertiary, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${trip.time}  ·  ${trip.duration}',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Trip {
  final String date, type, from, to, time, duration, status;
  final bool statusOk, isMorning;
  const _Trip(
    this.date,
    this.type,
    this.from,
    this.to,
    this.time,
    this.duration,
    this.status,
    this.statusOk,
    this.isMorning,
  );
}
