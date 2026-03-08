import 'dart:io';
import 'package:flutter/foundation.dart';

/// Singleton that holds the profile image chosen by each user role.
/// Any widget can observe changes via [ValueListenableBuilder].
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final ValueNotifier<File?> parentImage = ValueNotifier(null);
  final ValueNotifier<File?> studentImage = ValueNotifier(null);
  final ValueNotifier<File?> driverImage = ValueNotifier(null);
}
