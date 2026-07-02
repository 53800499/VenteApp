import '../../../../core/network/remote_api_runner.dart';
import '../../../../core/sync/cloud_sync_enabler.dart';
import '../../domain/entities/settings_entities.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/local/settings_local_datasource.dart';
import '../datasources/remote/settings_remote_datasource.dart';
import '../mappers/settings_mapper.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required SettingsLocalDatasource local,
    required SettingsRemoteDatasource remote,
    required RemoteApiRunner apiRunner,
    required CloudSyncEnabler cloudSyncEnabler,
  })  : _local = local,
        _remote = remote,
        _apiRunner = apiRunner,
        _cloudSyncEnabler = cloudSyncEnabler;

  final SettingsLocalDatasource _local;
  final SettingsRemoteDatasource _remote;
  final RemoteApiRunner _apiRunner;
  final CloudSyncEnabler _cloudSyncEnabler;

  static const _writeOfflineMessage =
      'Modification impossible hors ligne. Réessayez à la reconnexion.';

  @override
  Future<ShopConfiguration> getConfiguration({required int shopId}) async {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final remote = await _remote.fetchConfiguration();
        return SettingsMapper.fromApi(remote);
      },
      localFallback: () => _local.loadConfiguration(shopId),
    );
  }

  @override
  Future<ShopConfiguration> updateConfiguration({
    required int shopId,
    required UpdateShopSettingsInput input,
  }) async {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final remote = await _remote.updateConfiguration(
          SettingsMapper.updateToApi(input),
        );
        await _local.updateConfiguration(shopId: shopId, input: input);
        return SettingsMapper.fromApi(remote);
      },
    );
  }

  @override
  Future<RecordBackupResult> recordBackup({
    required int shopId,
    RecordBackupInput input = const RecordBackupInput(),
  }) async {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final remote = await _remote.recordBackup(
          SettingsMapper.backupToApi(input),
        );
        await _local.recordBackup(shopId: shopId, input: input);
        return SettingsMapper.backupFromApi(remote);
      },
    );
  }

  @override
  Future<SyncSettings> updateSyncSettings({
    required int shopId,
    required UpdateSyncSettingsInput input,
  }) async {
    if (input.enabled != null) {
      await _cloudSyncEnabler.setUserPreference(
        shopId: shopId,
        enabled: input.enabled!,
      );
      final local = await _local.loadConfiguration(shopId);
      try {
        await _remote.updateSyncSettings(SettingsMapper.syncToApi(input));
      } on Object {
        // Préférence locale conservée — propagation au prochain cycle en ligne.
      }
      return local.sync;
    }

    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final remote = await _remote.updateSyncSettings(
          SettingsMapper.syncToApi(input),
        );
        await _local.updateSyncSettings(shopId: shopId, input: input);
        return SettingsMapper.syncFromApi(remote);
      },
    );
  }
}
