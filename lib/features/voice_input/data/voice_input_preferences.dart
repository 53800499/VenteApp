import 'package:shared_preferences/shared_preferences.dart';

/// Préférence appareil : saisie vocale activée (défaut true).
class VoiceInputPreferences {
  VoiceInputPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const keyEnabled = 'voice_input_enabled';

  bool get isEnabled => _prefs.getBool(keyEnabled) ?? true;

  Future<void> setEnabled(bool value) => _prefs.setBool(keyEnabled, value);
}
