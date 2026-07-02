import '../entities/settings_entities.dart';

abstract class SettingsRepository {
  Future<ShopConfiguration> getConfiguration({required int shopId});

  Future<ShopConfiguration> updateConfiguration({
    required int shopId,
    required UpdateShopSettingsInput input,
  });

  Future<RecordBackupResult> recordBackup({
    required int shopId,
    RecordBackupInput input = const RecordBackupInput(),
  });

  Future<SyncSettings> updateSyncSettings({
    required int shopId,
    required UpdateSyncSettingsInput input,
  });
}
