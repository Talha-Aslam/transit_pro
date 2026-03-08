import 'dart:io';
import 'package:flutter/foundation.dart';

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
