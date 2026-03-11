/// Status of a missed-bus pickup request.
enum RequestStatus {
  searching, // waiting for a nearby driver
  accepted, // a driver accepted
  declined, // all drivers declined
  cancelled, // student / parent cancelled
  noDrivers, // no compatible bus found in range
}

/// A single missed-bus pickup request raised by a student or parent.
class MissedBusRequest {
  final String id;

  // ── Who raised it ────────────────────────────────────────────────────────
  final String studentName;
  final String studentId;
  final String missedBusNumber;
  final String assignedRoute;

  // ── Journey ──────────────────────────────────────────────────────────────
  final String currentStop;
  final String destination;

  // ── State ────────────────────────────────────────────────────────────────
  RequestStatus status;
  final DateTime timestamp;

  // ── Filled when a driver accepts ─────────────────────────────────────────
  String? assignedDriverName;
  String? assignedBusNumber;
  String? assignedDriverPhone;
  String? assignedETA;

  MissedBusRequest({
    required this.id,
    required this.studentName,
    required this.studentId,
    required this.missedBusNumber,
    required this.assignedRoute,
    required this.currentStop,
    required this.destination,
    required this.timestamp,
    this.status = RequestStatus.searching,
    this.assignedDriverName,
    this.assignedBusNumber,
    this.assignedDriverPhone,
    this.assignedETA,
  });
}
