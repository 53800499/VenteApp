import '../../features/settings/data/datasources/local/settings_local_datasource.dart';
import 'cloud_sync_preferences.dart';

/// Active la sync cloud (V2) par défaut sauf refus explicite dans Paramètres.
class CloudSyncEnabler {
  CloudSyncEnabler({
    required SettingsLocalDatasource settingsLocal,
    required CloudSyncPreferences preferences,
  })  : _settingsLocal = settingsLocal,
        _preferences = preferences;

  final SettingsLocalDatasource _settingsLocal;
  final CloudSyncPreferences _preferences;

  /// Active la sync cloud (V2) par défaut sauf refus explicite dans Paramètres.
  Future<void> activateForShop(int shopId) async {
    if (_preferences.isUserDisabled(shopId)) return;

    final config = await _settingsLocal.loadConfiguration(shopId);
    if (config.sync.enabled) return;

    await _settingsLocal.setCloudSyncEnabled(shopId: shopId, enabled: true);
  }

  Future<void> setUserPreference({
    required int shopId,
    required bool enabled,
  }) async {
    await _preferences.setUserDisabled(shopId, !enabled);
    await _settingsLocal.setCloudSyncEnabled(shopId: shopId, enabled: enabled);
  }
}
