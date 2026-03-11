import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/missed_bus_request.dart';
import '../models/route_data.dart';
import 'notification_service.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Singleton service managing the complete lifecycle of a missed-bus pickup
/// request: raise → search → driver notified → accept/decline → resolved.
///
/// All state is local (mock). A real backend would swap the internals while
/// keeping the same ValueNotifier API.
class MissedBusService {
  MissedBusService._();
  static final MissedBusService instance = MissedBusService._();

  // ── Public state ──────────────────────────────────────────────────────────

  /// The currently active request from the student/parent side. Null when idle.
  final studentActiveRequest = ValueNotifier<MissedBusRequest?>(null);

  /// Requests pending action on the driver side.
  final driverIncomingRequests = ValueNotifier<List<MissedBusRequest>>([]);

  // ── Stop list (sourced from existing route data) ──────────────────────────

  static List<String> get routeStops =>
      MockRouteBuilder.buildMorningRoute().stops.map((s) => s.name).toList();

  // ── Mock nearby buses that could respond ─────────────────────────────────

  static const _nearbyBuses = [
    _MockBus(
      driverName: 'Bilal Hussain',
      busNumber: 'Bus #17',
      phone: '+92 301 7778821',
      etaMinutes: 8,
    ),
    _MockBus(
      driverName: 'Kamran Iqbal',
      busNumber: 'Bus #29',
      phone: '+92 333 2221144',
      etaMinutes: 12,
    ),
  ];

  int _nearbyBusIndex = 0;
  int _nextId = 1;

  // ── Raise a request ───────────────────────────────────────────────────────

  /// Called by student or parent. Creates the request and simulates a 3-second
  /// search before alerting the closest available driver.
  void raiseRequest({
    required String studentName,
    required String studentId,
    required String missedBusNumber,
    required String assignedRoute,
    required String currentStop,
    required String destination,
  }) {
    final req = MissedBusRequest(
      id: 'req_${_nextId++}',
      studentName: studentName,
      studentId: studentId,
      missedBusNumber: missedBusNumber,
      assignedRoute: assignedRoute,
      currentStop: currentStop,
      destination: destination,
      timestamp: DateTime.now(),
      status: RequestStatus.searching,
    );

    studentActiveRequest.value = req;
    driverIncomingRequests.value = [];

    // Simulate a 3-second route-matching delay then alert drivers
    Future.delayed(const Duration(seconds: 3), () {
      if (studentActiveRequest.value?.id != req.id) return; // cancelled
      if (req.status != RequestStatus.searching) return;

      // Add to driver incoming list
      driverIncomingRequests.value = [req];

      // Alert driver via local push notification
      NotificationService.instance.show(
        title: '🚌 Pickup Request — $currentStop → $destination',
        body: '$studentName missed $missedBusNumber. Tap to accept or decline.',
        type: 'pickup_request',
        icon: '🚨',
        color: AppTheme.warning,
      );
    });
  }

  // ── Driver accepts ────────────────────────────────────────────────────────

  void acceptRequest(String id) {
    final req = _findRequest(id);
    if (req == null) return;

    final bus = _nearbyBuses[_nearbyBusIndex % _nearbyBuses.length];
    _nearbyBusIndex++;

    req
      ..status = RequestStatus.accepted
      ..assignedDriverName = bus.driverName
      ..assignedBusNumber = bus.busNumber
      ..assignedDriverPhone = bus.phone
      ..assignedETA = '~${bus.etaMinutes} min';

    // Notify student
    NotificationService.instance.show(
      title: '✅ Driver Accepted — Bus incoming!',
      body:
          '${bus.driverName} (${bus.busNumber}) accepted your request. ETA: ${bus.etaMinutes} min.',
      type: 'pickup_accepted',
      icon: '✅',
      color: AppTheme.success,
    );

    // Force ValueNotifier to re-fire listeners (mutable object, same reference)
    final updated = studentActiveRequest.value;
    studentActiveRequest.value = null;
    studentActiveRequest.value = updated;
    // First-accept wins — clear driver's list
    driverIncomingRequests.value = [];
  }

  // ── Driver declines ───────────────────────────────────────────────────────

  void declineRequest(String id) {
    final req = _findRequest(id);
    if (req == null) return;

    final updated = driverIncomingRequests.value
        .where((r) => r.id != id)
        .toList();
    driverIncomingRequests.value = updated;

    if (updated.isEmpty) {
      req.status = RequestStatus.noDrivers;
      // Force ValueNotifier to re-fire listeners (mutable object, same reference)
      final stale = studentActiveRequest.value;
      studentActiveRequest.value = null;
      studentActiveRequest.value = stale;

      NotificationService.instance.show(
        title: '⚠️ No drivers available',
        body:
            'No nearby bus could accept your request right now. Please contact the school.',
        type: 'pickup_declined',
        icon: '⚠️',
        color: AppTheme.error,
      );
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  void cancelRequest() {
    final req = studentActiveRequest.value;
    if (req != null) {
      req.status = RequestStatus.cancelled;
    }
    studentActiveRequest.value = null;
    driverIncomingRequests.value = [];
  }

  // ── Reset (for "Try Again") ───────────────────────────────────────────────

  void clearRequest() {
    studentActiveRequest.value = null;
    driverIncomingRequests.value = [];
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  MissedBusRequest? _findRequest(String id) {
    if (studentActiveRequest.value?.id == id) {
      return studentActiveRequest.value;
    }
    try {
      return driverIncomingRequests.value.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Simple immutable descriptor for a mock nearby bus.
class _MockBus {
  final String driverName;
  final String busNumber;
  final String phone;
  final int etaMinutes;
  const _MockBus({
    required this.driverName,
    required this.busNumber,
    required this.phone,
    required this.etaMinutes,
  });
}
