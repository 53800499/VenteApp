import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../../domain/services/settings_validation_service.dart';

class SettingsLocalDatasource {
  SettingsLocalDatasource(this._database);

  final db.AppDatabase _database;

  static bool _readSqlBool(Object? value, {bool defaultValue = true}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return defaultValue;
  }

  static int _readSqlInt(Object? value, {required int defaultValue}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static String _readSqlString(Object? value, {required String defaultValue}) {
    if (value == null) return defaultValue;
    if (value is String && value.isNotEmpty) return value;
    return defaultValue;
  }

  Future<int> _ensureSettingsId(int shopId) async {
    final existing = await _database.customSelect(
      'SELECT id FROM settings WHERE shop_id = ? LIMIT 1',
      variables: [Variable.withInt(shopId)],
      readsFrom: {_database.settings},
    ).getSingleOrNull();

    if (existing != null) {
      return existing.read<int>('id');
    }

    return _database.into(_database.settings).insert(
          db.SettingsCompanion.insert(
            shopId: shopId,
            updatedAt: nowMs(),
          ),
        );
  }

  ShopConfiguration _mapRow(Map<String, Object?> data, {int? now}) {
    final timestamp = now ?? nowMs();
    final backupLastAt = data['backup_last_at'] == null
        ? null
        : _readSqlInt(data['backup_last_at'], defaultValue: 0);
    final backupOverdue = backupLastAt == null ||
        timestamp - backupLastAt >= backupReminderAgeMs;

    return ShopConfiguration(
      shop: ShopSettings(
        name: _readSqlString(data['shop_name'], defaultValue: 'Ma Boutique'),
        phone: data['shop_phone'] as String?,
        address: data['shop_address'] as String?,
        logoPath: data['shop_logo_path'] as String?,
      ),
      localization: LocalizationSettings(
        currency: _readSqlString(data['currency'], defaultValue: 'FCFA'),
        language: _readSqlString(data['language'], defaultValue: 'fr'),
      ),
      inventory: InventorySettings(
        defaultAlertThreshold: _readSqlInt(
          data['default_alert_threshold'],
          defaultValue: 5,
        ),
      ),
      security: SecuritySettings(
        autoLockMinutes: const SettingsValidationService()
            .normalizeAutoLockMinutes(
          _readSqlInt(data['auto_lock_minutes'], defaultValue: 5),
        ),
      ),
      receipts: ReceiptSettings(
        footer: data['receipt_footer'] as String?,
      ),
      backup: BackupSettings(
        lastAt: backupLastAt,
        path: data['backup_path'] as String?,
        reminderRecommended: backupOverdue,
      ),
      sync: SyncSettings(
        enabled: _readSqlBool(data['cloud_sync_enabled'], defaultValue: true),
        lastAt: data['cloud_last_sync_at'] == null
            ? null
            : _readSqlInt(data['cloud_last_sync_at'], defaultValue: 0),
      ),
      updatedAt: _readSqlInt(data['updated_at'], defaultValue: timestamp),
    );
  }

  Future<ShopConfiguration> loadConfiguration(int shopId) async {
    await _ensureSettingsId(shopId);

    final row = await _database.customSelect(
      '''
      SELECT
        shop_name,
        shop_phone,
        shop_address,
        shop_logo_path,
        currency,
        language,
        default_alert_threshold,
        auto_lock_minutes,
        receipt_footer,
        backup_last_at,
        backup_path,
        cloud_sync_enabled,
        cloud_last_sync_at,
        updated_at
      FROM settings
      WHERE shop_id = ?
      LIMIT 1
      ''',
      variables: [Variable.withInt(shopId)],
      readsFrom: {_database.settings},
    ).getSingleOrNull();

    if (row == null) {
      return _mapRow(const {});
    }

    return _mapRow(row.data);
  }

  Future<ShopConfiguration> updateConfiguration({
    required int shopId,
    required UpdateShopSettingsInput input,
  }) async {
    final settingsId = await _ensureSettingsId(shopId);
    final timestamp = nowMs();

    await (_database.update(_database.settings)
          ..where((s) => s.id.equals(settingsId)))
        .write(
      db.SettingsCompanion(
        shopName: input.shopName == null
            ? const Value.absent()
            : Value(input.shopName!.trim()),
        shopPhone: input.shopPhone == null
            ? const Value.absent()
            : Value(input.shopPhone!.trim().isEmpty ? null : input.shopPhone),
        shopAddress: input.shopAddress == null
            ? const Value.absent()
            : Value(
                input.shopAddress!.trim().isEmpty ? null : input.shopAddress,
              ),
        shopLogoPath: input.shopLogoPath == null
            ? const Value.absent()
            : Value(input.shopLogoPath),
        defaultAlertThreshold: input.defaultAlertThreshold == null
            ? const Value.absent()
            : Value(input.defaultAlertThreshold!),
        autoLockMinutes: input.autoLockMinutes == null
            ? const Value.absent()
            : Value(input.autoLockMinutes!),
        receiptFooter: input.receiptFooter == null
            ? const Value.absent()
            : Value(
                input.receiptFooter!.trim().isEmpty ? null : input.receiptFooter,
              ),
        updatedAt: Value(timestamp),
      ),
    );

    if (input.shopName != null ||
        input.shopPhone != null ||
        input.shopAddress != null) {
      await (_database.update(_database.shops)..where((s) => s.id.equals(shopId)))
          .write(
        db.ShopsCompanion(
          name: input.shopName == null
              ? const Value.absent()
              : Value(input.shopName!.trim()),
          phone: input.shopPhone == null
              ? const Value.absent()
              : Value(
                  input.shopPhone!.trim().isEmpty ? null : input.shopPhone,
                ),
          address: input.shopAddress == null
              ? const Value.absent()
              : Value(
                  input.shopAddress!.trim().isEmpty ? null : input.shopAddress,
                ),
        ),
      );
    }

    return loadConfiguration(shopId);
  }

  Future<RecordBackupResult> recordBackup({
    required int shopId,
    RecordBackupInput input = const RecordBackupInput(),
  }) async {
    final settingsId = await _ensureSettingsId(shopId);
    final recordedAt = nowMs();

    await (_database.update(_database.settings)
          ..where((s) => s.id.equals(settingsId)))
        .write(
      db.SettingsCompanion(
        backupLastAt: Value(recordedAt),
        backupPath: Value(input.path?.trim()),
        updatedAt: Value(recordedAt),
      ),
    );

    final config = await loadConfiguration(shopId);
    return RecordBackupResult(
      backup: config.backup,
      recordedAt: recordedAt,
    );
  }

  Future<SyncSettings> updateSyncSettings({
    required int shopId,
    required UpdateSyncSettingsInput input,
  }) async {
    final settingsId = await _ensureSettingsId(shopId);
    final timestamp = nowMs();

    await (_database.update(_database.settings)
          ..where((s) => s.id.equals(settingsId)))
        .write(
      db.SettingsCompanion(
        cloudSyncEnabled: input.enabled == null
            ? const Value.absent()
            : Value(input.enabled!),
        cloudLastSyncAt: input.lastSyncAt == null
            ? const Value.absent()
            : Value(input.lastSyncAt),
        updatedAt: Value(timestamp),
      ),
    );

    final config = await loadConfiguration(shopId);
    return config.sync;
  }

  Future<void> setCloudSyncEnabled({
    required int shopId,
    required bool enabled,
    int? lastSyncAt,
  }) async {
    final settingsId = await _ensureSettingsId(shopId);
    final timestamp = nowMs();

    await (_database.update(_database.settings)
          ..where((s) => s.id.equals(settingsId)))
        .write(
      db.SettingsCompanion(
        cloudSyncEnabled: Value(enabled),
        cloudLastSyncAt: lastSyncAt == null
            ? const Value.absent()
            : Value(lastSyncAt),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> touchCloudLastSyncAt(int shopId) async {
    final settingsId = await _ensureSettingsId(shopId);
    final timestamp = nowMs();
    await (_database.update(_database.settings)
          ..where((s) => s.id.equals(settingsId)))
        .write(
      db.SettingsCompanion(
        cloudLastSyncAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }
}
