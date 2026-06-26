import 'package:shared_preferences/shared_preferences.dart';

/// Préférences de parcours auth (déconnexion explicite vs verrouillage PIN).
class AuthFlowStorage {
  AuthFlowStorage(this._prefs);

  static const _loggedOutKey = 'auth_user_logged_out';

  final SharedPreferences _prefs;

  Future<void> markLoggedOut() async {
    await _prefs.setBool(_loggedOutKey, true);
  }

  Future<void> clearLoggedOut() async {
    await _prefs.setBool(_loggedOutKey, false);
  }

  Future<bool> wasLoggedOut() async => _prefs.getBool(_loggedOutKey) ?? false;
}
