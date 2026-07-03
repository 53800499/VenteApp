import 'package:shared_preferences/shared_preferences.dart';

import '../utils/time.dart';

/// Verrouillage applicatif (PIN) — indépendant de la session locale et du JWT.
class AppLockController {
  AppLockController(this._prefs);

  static const _backgroundedAtKey = 'app_backgrounded_at_ms';

  final SharedPreferences _prefs;

  bool _unlockedThisProcess = false;
  int? _backgroundedAtMs;

  void markUnlocked() {
    _unlockedThisProcess = true;
    _backgroundedAtMs = null;
    _prefs.remove(_backgroundedAtKey);
  }

  void markBackgrounded() {
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
    final backgroundedAt = _backgroundedAtMs ?? _prefs.getInt(_backgroundedAtKey);
    if (backgroundedAt == null) return false;
    final elapsedMs = nowMs() - backgroundedAt;
    return elapsedMs >= autoLockMinutes * 60 * 1000;
  }
}
