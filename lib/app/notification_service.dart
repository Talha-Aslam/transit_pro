import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'geofence_service.dart';
import 'language_provider.dart';

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
        final mins = ((alert.distance / 50).round()).toString();
        title = AppStrings.t(
          'geofence_approaching_title',
        ).replaceAll('{stop}', alert.stop.name);
        body = AppStrings.t(
          'geofence_approaching_body',
        ).replaceAll('{stop}', alert.stop.name).replaceAll('{mins}', mins);
        icon = '🔔';
        color = const Color(0xFFF59E0B);
        break;
      case GeofenceEvent.arrived:
        title = AppStrings.t(
          'geofence_arrived_title',
        ).replaceAll('{stop}', alert.stop.name);
        body = AppStrings.t(
          'geofence_arrived_body',
        ).replaceAll('{stop}', alert.stop.name);
        icon = '✅';
        color = const Color(0xFF10B981);
        break;
      case GeofenceEvent.departed:
        title = AppStrings.t(
          'geofence_departed_title',
        ).replaceAll('{stop}', alert.stop.name);
        body = AppStrings.t(
          'geofence_departed_body',
        ).replaceAll('{stop}', alert.stop.name);
        icon = '🚌';
        color = const Color(0xFF3B82F6);
        break;
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
        title: AppStrings.t('seed_emma_boarded_title'),
        message: AppStrings.t('seed_emma_boarded_message'),
        time: '07:18 AM',
        date: 'Today',
        color: const Color(0xFF10B981),
      ),
      AppNotification(
        id: 2,
        type: 'info',
        icon: '🚌',
        title: AppStrings.t('seed_bus_running_ahead_title'),
        message: AppStrings.t('seed_bus_running_ahead_message'),
        time: '07:10 AM',
        date: 'Today',
        color: const Color(0xFF3B82F6),
      ),
      AppNotification(
        id: 3,
        type: 'alert',
        icon: '🔔',
        title: AppStrings.t('seed_bus_approaching_title'),
        message: AppStrings.t('seed_bus_approaching_message'),
        time: '06:55 AM',
        date: 'Today',
        color: const Color(0xFFF59E0B),
      ),
      AppNotification(
        id: 4,
        type: 'success',
        icon: '🏫',
        read: true,
        title: AppStrings.t('seed_emma_arrived_title'),
        message: AppStrings.t('seed_emma_arrived_message'),
        time: '07:45 AM',
        date: 'Yesterday',
        color: const Color(0xFF10B981),
      ),
      AppNotification(
        id: 5,
        type: 'info',
        icon: '📍',
        read: true,
        title: AppStrings.t('seed_route_update_title'),
        message: AppStrings.t('seed_route_update_message'),
        time: '06:30 PM',
        date: 'Yesterday',
        color: const Color(0xFF8B5CF6),
      ),
      AppNotification(
        id: 6,
        type: 'success',
        icon: '🌇',
        read: true,
        title: AppStrings.t('seed_emma_dropped_title'),
        message: AppStrings.t('seed_emma_dropped_message'),
        time: '03:35 PM',
        date: 'Yesterday',
        color: const Color(0xFF10B981),
      ),
      AppNotification(
        id: 7,
        type: 'alert',
        icon: '⚠️',
        read: true,
        title: AppStrings.t('seed_schedule_change_title'),
        message: AppStrings.t('seed_schedule_change_message'),
        time: '04:00 PM',
        date: 'Mon, Feb 23',
        color: const Color(0xFFF59E0B),
      ),
    ];
  }
}
