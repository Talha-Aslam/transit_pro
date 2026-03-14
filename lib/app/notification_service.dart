import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'geofence_service.dart';

/// Called when the user taps a notification while the app is terminated.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void _onNotificationTapBackground(NotificationResponse response) {
  // The OS will relaunch the app; normal routing takes over.
}

/// Notification item for in-app display.
class AppNotification {
  final int id;
  final String type;
  final String icon;
  final String title;
  final String message;
  final String time;
  final String date;
  final Color color;
  bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.date,
    required this.color,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    icon: icon,
    title: title,
    message: message,
    time: time,
    date: date,
    color: color,
    read: read ?? this.read,
  );
}

/// Singleton that manages both local push notifications and in-app history.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final history = ValueNotifier<List<AppNotification>>([]);
  int _nextId = 100;

  bool _initialised = false;

  /// Initialise the notification plugin. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
    );

    // Seed history with some mock notifications
    _seedHistory();
  }

  /// Show a local push notification and add to in-app history.
  Future<void> show({
    required String title,
    required String body,
    String type = 'info',
    String icon = '🔔',
    Color color = Colors.blue,
  }) async {
    final id = _nextId++;

    // Push notification
    const androidDetails = AndroidNotificationDetails(
      'transit_pro_channel',
      'Transit Pro',
      channelDescription: 'Bus tracking notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);

    // In-app history
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';

    final notif = AppNotification(
      id: id,
      type: type,
      icon: icon,
      title: title,
      message: body,
      time: timeStr,
      date: 'Today',
      color: color,
    );

    history.value = [notif, ...history.value];
  }

  /// Convert a geofence alert into a notification.
  Future<void> fromGeofence(GeofenceAlert alert) async {
    String title;
    String body;
    String icon;
    Color color;

    switch (alert.event) {
      case GeofenceEvent.approaching:
        title = 'Bus Approaching ${alert.stop.name}';
        body =
            'Bus will arrive at ${alert.stop.name} in about ${(alert.distance / 50).round()} minutes.';
        icon = '🔔';
        color = const Color(0xFFF59E0B);
      case GeofenceEvent.arrived:
        title = 'Bus Arrived at ${alert.stop.name}';
        body = 'The bus has arrived at ${alert.stop.name}. Please be ready!';
        icon = '✅';
        color = const Color(0xFF10B981);
      case GeofenceEvent.departed:
        title = 'Bus Left ${alert.stop.name}';
        body = 'The bus has departed from ${alert.stop.name}.';
        icon = '🚌';
        color = const Color(0xFF3B82F6);
    }

    await show(
      title: title,
      body: body,
      type: alert.event == GeofenceEvent.approaching ? 'alert' : 'info',
      icon: icon,
      color: color,
    );
  }

  void markAllRead() {
    history.value = history.value.map((n) => n.copyWith(read: true)).toList();
  }

  int get unreadCount => history.value.where((n) => !n.read).length;

  void _seedHistory() {
    history.value = [
      AppNotification(
        id: 1,
        type: 'success',
        icon: '✅',
        title: 'Emma Boarded the Bus',
        message: 'Your child has safely boarded Bus #42 at Oak Street stop.',
        time: '07:18 AM',
        date: 'Today',
        color: const Color(0xFF10B981),
      ),
      AppNotification(
        id: 2,
        type: 'info',
        icon: '🚌',
        title: 'Bus Running Ahead',
        message: 'Bus #42 is running 3 minutes ahead of schedule today.',
        time: '07:10 AM',
        date: 'Today',
        color: const Color(0xFF3B82F6),
      ),
      AppNotification(
        id: 3,
        type: 'alert',
        icon: '🔔',
        title: 'Bus Approaching Stop',
        message:
            'Bus #42 will arrive at Pine Road stop in approximately 5 minutes.',
        time: '06:55 AM',
        date: 'Today',
        color: const Color(0xFFF59E0B),
      ),
      AppNotification(
        id: 4,
        type: 'success',
        icon: '🏫',
        read: true,
        title: 'Emma Arrived at School',
        message: 'Emma has safely arrived at Lincoln Elementary School.',
        time: '07:45 AM',
        date: 'Yesterday',
        color: const Color(0xFF10B981),
      ),
      AppNotification(
        id: 5,
        type: 'info',
        icon: '📍',
        read: true,
        title: 'Route Update',
        message:
            'Due to road works, Route A will use alternate path via Oak Avenue.',
        time: '06:30 PM',
        date: 'Yesterday',
        color: const Color(0xFF8B5CF6),
      ),
      AppNotification(
        id: 6,
        type: 'success',
        icon: '🌇',
        read: true,
        title: 'Emma Dropped Off',
        message: 'Emma has been safely dropped off at Oak Street stop.',
        time: '03:35 PM',
        date: 'Yesterday',
        color: const Color(0xFF10B981),
      ),
      AppNotification(
        id: 7,
        type: 'alert',
        icon: '⚠️',
        read: true,
        title: 'Schedule Change',
        message:
            "Tomorrow's pickup time has been moved to 07:30 AM due to a school event.",
        time: '04:00 PM',
        date: 'Mon, Feb 23',
        color: const Color(0xFFF59E0B),
      ),
    ];
  }
}
