class ShopSettingsApiDto {
  ShopSettingsApiDto({
    required this.name,
    this.phone,
    this.address,
    this.logoPath,
  });

  factory ShopSettingsApiDto.fromJson(Map<String, dynamic> json) {
    return ShopSettingsApiDto(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      logoPath: json['logoPath'] as String?,
    );
  }

  final String name;
  final String? phone;
  final String? address;
  final String? logoPath;
}

class LocalizationSettingsApiDto {
  LocalizationSettingsApiDto({
    required this.currency,
    required this.language,
  });

  factory LocalizationSettingsApiDto.fromJson(Map<String, dynamic> json) {
    return LocalizationSettingsApiDto(
      currency: json['currency'] as String? ?? 'FCFA',
      language: json['language'] as String? ?? 'fr',
    );
  }

  final String currency;
  final String language;
}

class InventorySettingsApiDto {
  InventorySettingsApiDto({required this.defaultAlertThreshold});

  factory InventorySettingsApiDto.fromJson(Map<String, dynamic> json) {
    return InventorySettingsApiDto(
      defaultAlertThreshold:
          (json['defaultAlertThreshold'] as num?)?.toInt() ?? 5,
    );
  }

  final int defaultAlertThreshold;
}

class SecuritySettingsApiDto {
  SecuritySettingsApiDto({required this.autoLockMinutes});

  factory SecuritySettingsApiDto.fromJson(Map<String, dynamic> json) {
    return SecuritySettingsApiDto(
      autoLockMinutes: (json['autoLockMinutes'] as num?)?.toInt() ?? 5,
    );
  }

  final int autoLockMinutes;
}

class ReceiptSettingsApiDto {
  ReceiptSettingsApiDto({this.footer});

  factory ReceiptSettingsApiDto.fromJson(Map<String, dynamic> json) {
    return ReceiptSettingsApiDto(footer: json['footer'] as String?);
  }

  final String? footer;
}

class BackupSettingsApiDto {
  BackupSettingsApiDto({
    this.lastAt,
    this.path,
    required this.reminderRecommended,
  });

  factory BackupSettingsApiDto.fromJson(Map<String, dynamic> json) {
    return BackupSettingsApiDto(
      lastAt: (json['lastAt'] as num?)?.toInt(),
      path: json['path'] as String?,
      reminderRecommended: json['reminderRecommended'] as bool? ?? true,
    );
  }

  final int? lastAt;
  final String? path;
  final bool reminderRecommended;
}

class SyncSettingsApiDto {
  SyncSettingsApiDto({
    required this.enabled,
    this.lastAt,
  });

  factory SyncSettingsApiDto.fromJson(Map<String, dynamic> json) {
    return SyncSettingsApiDto(
      enabled: json['enabled'] as bool? ?? false,
      lastAt: (json['lastAt'] as num?)?.toInt(),
    );
  }

  final bool enabled;
  final int? lastAt;
}

class ShopConfigurationApiDto {
  ShopConfigurationApiDto({
    required this.shop,
    required this.localization,
    required this.inventory,
    required this.security,
    required this.receipts,
    required this.backup,
    required this.sync,
    required this.updatedAt,
  });

  factory ShopConfigurationApiDto.fromJson(Map<String, dynamic> json) {
    return ShopConfigurationApiDto(
      shop: ShopSettingsApiDto.fromJson(
        json['shop'] as Map<String, dynamic>,
      ),
      localization: LocalizationSettingsApiDto.fromJson(
        json['localization'] as Map<String, dynamic>,
      ),
      inventory: InventorySettingsApiDto.fromJson(
        json['inventory'] as Map<String, dynamic>,
      ),
      security: SecuritySettingsApiDto.fromJson(
        json['security'] as Map<String, dynamic>,
      ),
      receipts: ReceiptSettingsApiDto.fromJson(
        json['receipts'] as Map<String, dynamic>,
      ),
      backup: BackupSettingsApiDto.fromJson(
        json['backup'] as Map<String, dynamic>,
      ),
      sync: SyncSettingsApiDto.fromJson(
        json['sync'] as Map<String, dynamic>,
      ),
      updatedAt: (json['updatedAt'] as num).toInt(),
    );
  }

  final ShopSettingsApiDto shop;
  final LocalizationSettingsApiDto localization;
  final InventorySettingsApiDto inventory;
  final SecuritySettingsApiDto security;
  final ReceiptSettingsApiDto receipts;
  final BackupSettingsApiDto backup;
  final SyncSettingsApiDto sync;
  final int updatedAt;
}

class RecordBackupResponseApiDto {
  RecordBackupResponseApiDto({
    required this.backup,
    required this.recordedAt,
  });

  factory RecordBackupResponseApiDto.fromJson(Map<String, dynamic> json) {
    return RecordBackupResponseApiDto(
      backup: BackupSettingsApiDto.fromJson(
        json['backup'] as Map<String, dynamic>,
      ),
      recordedAt: (json['recordedAt'] as num).toInt(),
    );
  }

  final BackupSettingsApiDto backup;
  final int recordedAt;
}
