import 'package:flutter/material.dart';

import '../services/local_storage_service.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider(this._localStorageService);

  final LocalStorageService _localStorageService;

  bool _isCompleted = false;
  bool _isLoading = false;

  bool get isCompleted => _isCompleted;
  bool get isLoading => _isLoading;

  Future<void> loadStatus() async {
    _isLoading = true;
    notifyListeners();

    _isCompleted = await _localStorageService.getOnboardingCompleted();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _isCompleted = true;
    await _localStorageService.setOnboardingCompleted(true);
    notifyListeners();
  }
}
