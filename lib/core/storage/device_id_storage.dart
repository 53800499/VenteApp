import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

/// Identifiant stable de l'appareil requis par l'API (`deviceId` + `deviceLabel`).
class DeviceIdStorage {
  DeviceIdStorage(SharedPreferences prefs)
      : _prefs = prefs,
        _memory = null;

  DeviceIdStorage.inMemory() : _prefs = null, _memory = {};

  static const _deviceIdKey = 'device_id';

  final SharedPreferences? _prefs;
  final Map<String, String>? _memory;
  final _uuid = const Uuid();

  /// Génère ou récupère l'UUID appareil (min. 8 caractères, requis par l'API).
  Future<String> getOrCreate() async {
    final existing = _readSync(_deviceIdKey);
    if (existing != null && existing.length >= 8) return existing;

    final id = _uuid.v4();
    await _write(_deviceIdKey, id);
    return id;
  }

  /// Retourne le deviceId mis en cache s'il existe déjà.
  String? get cachedDeviceId => _readSync(_deviceIdKey);

  /// Tag court d'identification d'appareil (4 caractères alphanumériques)
  /// pour les numéros de reçus en mode déconnecté multi-terminaux.
  String get shortDeviceTag {
    var raw = cachedDeviceId;
    if (raw == null || raw.length < 8) {
      raw = _uuid.v4();
      _write(_deviceIdKey, raw);
    }
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    return sanitized.length >= 4 ? sanitized.substring(0, 4) : sanitized;
  }

  Future<({String deviceId, String deviceLabel})> getAuthDevice() async {
    final deviceId = await getOrCreate();
    return (deviceId: deviceId, deviceLabel: AppConstants.deviceLabel);
  }

  String? _readSync(String key) {
    final memory = _memory;
    if (memory != null) return memory[key];
    return _prefs!.getString(key);
  }

  Future<void> _write(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    await _prefs!.setString(key, value);
  }
}
