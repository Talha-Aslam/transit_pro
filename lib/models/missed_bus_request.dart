/// Status of a missed-bus pickup request.
enum RequestStatus {
  searching, // waiting for a nearby driver
  viewing, // a driver has opened it and is looking
  bidOffered, // that driver proposed a fare, awaiting accept/reject
  accepted, // the requester accepted the offer
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

  // ── Filled once a driver starts viewing/bidding ──────────────────────────
  String? assignedDriverName;
  String? assignedBusNumber;
  String? assignedDriverPhone;
  String? assignedDriverPhotoUrl;
  String? assignedETA;

  /// `Rs.150` display string, or null when the accepting driver has not set
  /// a fare. Paid to the driver directly — the app never moves this money.
  String? fareDisplay;

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
    this.assignedDriverPhotoUrl,
    this.assignedETA,
    this.fareDisplay,
  });
}
