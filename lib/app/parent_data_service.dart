import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mutable model for a single child registered under a parent account.
class ChildInfo {
  String name;
  String grade;
  String school;
  String busNumber;
  String route;
  String stop;
  String driver;

  ChildInfo({
    this.name = '',
    this.grade = '',
    this.school = '',
    this.busNumber = '',
    this.route = '',
    this.stop = '',
    this.driver = '',
  });

  ChildInfo copyWith({
    String? name,
    String? grade,
    String? school,
    String? busNumber,
    String? route,
    String? stop,
    String? driver,
  }) => ChildInfo(
    name: name ?? this.name,
    grade: grade ?? this.grade,
    school: school ?? this.school,
    busNumber: busNumber ?? this.busNumber,
    route: route ?? this.route,
    stop: stop ?? this.stop,
    driver: driver ?? this.driver,
  );
}

/// Mutable model for the parent's own profile info.
class ParentInfo {
  String name;
  String email;
  String phone;

  ParentInfo({
    this.name = 'Sarah Johnson',
    this.email = 'sarah@example.com',
    this.phone = '+1 555-0100',
  });
}

/// Singleton that holds the parent's profile data and notifies listeners
/// whenever the data changes.
class ParentDataService {
  ParentDataService._();
  static final ParentDataService instance = ParentDataService._();

  static const _driverRatingsKey = 'parent_driver_ratings';

  /// Notifier for the parent's own info.
  final parentInfo = ValueNotifier<ParentInfo>(ParentInfo());

  /// Notifier for the list of children.
  final children = ValueNotifier<List<ChildInfo>>([
    ChildInfo(
      name: 'Emma Johnson',
      grade: 'Grade 5',
      school: 'Lincoln Elementary School',
      busNumber: 'Bus #42',
      route: 'Route A',
      stop: 'Oak Street',
      driver: 'Mike T.',
    ),
  ]);

  /// Per-child photo files (same length as [children]).
  final childImages = ValueNotifier<List<File?>>([null]);

  /// Index of the currently-selected child (used by dashboard / tracking).
  final selectedChildIndex = ValueNotifier<int>(0);

  /// Persisted weekly driver ratings, keyed by bus + driver.
  final driverRatings = ValueNotifier<Map<String, DriverRatingInfo>>({});

  // ── helpers ────────────────────────────────────────────────────────────────

  ChildInfo? get selectedChild {
    final list = children.value;
    final idx = selectedChildIndex.value;
    if (list.isEmpty) return null;
    return list[idx.clamp(0, list.length - 1)];
  }

  File? get selectedChildImage {
    final imgs = childImages.value;
    final idx = selectedChildIndex.value;
    if (imgs.isEmpty) return null;
    return imgs[idx.clamp(0, imgs.length - 1)];
  }

  String _driverKey(ChildInfo child) => '${child.busNumber}|${child.driver}';

  Future<void> loadDriverRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_driverRatingsKey);
    if (raw == null || raw.isEmpty) {
      driverRatings.value = {};
      return;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    driverRatings.value = decoded.map(
      (key, value) => MapEntry(
        key,
        DriverRatingInfo.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  bool canRateDriver(ChildInfo child) {
    final info = driverRatings.value[_driverKey(child)];
    if (info == null) return true;
    return !info.isSameWeek(DateTime.now());
  }

  DriverRatingInfo? driverRatingFor(ChildInfo child) {
    return driverRatings.value[_driverKey(child)];
  }

  Future<void> rateDriverForChild(ChildInfo child, double rating) async {
    final key = _driverKey(child);
    final updated = Map<String, DriverRatingInfo>.from(driverRatings.value);
    updated[key] = DriverRatingInfo(rating: rating, ratedAt: DateTime.now());
    driverRatings.value = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _driverRatingsKey,
      jsonEncode(updated.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  void updateParentInfo(ParentInfo info) {
    parentInfo.value = info;
  }

  void updateChild(int index, ChildInfo child) {
    final list = List<ChildInfo>.from(children.value);
    list[index] = child;
    children.value = list;
  }

  void updateChildImage(int index, File? image) {
    final imgs = List<File?>.from(childImages.value);
    while (imgs.length <= index) {
      imgs.add(null);
    }
    imgs[index] = image;
    childImages.value = List.unmodifiable(imgs);
  }

  void addChild(ChildInfo child) {
    children.value = [...children.value, child];
    childImages.value = [...childImages.value, null];
  }

  void removeChild(int index) {
    final list = List<ChildInfo>.from(children.value);
    list.removeAt(index);
    children.value = list;

    final imgs = List<File?>.from(childImages.value);
    if (index < imgs.length) imgs.removeAt(index);
    childImages.value = imgs;

    // Keep selected index in bounds
    if (selectedChildIndex.value >= list.length && list.isNotEmpty) {
      selectedChildIndex.value = list.length - 1;
    }
  }

  void selectChild(int index) {
    selectedChildIndex.value = index.clamp(0, children.value.length - 1);
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
