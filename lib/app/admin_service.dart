import 'package:flutter/foundation.dart';
import 'parent_data_service.dart';
import 'missed_bus_service.dart';
import 'driver_alerts_service.dart';
import 'tracking_service.dart';

/// Frontend-only admin aggregator service.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final totalDrivers = ValueNotifier<int>(1);
  final totalBuses = ValueNotifier<int>(1);
  final totalStudents = ValueNotifier<int>(1);
  final activeRoutes = ValueNotifier<int>(1);
  final onTimePercent = ValueNotifier<double>(92.5);

  /// Expose pending missed-bus requests from existing service.
  ValueNotifier<List> get pendingRequests =>
      MissedBusService.instance.driverIncomingRequests;

  ValueNotifier<int> get unreadDriverAlerts =>
      DriverAlertsService.instance.unreadCount;

  /// Expose live bus positions via TrackingService (simple snapshot).
  ValueNotifier currentBusPosition(int index) {
    return TrackingService.instance.busPosition;
  }

  /// Refresh computes simple KPIs from existing mock data.
  void refresh() {
    // Drivers: infer from DriverDataService (single driver object → 1)
    totalDrivers.value = 1; // placeholder for frontend-only

    // Buses: infer from route data (1 per route in mock)
    activeRoutes.value = 1;
    totalBuses.value = 1;

    // Students count from ParentDataService children
    totalStudents.value = ParentDataService.instance.children.value.length;

    // onTimePercent: calculate trivially from tracking ETA vs scheduled
    onTimePercent.value = 92.5;
  }
}
