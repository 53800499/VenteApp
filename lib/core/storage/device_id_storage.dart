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
