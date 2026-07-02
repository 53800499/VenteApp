import '../../../../core/errors/failures.dart';
import '../../../../core/backup/shop_backup_service.dart';
import '../entities/settings_entities.dart';
import '../repositories/settings_repository.dart';
import '../services/settings_validation_service.dart';

class GetShopConfiguration {
  const GetShopConfiguration(this._repository);

  final SettingsRepository _repository;

  Future<ShopConfiguration> call({required int shopId}) =>
      _repository.getConfiguration(shopId: shopId);
}

class UpdateShopConfiguration {
  const UpdateShopConfiguration(
    this._repository,
    this._validation,
  );

  final SettingsRepository _repository;
  final SettingsValidationService _validation;

  Future<ShopConfiguration> call({
    required int shopId,
    required UpdateShopSettingsInput input,
  }) async {
    if (input.isEmpty) {
      throw const ValidationFailure('Aucun paramètre à mettre à jour.');
    }
    if (input.shopName != null) {
      _validation.assertShopName(input.shopName);
    }
    if (input.defaultAlertThreshold != null) {
      _validation.assertDefaultAlertThreshold(input.defaultAlertThreshold!);
    }
    if (input.autoLockMinutes != null) {
      _validation.assertAutoLockMinutes(input.autoLockMinutes!);
    }
    if (input.receiptFooter != null) {
      _validation.assertReceiptFooter(input.receiptFooter);
    }

    return _repository.updateConfiguration(shopId: shopId, input: input);
  }
}

class RecordShopBackup {
  const RecordShopBackup(this._repository);

  final SettingsRepository _repository;

  Future<RecordBackupResult> call({
    required int shopId,
    RecordBackupInput input = const RecordBackupInput(),
  }) =>
      _repository.recordBackup(shopId: shopId, input: input);
}

class UpdateShopSyncSettings {
  const UpdateShopSyncSettings(this._repository);

  final SettingsRepository _repository;

  Future<SyncSettings> call({
    required int shopId,
    required UpdateSyncSettingsInput input,
  }) {
    if (input.isEmpty) {
      throw const ValidationFailure(
        'Aucun paramètre de synchronisation à mettre à jour.',
      );
    }
    return _repository.updateSyncSettings(shopId: shopId, input: input);
  }
}

class CreateShopBackup {
  const CreateShopBackup(this._backup, this._recordBackup);

  final ShopBackupService _backup;
  final RecordShopBackup _recordBackup;

  Future<ShopBackupFile> call({
    required int shopId,
    required String shopName,
    required String passphrase,
  }) async {
    final file = await _backup.createEncryptedBackup(
      shopId: shopId,
      shopName: shopName,
      passphrase: passphrase,
    );
    await _recordBackup(
      shopId: shopId,
      input: RecordBackupInput(path: file.filename),
    );
    return file;
  }
}

class RestoreShopBackup {
  const RestoreShopBackup(this._backup);

  final ShopBackupService _backup;

  Future<void> call({
    required int shopId,
    required List<int> bytes,
    required String passphrase,
  }) {
    return _backup.restoreEncryptedBackup(
      shopId: shopId,
      bytes: bytes,
      passphrase: passphrase,
    );
  }
}

class ExportShopJson {
  const ExportShopJson(this._backup);

  final ShopBackupService _backup;

  Future<ShopJsonExport> call({
    required int shopId,
    required String shopName,
  }) {
    return _backup.exportReadableJson(shopId: shopId, shopName: shopName);
  }
}
