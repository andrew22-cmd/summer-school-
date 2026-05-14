import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  static const String _classMembersStageNormMigratedKey =
      'class_members_stage_norm_migrated_v1';

  Future<bool> getOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, value);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }

  Future<void> setSavedEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove(_savedEmailKey);
    } else {
      await prefs.setString(_savedEmailKey, email);
    }
  }

  Future<bool> getClassMembersStageNormMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_classMembersStageNormMigratedKey) ?? false;
  }

  Future<void> setClassMembersStageNormMigrated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_classMembersStageNormMigratedKey, value);
  }
}
