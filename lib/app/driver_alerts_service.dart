import 'package:flutter/foundation.dart';

class DriverAlertsService {
  DriverAlertsService._();

  static final DriverAlertsService instance = DriverAlertsService._();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(2);

  void setUnreadCount(int value) {
    unreadCount.value = value;
  }
}
