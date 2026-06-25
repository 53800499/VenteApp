import 'package:shared_preferences/shared_preferences.dart';

/// Persistance du statut de présentation initiale (onboarding).
class OnboardingStorage {
  OnboardingStorage(this._prefs);

  static const _completedKey = 'onboarding_completed';

  final SharedPreferences _prefs;

  Future<bool> isCompleted() async => _prefs.getBool(_completedKey) ?? false;

  Future<void> markCompleted() async {
    await _prefs.setBool(_completedKey, true);
  }
}
