import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_config.dart';

class ApiSettingsStorage {
  ApiSettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  String resolveEffectiveUrl() =>
      ApiConfig.resolveBaseUrl(customUrl: _prefs.getString(ApiConfig.prefsKey));

  String? get customBaseUrl => _prefs.getString(ApiConfig.prefsKey);

  Future<void> saveCustomBaseUrl(String url) async {
    await _prefs.setString(
      ApiConfig.prefsKey,
      ApiConfig.normalizeUrl(url),
    );
  }

  Future<void> clearCustomBaseUrl() async {
    await _prefs.remove(ApiConfig.prefsKey);
  }
}
