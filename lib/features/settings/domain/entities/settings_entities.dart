// Module 10 — Paramètres & Configuration boutique.

class ShopSettings {
  const ShopSettings({
    required this.name,
    this.phone,
    this.address,
    this.logoPath,
  });

  final String name;
  final String? phone;
  final String? address;
  final String? logoPath;
}

class LocalizationSettings {
  const LocalizationSettings({
    required this.currency,
    required this.language,
  });

  final String currency;
  final String language;
}

class InventorySettings {
  const InventorySettings({required this.defaultAlertThreshold});

  final int defaultAlertThreshold;
}

class SecuritySettings {
  const SecuritySettings({required this.autoLockMinutes});

  final int autoLockMinutes;
}

class ReceiptSettings {
  const ReceiptSettings({this.footer});

  final String? footer;
}

class BackupSettings {
  const BackupSettings({
    this.lastAt,
    this.path,
    required this.reminderRecommended,
  });

  final int? lastAt;
  final String? path;
  final bool reminderRecommended;
}

class SyncSettings {
  const SyncSettings({
    required this.enabled,
    this.lastAt,
  });

  final bool enabled;
  final int? lastAt;
}

class ShopConfiguration {
  const ShopConfiguration({
    required this.shop,
    required this.localization,
    required this.inventory,
    required this.security,
    required this.receipts,
    required this.backup,
    required this.sync,
    required this.updatedAt,
  });

  final ShopSettings shop;
  final LocalizationSettings localization;
  final InventorySettings inventory;
  final SecuritySettings security;
  final ReceiptSettings receipts;
  final BackupSettings backup;
  final SyncSettings sync;
  final int updatedAt;
}

class UpdateShopSettingsInput {
  const UpdateShopSettingsInput({
    this.shopName,
    this.shopPhone,
    this.shopAddress,
    this.shopLogoPath,
    this.defaultAlertThreshold,
    this.autoLockMinutes,
    this.receiptFooter,
  });

  final String? shopName;
  final String? shopPhone;
  final String? shopAddress;
  final String? shopLogoPath;
  final int? defaultAlertThreshold;
  final int? autoLockMinutes;
  final String? receiptFooter;

  bool get isEmpty =>
      shopName == null &&
      shopPhone == null &&
      shopAddress == null &&
      shopLogoPath == null &&
      defaultAlertThreshold == null &&
      autoLockMinutes == null &&
      receiptFooter == null;
}

class RecordBackupInput {
  const RecordBackupInput({this.path});

  final String? path;
}

class UpdateSyncSettingsInput {
  const UpdateSyncSettingsInput({
    this.enabled,
    this.lastSyncAt,
  });

  final bool? enabled;
  final int? lastSyncAt;

  bool get isEmpty => enabled == null && lastSyncAt == null;
}

class RecordBackupResult {
  const RecordBackupResult({
    required this.backup,
    required this.recordedAt,
  });

  final BackupSettings backup;
  final int recordedAt;
}

const backupReminderAgeMs = 7 * 24 * 60 * 60 * 1000;
const autoLockMinuteOptions = [1, 5, 15, 30, 60, 120];
