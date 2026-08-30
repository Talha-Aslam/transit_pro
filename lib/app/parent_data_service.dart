import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transit_core/transit_core.dart';

import '../data/payment_repository.dart';
import '../data/rating_repository.dart';
import '../data/trip_repository.dart';
import '../data/user_repository.dart';
import '../services/cloudinary_service.dart';
import 'session_service.dart';

/// A single child, flattened for the UI.
///
/// [id] is new and matters: the prototype identified a child only by name, so
/// editing one meant rewriting the whole list, and two children called Ali were
/// the same child. Every write now targets `students/{id}`.
class ChildInfo {
  final String id;
  String name;
  String grade;
  String school;

  /// `Student.instituteType` -- `School`/`College`/`University`/`Academy`.
  /// Was never carried through this flattened view until now: the "Edit
  /// Info" sheet (`parent_profile.dart`) had its own local-only guess for
  /// this (matching `school` against a hardcoded demo list of institute
  /// names), which silently forgot any real institute not in that tiny
  /// list. This is the real, persisted value instead.
  String instituteType;

  String busNumber;
  String route;
  String stop;
  String driver;
  String? photoUrl;

  /// Where the child is collected from / dropped off, from
  /// `Student.pickupLocation`/`.dropoffLocation`. Set at signup but, until
  /// now, never surfaced (or editable) anywhere past that point.
  GeoCoord? pickup;
  GeoCoord? dropoff;

  /// Which of the assigned driver's `DriverSchedule` rounds this child rides
  /// — `Student.scheduleId`. Null when the driver runs a single round (or
  /// none at all), in which case there is nothing to choose.
  String? scheduleId;

  ChildInfo({
    this.id = '',
    this.name = '',
    this.grade = '',
    this.school = '',
    this.instituteType = '',
    this.busNumber = '',
    this.route = '',
    this.stop = '',
    this.driver = '',
    this.photoUrl,
    this.pickup,
    this.dropoff,
    this.scheduleId,
  });

  ChildInfo copyWith({
    String? name,
    String? grade,
    String? school,
    String? instituteType,
    String? busNumber,
    String? route,
    String? stop,
    String? driver,
    String? photoUrl,
    GeoCoord? pickup,
    GeoCoord? dropoff,
    String? scheduleId,
  }) => ChildInfo(
    id: id,
    name: name ?? this.name,
    grade: grade ?? this.grade,
    school: school ?? this.school,
    instituteType: instituteType ?? this.instituteType,
    busNumber: busNumber ?? this.busNumber,
    route: route ?? this.route,
    stop: stop ?? this.stop,
    driver: driver ?? this.driver,
    photoUrl: photoUrl ?? this.photoUrl,
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
    scheduleId: scheduleId ?? this.scheduleId,
  );
}

/// The parent's own details, from `users/{uid}`.
class ParentInfo {
  String name;
  String email;
  String phone;

  ParentInfo({this.name = '', this.email = '', this.phone = ''});
}

/// Parent-facing view of the live session.
///
/// Keeps the notifier API the parent screens already bind to; the source behind
/// it is now Firestore. Ratings and fee state, which used to live in
/// `SharedPreferences` and therefore never reached the driver who was being
/// rated or paid, are real documents now.
class ParentDataService {
  ParentDataService._() {
    SessionService.instance.onUser((_) => _rebuild());
    SessionService.instance.onRoleData(_rebuild);
  }
  static final ParentDataService instance = ParentDataService._();

  /// Payment reminders stay device-local on purpose: this is a notification
  /// preference for this phone, not shared data anyone else reads.
  static const _paymentRemindersKey = 'parent_payment_reminders';

  /// Boarding/arrival/delay alert toggles, same device-local reasoning as
  /// [_paymentRemindersKey] — these are per-phone notification preferences,
  /// not account data.
  static const _notificationPrefsKey = 'parent_notification_prefs';

  final parentInfo = ValueNotifier<ParentInfo>(ParentInfo());
  final children = ValueNotifier<List<ChildInfo>>([]);

  /// Locally picked photos, held only until the Cloudinary upload lands and
  /// `photoUrl` takes over. Keeps the avatar from flickering back to a
  /// placeholder while the upload is in flight.
  final childImages = ValueNotifier<List<File?>>([]);

  /// Mirrors [SessionService.selectedChildIndex] so existing screens keep
  /// working; that notifier is the one the session actually follows.
  ValueNotifier<int> get selectedChildIndex =>
      SessionService.instance.selectedChildIndex;

  final driverRatings = ValueNotifier<Map<String, DriverRatingInfo>>({});
  final paidFeeMonths = ValueNotifier<Set<String>>({});
  final feeNotifications = ValueNotifier<List<String>>([]);
  final paymentReminders = ValueNotifier<Map<String, bool>>({});

  /// Keyed by 'boarding' / 'arrival' / 'delay'. Missing keys default to `true`
  /// in [notificationPrefFor] — the toggles have always defaulted on.
  final notificationPrefs = ValueNotifier<Map<String, bool>>({});

  // ── helpers ────────────────────────────────────────────────────────────────

  ChildInfo? get currentChild => selectedChild;

  ChildInfo? get selectedChild {
    final list = children.value;
    if (list.isEmpty) return null;
    return list[selectedChildIndex.value.clamp(0, list.length - 1)];
  }

  File? get selectedChildImage {
    final imgs = childImages.value;
    if (imgs.isEmpty) return null;
    final idx = selectedChildIndex.value;
    if (idx < 0 || idx >= imgs.length) return null;
    return imgs[idx];
  }

  /// Ratings are keyed by driver id now, not by `'Bus #42|Ahmed Raza'`. The old
  /// key changed whenever a bus was reassigned or a name was corrected, which
  /// silently reset the weekly gate.
  String _driverKey(ChildInfo child) => child.driver;

  // ── Live rebuild ──────────────────────────────────────────────────────────

  void _rebuild() {
    final session = SessionService.instance;
    final user = session.user.value;

    if (user == null) {
      parentInfo.value = ParentInfo();
      children.value = [];
      childImages.value = [];
      driverRatings.value = {};
      paidFeeMonths.value = {};
      feeNotifications.value = [];
      return;
    }

    if (user.role != UserRole.parent) return;

    parentInfo.value = ParentInfo(
      name: user.name,
      email: user.email,
      phone: user.phone,
    );

    final kids = session.children.value;
    children.value = kids.map((s) {
      final bus = session.busFor(s.busId);
      final route = session.routeFor(s.routeId);
      return ChildInfo(
        id: s.id,
        name: s.name,
        grade: s.grade,
        school: s.school,
        instituteType: s.instituteType,
        busNumber: bus?.busNumber ?? '',
        route: route?.name ?? '',
        stop: session.stopNameFor(s) ?? '',
        // The driver *id*, not a display name — see _driverKey. Prefers the
        // admin-assigned bus's driver, but falls back to the student's own
        // direct `driverId` — set when a self-signed-up driver (the actual
        // pilot path; see `Student.driverId`'s doc comment) accepts this
        // child's ride request without ever going through a `Bus` document.
        // Without the fallback, a pilot family's driver id was always empty
        // here, which silently broke both the weekly rating gate and any
        // lookup keyed on "this child's driver".
        driver: bus?.driverId ?? s.driverId ?? '',
        photoUrl: s.photoUrl,
        pickup: s.pickupLocation,
        dropoff: s.dropoffLocation,
        scheduleId: s.scheduleId,
      );
    }).toList();

    // Keep the local preview list the same length as the child list. Guarded on
    // length: a ValueNotifier<List> compares by identity, so reassigning an
    // equivalent list every rebuild would wake every listening screen for
    // nothing.
    if (childImages.value.length != kids.length) {
      final imgs = List<File?>.from(childImages.value);
      while (imgs.length < kids.length) {
        imgs.add(null);
      }
      childImages.value = imgs.take(kids.length).toList();
    }

    _loadRatings(user.uid);
    _loadFees(user.uid);
  }

  // ── Ratings ───────────────────────────────────────────────────────────────

  String? _ratingsForUid;

  Future<void> _loadRatings(String uid) async {
    if (_ratingsForUid == uid) return;
    _ratingsForUid = uid;
    await loadDriverRatings();
  }

  /// Kept for the screens that call it directly on open.
  Future<void> loadDriverRatings() async {
    final uid = SessionService.instance.uid;
    if (uid == null) {
      driverRatings.value = {};
      return;
    }
    try {
      final list = await RatingRepository.instance.fetchByRater(uid);
      driverRatings.value = {
        for (final r in list)
          r.driverId: DriverRatingInfo(
            rating: r.rating,
            ratedAt: r.createdAt ?? DateTime.now(),
          ),
      };
    } catch (e) {
      debugPrint('load ratings failed: $e');
    }
  }

  bool canRateDriver(ChildInfo child) {
    final info = driverRatings.value[_driverKey(child)];
    if (info == null) return true;
    return !info.isSameWeek(DateTime.now());
  }

  /// Whether [child] has ever actually completed a ride with the driver
  /// currently assigned to them.
  ///
  /// [canRateDriver] above only answers "have I already rated this driver
  /// this week" — it says nothing about whether a ride ever happened, so a
  /// driver merely *assigned* to a child (via [_driverKey]) but never ridden
  /// with could be rated. This is the other, required half of the gate: at
  /// least one `boarded` attendance record whose denormalised `driverId`
  /// matches the child's *current* driver id. Matching on the current id
  /// specifically matters — a child may have ridden with a previous driver
  /// who no longer serves them, and that history must not count towards
  /// rating today's driver.
  ///
  /// Needs a Firestore read (via [TripRepository.fetchAttendanceForStudent]),
  /// so unlike [canRateDriver] this is async; callers should resolve it once
  /// (e.g. in `initState`) and cache the result rather than calling it from
  /// `build`.
  Future<bool> hasRiddenWithDriver(ChildInfo child) async {
    final driverId = _driverKey(child);
    if (driverId.isEmpty || child.id.isEmpty) return false;
    try {
      final records = await TripRepository.instance.fetchAttendanceForStudent(
        child.id,
      );
      return records.any(
        (r) => r.driverId == driverId && r.status == AttendanceStatus.boarded,
      );
    } catch (e) {
      debugPrint('hasRiddenWithDriver failed: $e');
      return false;
    }
  }

  DriverRatingInfo? driverRatingFor(ChildInfo child) =>
      driverRatings.value[_driverKey(child)];

  Future<void> rateDriverForChild(ChildInfo child, double rating) async {
    final uid = SessionService.instance.uid;
    final driverId = _driverKey(child);
    if (uid == null || driverId.isEmpty) return;

    final accepted = await RatingRepository.instance.submit(
      driverId: driverId,
      raterId: uid,
      rating: rating,
      studentId: child.id.isEmpty ? null : child.id,
    );
    if (!accepted) return;

    final updated = Map<String, DriverRatingInfo>.from(driverRatings.value);
    updated[driverId] = DriverRatingInfo(
      rating: rating,
      ratedAt: DateTime.now(),
    );
    driverRatings.value = updated;
  }

  // ── Fees ──────────────────────────────────────────────────────────────────

  String? _feesForUid;

  Future<void> _loadFees(String uid) async {
    if (_feesForUid == uid) return;
    _feesForUid = uid;
    await loadFeeState();
  }

  /// Which months are settled, straight from `payments`.
  ///
  /// This used to be a `Set<String>` in `SharedPreferences`, which meant a
  /// parent could mark their own fees paid by reinstalling the app, and the
  /// driver never saw any of it.
  Future<void> loadFeeState() async {
    final uid = SessionService.instance.uid;
    if (uid == null) {
      paidFeeMonths.value = {};
      feeNotifications.value = [];
      return;
    }
    try {
      final payments = await PaymentRepository.instance
          .watchForParent(uid)
          .first;
      paidFeeMonths.value = payments
          .where((p) => p.status == PaymentStatus.paid)
          .map((p) => p.monthKey)
          .toSet();
      feeNotifications.value = payments
          .where((p) => p.status == PaymentStatus.paid)
          .map((p) => 'Your ${p.monthKey} fee payment was confirmed.')
          .toList();
    } catch (e) {
      debugPrint('load fees failed: $e');
    }
  }

  bool isMonthPaid(String month) => paidFeeMonths.value.contains(month);

  /// Confirmation is the *driver's* action, not the parent's.
  ///
  /// `firestore.rules` blocks a parent from setting `status: paid`, so this
  /// only refreshes the local view after the driver has confirmed. It is kept
  /// because the payment screens still call it.
  Future<void> confirmFeeByDriver({
    required String month,
    required String driverName,
  }) async {
    await loadFeeState();
  }

  // ── Profile writes ────────────────────────────────────────────────────────

  Future<void> updateParentInfo(ParentInfo info) async {
    final uid = SessionService.instance.uid;
    if (uid == null) return;
    parentInfo.value = info;
    await UserRepository.instance.updateUser(uid, {
      'name': info.name,
      'phone': info.phone,
    });
  }

  Future<void> updateChild(int index, ChildInfo child) async {
    final list = List<ChildInfo>.from(children.value);
    if (index < 0 || index >= list.length) return;
    list[index] = child;
    children.value = list;

    if (child.id.isEmpty) return;
    await UserRepository.instance.updateStudent(child.id, {
      'name': child.name,
      'grade': child.grade,
      'school': child.school,
      'instituteType': child.instituteType,
      'pickupLocation': ?child.pickup?.toMap(),
      'dropoffLocation': ?child.dropoff?.toMap(),
      'scheduleId': ?child.scheduleId,
    });
  }

  /// Uploads the picked photo and stores its URL on the child.
  ///
  /// The prototype held a `File` in memory and called it done, so the photo was
  /// gone on the next launch and no other device ever saw it.
  Future<void> updateChildImage(int index, File? image) async {
    final imgs = List<File?>.from(childImages.value);
    while (imgs.length <= index) {
      imgs.add(null);
    }
    imgs[index] = image;
    childImages.value = List.unmodifiable(imgs);

    if (image == null) return;
    final list = children.value;
    if (index < 0 || index >= list.length) return;
    final childId = list[index].id;
    if (childId.isEmpty) return;

    if (!CloudinaryService.instance.isConfigured) {
      debugPrint('Cloudinary not configured — child photo kept locally only.');
      return;
    }

    try {
      final result = await CloudinaryService.instance.uploadProfilePhoto(
        image,
        childId,
      );
      await UserRepository.instance.updateStudent(childId, {
        'photoUrl': result.secureUrl,
      });
    } catch (e) {
      debugPrint('child photo upload failed: $e');
    }
  }

  Future<void> addChild(ChildInfo child) async {
    final uid = SessionService.instance.uid;
    if (uid == null) return;
    await UserRepository.instance.addStudent(
      Student(
        id: '',
        name: child.name,
        parentId: uid,
        grade: child.grade,
        school: child.school,
        // Was `child.grade` -- a copy-paste of the same default the signup
        // flow uses when no dedicated instituteType selector exists there
        // yet. This form (`_ChildFlowSheet`, shared with `updateChild`) now
        // has its own real instituteType field, so use it.
        instituteType: child.instituteType,
        pickupLocation: child.pickup,
        dropoffLocation: child.dropoff,
      ),
    );
    // The children stream republishes; no local mutation needed.
  }

  Future<void> removeChild(int index) async {
    final list = children.value;
    if (index < 0 || index >= list.length) return;
    final id = list[index].id;
    if (id.isEmpty) return;
    await UserRepository.instance.deleteStudent(id);
  }

  void selectChild(int index) {
    final count = children.value.length;
    if (count == 0) return;
    selectedChildIndex.value = index.clamp(0, count - 1);
  }

  // ── Payment reminders (device-local) ──────────────────────────────────────

  Future<void> loadPaymentReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_paymentRemindersKey);
    if (raw == null || raw.isEmpty) {
      paymentReminders.value = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      paymentReminders.value = decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      paymentReminders.value = {};
    }
  }

  Future<void> setPaymentReminder(String month, bool enabled) async {
    final updated = Map<String, bool>.from(paymentReminders.value);
    updated[month] = enabled;
    paymentReminders.value = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paymentRemindersKey, jsonEncode(updated));
  }

  bool hasPaymentReminder(String month) =>
      paymentReminders.value[month] ?? false;

  // ── Notification preferences (device-local) ───────────────────────────────

  Future<void> loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationPrefsKey);
    if (raw == null || raw.isEmpty) {
      notificationPrefs.value = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      notificationPrefs.value = decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      notificationPrefs.value = {};
    }
  }

  Future<void> setNotificationPref(String key, bool enabled) async {
    final updated = Map<String, bool>.from(notificationPrefs.value);
    updated[key] = enabled;
    notificationPrefs.value = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationPrefsKey, jsonEncode(updated));
  }

  /// Defaults to `true` for a key never explicitly set — the toggles have
  /// always defaulted on.
  bool notificationPrefFor(String key) => notificationPrefs.value[key] ?? true;

  List<String> getUpcomingPayments() {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final next = DateTime(now.year, now.month + 1);
    return [_monthKey(current), _monthKey(next)];
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  bool isPaymentDue(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return false;
    final year = int.tryParse(parts[0]);
    final monthNum = int.tryParse(parts[1]);
    if (year == null || monthNum == null) return false;

    // Last day of that month. DateTime normalises month 13 into January, so
    // this is safe for December without a special case.
    final dueDate = DateTime(
      year,
      monthNum + 1,
      1,
    ).subtract(const Duration(days: 1));
    return DateTime.now().isAfter(dueDate.subtract(const Duration(days: 5)));
  }
}

class DriverRatingInfo {
  final double rating;
  final DateTime ratedAt;

  const DriverRatingInfo({required this.rating, required this.ratedAt});

  Map<String, dynamic> toJson() => {
    'rating': rating,
    'ratedAt': ratedAt.toIso8601String(),
  };

  factory DriverRatingInfo.fromJson(Map<String, dynamic> json) {
    return DriverRatingInfo(
      rating: (json['rating'] as num).toDouble(),
      ratedAt: DateTime.parse(json['ratedAt'] as String),
    );
  }

  bool isSameWeek(DateTime now) {
    final startOfNowWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final ratedDate = DateTime(ratedAt.year, ratedAt.month, ratedAt.day);
    return !ratedDate.isBefore(startOfNowWeek);
  }
}
