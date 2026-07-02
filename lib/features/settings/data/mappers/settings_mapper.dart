import '../../domain/entities/settings_entities.dart';
import '../models/settings_api_models.dart';

class SettingsMapper {
  static ShopConfiguration fromApi(ShopConfigurationApiDto dto) {
    return ShopConfiguration(
      shop: ShopSettings(
        name: dto.shop.name,
        phone: dto.shop.phone,
        address: dto.shop.address,
        logoPath: dto.shop.logoPath,
      ),
      localization: LocalizationSettings(
        currency: dto.localization.currency,
        language: dto.localization.language,
      ),
      inventory: InventorySettings(
        defaultAlertThreshold: dto.inventory.defaultAlertThreshold,
      ),
      security: SecuritySettings(
        autoLockMinutes: dto.security.autoLockMinutes,
      ),
      receipts: ReceiptSettings(footer: dto.receipts.footer),
      backup: BackupSettings(
        lastAt: dto.backup.lastAt,
        path: dto.backup.path,
        reminderRecommended: dto.backup.reminderRecommended,
      ),
      sync: SyncSettings(
        enabled: dto.sync.enabled,
        lastAt: dto.sync.lastAt,
      ),
      updatedAt: dto.updatedAt,
    );
  }

  static RecordBackupResult backupFromApi(RecordBackupResponseApiDto dto) {
    return RecordBackupResult(
      backup: BackupSettings(
        lastAt: dto.backup.lastAt,
        path: dto.backup.path,
        reminderRecommended: dto.backup.reminderRecommended,
      ),
      recordedAt: dto.recordedAt,
    );
  }

  static SyncSettings syncFromApi(SyncSettingsApiDto dto) {
    return SyncSettings(enabled: dto.enabled, lastAt: dto.lastAt);
  }

  static Map<String, dynamic> updateToApi(UpdateShopSettingsInput input) {
    return {
      if (input.shopName != null) 'shopName': input.shopName,
      if (input.shopPhone != null) 'shopPhone': input.shopPhone,
      if (input.shopAddress != null) 'shopAddress': input.shopAddress,
      if (input.shopLogoPath != null) 'shopLogoPath': input.shopLogoPath,
      if (input.defaultAlertThreshold != null)
        'defaultAlertThreshold': input.defaultAlertThreshold,
      if (input.autoLockMinutes != null)
        'autoLockMinutes': input.autoLockMinutes,
      if (input.receiptFooter != null) 'receiptFooter': input.receiptFooter,
    };
  }

  static Map<String, dynamic> syncToApi(UpdateSyncSettingsInput input) {
    return {
      if (input.enabled != null) 'enabled': input.enabled,
      if (input.lastSyncAt != null) 'lastSyncAt': input.lastSyncAt,
    };
  }

  static Map<String, dynamic> backupToApi(RecordBackupInput input) {
    return {
      if (input.path != null) 'path': input.path,
    };
  }
}
