import 'package:flutter/material.dart';

/// Singleton ChangeNotifier that manages the active subscription plan across the app.
class SubscriptionProvider extends ChangeNotifier {
  static final SubscriptionProvider instance = SubscriptionProvider._();
  SubscriptionProvider._();

  String _plan = 'premium';

  String get plan => _plan;

  String get planDisplayName {
    switch (_plan) {
      case 'family':
        return 'Family';
      case 'basic':
        return 'Basic';
      default:
        return 'Premium';
    }
  }

  void setPlan(String plan) {
    if (_plan == plan) return;
    _plan = plan;
    notifyListeners();
  }
}
