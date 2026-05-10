class ParentTripHistoryEntry {
  final DateTime date;
  final String typeKey;
  final String from;
  final String to;
  final String time;
  final String statusKey;
  final bool statusOk;
  final bool isMorning;
  final bool completed;

  const ParentTripHistoryEntry({
    required this.date,
    required this.typeKey,
    required this.from,
    required this.to,
    required this.time,
    required this.statusKey,
    required this.statusOk,
    required this.isMorning,
    this.completed = true,
  });
}

List<ParentTripHistoryEntry> buildParentTripHistoryEntries(DateTime now) {
  DateTime onDay(int dayOffset, int hour, int minute) {
    return DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
  }

  return [
    ParentTripHistoryEntry(
      date: onDay(0, 7, 15),
      typeKey: 'trip_type_morning_pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:15 AM',
      statusKey: 'trip_status_on_time',
      statusOk: true,
      isMorning: true,
      completed: false,
    ),
    ParentTripHistoryEntry(
      date: onDay(0, 15, 30),
      typeKey: 'trip_type_afternoon_dropoff',
      from: 'Lincoln Elementary',
      to: 'Oak Street Stop',
      time: '03:30 PM',
      statusKey: 'trip_status_on_time',
      statusOk: true,
      isMorning: false,
    ),
    ParentTripHistoryEntry(
      date: onDay(-1, 7, 20),
      typeKey: 'trip_type_morning_pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:20 AM',
      statusKey: 'trip_status_5_late',
      statusOk: false,
      isMorning: true,
    ),
    ParentTripHistoryEntry(
      date: onDay(-2, 15, 30),
      typeKey: 'trip_type_afternoon_dropoff',
      from: 'Lincoln Elementary',
      to: 'Oak Street Stop',
      time: '03:30 PM',
      statusKey: 'trip_status_on_time',
      statusOk: true,
      isMorning: false,
    ),
    ParentTripHistoryEntry(
      date: onDay(-4, 7, 14),
      typeKey: 'trip_type_morning_pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:14 AM',
      statusKey: 'trip_status_1_early',
      statusOk: true,
      isMorning: true,
    ),
    ParentTripHistoryEntry(
      date: onDay(-10, 15, 30),
      typeKey: 'trip_type_afternoon_dropoff',
      from: 'Lincoln Elementary',
      to: 'Oak Street Stop',
      time: '03:30 PM',
      statusKey: 'trip_status_on_time',
      statusOk: true,
      isMorning: false,
    ),
    ParentTripHistoryEntry(
      date: onDay(-40, 7, 18),
      typeKey: 'trip_type_morning_pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:18 AM',
      statusKey: 'trip_status_on_time',
      statusOk: true,
      isMorning: true,
    ),
    ParentTripHistoryEntry(
      date: DateTime(now.year, 1, 18, 15, 25),
      typeKey: 'trip_type_afternoon_dropoff',
      from: 'Lincoln Elementary',
      to: 'Oak Street Stop',
      time: '03:25 PM',
      statusKey: 'trip_status_on_time',
      statusOk: true,
      isMorning: false,
    ),
    ParentTripHistoryEntry(
      date: DateTime(now.year - 1, 11, 22, 7, 12),
      typeKey: 'trip_type_morning_pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:12 AM',
      statusKey: 'trip_status_on_time',
      statusOk: true,
      isMorning: true,
    ),
  ];
}
