import 'package:shared_preferences/shared_preferences.dart';

import '../utils/benin_day_range.dart';
import '../utils/time.dart';
import 'pin_cold_start_policy.dart';

/// Verrouillage applicatif (PIN) — indépendant de la session locale et du JWT.
class AppLockController {
  AppLockController(this._prefs);

  static const _backgroundedAtKey = 'app_backgrounded_at_ms';
  static const _lastUnlockedAtKey = 'app_last_unlocked_at_ms';
  static const _pinColdStartPolicyKey = 'pin_cold_start_policy';

  static const _eightHoursMs = 8 * 60 * 60 * 1000;

  final SharedPreferences _prefs;

  bool _unlockedThisProcess = false;
  int? _backgroundedAtMs;
  int _transientTaskCount = 0;

  bool get isLockSuppressed => _transientTaskCount > 0;

  PinColdStartPolicy get pinColdStartPolicy =>
      PinColdStartPolicy.fromCode(_prefs.getString(_pinColdStartPolicyKey));

  Future<void> setPinColdStartPolicy(PinColdStartPolicy policy) async {
    await _prefs.setString(_pinColdStartPolicyKey, policy.code);
  }

  /// Empêche le verrouillage pendant une action système (galerie, fichier…).
  void beginTransientTask() {
    _transientTaskCount++;
  }

  void endTransientTask() {
    if (_transientTaskCount > 0) {
      _transientTaskCount--;
    }
  }

  Future<T> runWithLockSuppressed<T>(Future<T> Function() action) async {
    beginTransientTask();
    try {
      return await action();
    } finally {
      endTransientTask();
    }
  }

  void markUnlocked() {
    _unlockedThisProcess = true;
    _backgroundedAtMs = null;
    _prefs.remove(_backgroundedAtKey);
    _prefs.setInt(_lastUnlockedAtKey, nowMs());
  }

  void markBackgrounded() {
    if (isLockSuppressed) return;
    final timestamp = nowMs();
    _backgroundedAtMs = timestamp;
    _unlockedThisProcess = false;
    _prefs.setInt(_backgroundedAtKey, timestamp);
  }

  /// Au cold start : PIN selon la politique configurée.
  bool requiresPinOnColdStart({
    required bool setupComplete,
    required bool wasLoggedOut,
  }) {
    if (!setupComplete || wasLoggedOut) return false;
    if (_unlockedThisProcess) return false;

    final lastUnlockedAt = _prefs.getInt(_lastUnlockedAtKey);

    return switch (pinColdStartPolicy) {
      PinColdStartPolicy.always => true,
      PinColdStartPolicy.remember8Hours =>
        lastUnlockedAt == null || nowMs() - lastUnlockedAt >= _eightHoursMs,
      PinColdStartPolicy.rememberToday =>
        lastUnlockedAt == null ||
            lastUnlockedAt < getBeninDayBounds().dayStartMs,
    };
  }

  /// Au retour de l'arrière-plan : PIN après [autoLockMinutes] d'inactivité.
  bool requiresPinOnResume(int autoLockMinutes) {
    if (isLockSuppressed) return false;
    final backgroundedAt =
        _backgroundedAtMs ?? _prefs.getInt(_backgroundedAtKey);
    if (backgroundedAt == null) return false;
    final elapsedMs = nowMs() - backgroundedAt;
    return elapsedMs >= autoLockMinutes * 60 * 1000;
  }
}
