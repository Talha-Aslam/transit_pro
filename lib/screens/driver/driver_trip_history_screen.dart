import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../data/trip_repository.dart';
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
  DateTime? _selectedDate;

  final _filters = ['All', 'Today', 'This Week', 'This Month'];

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.driverCyan),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  void _clearPickedDate() {
    setState(() => _selectedDate = null);
  }

  DateTime _tripDate(Trip t) =>
      t.startedAt ?? DateTime.tryParse(t.dateKey) ?? DateTime.now();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Applies the calendar date (if picked) and the chip filter, in that
  /// order — computed once per build rather than re-derived (and re-sorted by
  /// implication) every time the list is touched.
  List<Trip> _applyFilters(List<Trip> trips) {
    var result = trips;
    if (_selectedDate != null) {
      result =
          result.where((t) => _isSameDay(_tripDate(t), _selectedDate!)).toList();
    }

    final now = DateTime.now();
    switch (_filterIndex) {
      case 1: // Today
        return result.where((t) => _isSameDay(_tripDate(t), now)).toList();
      case 2: // This Week (Monday onward)
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return result
            .where((t) => !_tripDate(t).isBefore(startOfWeek))
            .toList();
      case 3: // This Month
        return result
            .where(
              (t) =>
                  _tripDate(t).year == now.year &&
                  _tripDate(t).month == now.month,
            )
            .toList();
      default: // All
        return result;
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
              _buildHeader(),
              Expanded(
                child: uid == null
                    ? const _EmptyTrips(
                        message: 'Sign in to see your trip history.',
                      )
                    : StreamBuilder<List<Trip>>(
                        stream:
                            TripRepository.instance.watchTripsForDriver(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.driverCyan,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return const _EmptyTrips(
                              message:
                                  'Could not load your trip history. Check '
                                  'your connection and try again.',
                            );
                          }
                          final allTrips = snapshot.data ?? const <Trip>[];
                          // Computed once here and passed down, rather than a
                          // `_filtered` getter re-run (and re-filtered from
                          // scratch) on every widget that touches it.
                          final trips = _applyFilters(allTrips);
                          return _buildBody(trips, everHadTrips: allTrips.isNotEmpty);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<Trip> trips, {required bool everHadTrips}) {
    final completed =
        trips.where((t) => t.status == TripStatus.completed).toList();
    final onTime = completed.where((t) => t.onTime == true).length;
    final delayed = completed.where((t) => t.onTime == false).length;
    final rate = completed.isEmpty ? 0 : (onTime / completed.length * 100).round();

    return Column(
      children: [
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
                _Stat('${trips.length}', 'Total Trips', AppTheme.driverCyan),
                _vd(),
                _Stat('$onTime', 'On Time', AppTheme.success),
                _vd(),
                _Stat('$delayed', 'Delayed', AppTheme.error),
                _vd(),
                _Stat('$rate%', 'Rate', AppTheme.warningLight),
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
            separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                      color: sel ? Colors.transparent : context.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _filters[i],
                        style: TextStyle(
                          color: sel ? Colors.white : context.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Trip list
        Expanded(
          child: trips.isEmpty
              ? _EmptyTrips(
                  message: everHadTrips
                      ? 'No trips match this filter yet.'
                      : 'Your trip history will appear here once you '
                          'complete your first ride.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: trips.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TripCard(trip: trips[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
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
          Expanded(
            child: Text(
              AppStrings.t('trip_history'),
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_selectedDate != null) ...[
            GestureDetector(
              onTap: _clearPickedDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: context.cardBgElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.inputBorder),
                ),
                child: Text(
                  '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: _pickDate,
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
                  Icons.calendar_month_rounded,
                  color: context.textPrimary,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vd() => Container(width: 1, height: 30, color: context.cardBgElevated);
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

class _EmptyTrips extends StatelessWidget {
  final String message;
  const _EmptyTrips({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textTertiary, fontSize: 13),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  const _TripCard({required this.trip});

  bool get _isMorning => trip.type == TripType.morning;

  ({String label, Color color}) get _statusDisplay {
    switch (trip.status) {
      case TripStatus.completed:
        if (trip.onTime == true) {
          return (label: 'On Time', color: AppTheme.success);
        }
        if (trip.onTime == false) {
          final mins = trip.delayMinutes;
          return (
            label: mins != null ? '$mins min late' : 'Delayed',
            color: AppTheme.error,
          );
        }
        return (label: 'Completed', color: AppTheme.info);
      case TripStatus.inProgress:
        return (label: 'In Progress', color: AppTheme.warning);
      case TripStatus.cancelled:
        return (label: 'Cancelled', color: AppTheme.error);
      case TripStatus.scheduled:
        return (label: 'Scheduled', color: AppTheme.info);
    }
  }

  String _formatDate(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day} ${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get _durationLabel {
    final d = trip.duration;
    if (d == null) return '—';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusDisplay;
    final date = trip.startedAt ?? DateTime.tryParse(trip.dateKey);

    return GlassCard(
      // One instance per row of a `ListView.separated` — the blur pass would
      // repeat for every visible card on every scroll frame.
      enableBlur: false,
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
                      (_isMorning ? AppTheme.warningLight : AppTheme.info)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isMorning ? 'Morning Route' : 'Afternoon Route',
                  style: TextStyle(
                    color: _isMorning ? AppTheme.warningLight : AppTheme.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
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
              Icon(
                Icons.groups_rounded,
                size: 14,
                color: context.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                '${trip.studentsBoarded} boarded'
                '${trip.studentsAbsent > 0 ? ' · ${trip.studentsAbsent} absent' : ''}'
                '${trip.studentsExpected > 0 ? ' of ${trip.studentsExpected}' : ''}',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                date == null ? '—' : _formatDate(date),
                style: TextStyle(color: context.textTertiary, fontSize: 11),
              ),
              const Spacer(),
              Text(
                date == null
                    ? _durationLabel
                    : '${_formatTime(date)}  ·  $_durationLabel',
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
