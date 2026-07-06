import 'package:shared_preferences/shared_preferences.dart';

import '../utils/time.dart';

/// Verrouillage applicatif (PIN) — indépendant de la session locale et du JWT.
class AppLockController {
  AppLockController(this._prefs);

  static const _backgroundedAtKey = 'app_backgrounded_at_ms';

  final SharedPreferences _prefs;

  bool _unlockedThisProcess = false;
  int? _backgroundedAtMs;
  int _transientTaskCount = 0;

  bool get isLockSuppressed => _transientTaskCount > 0;

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
  }

  void markBackgrounded() {
    if (isLockSuppressed) return;
    final timestamp = nowMs();
    _backgroundedAtMs = timestamp;
    _unlockedThisProcess = false;
    _prefs.setInt(_backgroundedAtKey, timestamp);
  }

  /// Au cold start : PIN obligatoire si une boutique est installée.
  bool requiresPinOnColdStart({required bool setupComplete, required bool wasLoggedOut}) {
    if (!setupComplete || wasLoggedOut) return false;
    return !_unlockedThisProcess;
  }

  /// Au retour de l'arrière-plan : PIN après [autoLockMinutes] d'inactivité.
  bool requiresPinOnResume(int autoLockMinutes) {
    if (isLockSuppressed) return false;
    final backgroundedAt = _backgroundedAtMs ?? _prefs.getInt(_backgroundedAtKey);
    if (backgroundedAt == null) return false;
    final elapsedMs = nowMs() - backgroundedAt;
    return elapsedMs >= autoLockMinutes * 60 * 1000;
  }
}
