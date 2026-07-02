import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise le refus explicite de sync cloud (toggle Paramètres).
class CloudSyncPreferences {
  CloudSyncPreferences(this._prefs);

  final SharedPreferences _prefs;

  static String _disabledKey(int shopId) => 'cloud_sync_user_disabled_$shopId';

  bool isUserDisabled(int shopId) =>
      _prefs.getBool(_disabledKey(shopId)) ?? false;

  Future<void> setUserDisabled(int shopId, bool disabled) async {
    if (disabled) {
      await _prefs.setBool(_disabledKey(shopId), true);
    } else {
      await _prefs.remove(_disabledKey(shopId));
    }
  }
}
