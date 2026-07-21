import 'package:drift/drift.dart';

class Shops extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant('Ma Boutique'))();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  IntColumn get ownerUserId => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(true))();
  IntColumn get parentShopId => integer().nullable().references(Shops, #id)();
  IntColumn get createdAt => integer()();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get name => text()();
  TextColumn get pinHash => text()();
  /// PIN local encore provisoire (hash aléatoire créé après connexion WhatsApp
  /// sur un nouvel appareil) : autorise une validation serveur au 1er PIN.
  BoolColumn get pinProvisional =>
      boolean().withDefault(const Constant(false))();
  TextColumn get role =>
      text().withDefault(const Constant('owner'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get avatarPath => text().nullable()();
  IntColumn get lastLoginAt => integer().nullable()();
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  IntColumn get lockedUntil => integer().nullable()();
  IntColumn get lockoutCount => integer().withDefault(const Constant(0))();
  TextColumn get emergencyRecoveryHash => text().nullable()();
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get shopName =>
      text().withDefault(const Constant('Ma Boutique'))();
  TextColumn get shopPhone => text().nullable()();
  TextColumn get shopAddress => text().nullable()();
  TextColumn get shopLogoPath => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('FCFA'))();
  TextColumn get language => text().withDefault(const Constant('fr'))();
  IntColumn get defaultAlertThreshold =>
      integer().withDefault(const Constant(5))();
  TextColumn get dailySummaryTime =>
      text().withDefault(const Constant('20:00'))();
  BoolColumn get enableStockAlerts =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get enableDebtReminders =>
      boolean().withDefault(const Constant(true))();
  IntColumn get debtReminderDays =>
      integer().withDefault(const Constant(7))();
  BoolColumn get enableDailySummary =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get enableBackupReminder =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get enableGoodDayAlert =>
      boolean().withDefault(const Constant(true))();
  TextColumn get receiptFooter => text().nullable()();
  IntColumn get backupLastAt => integer().nullable()();
  TextColumn get backupPath => text().nullable()();
  BoolColumn get cloudSyncEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get cloudLastSyncAt => integer().nullable()();
  IntColumn get autoLockMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get pricingTiersEnabled =>
      boolean().withDefault(const Constant(false))();
  /// Seuil FCFA au-delà duquel un client est obligatoire sur une op FX (0 = jamais).
  IntColumn get fxCustomerRequiredAboveFcfa =>
      integer().withDefault(const Constant(0))();
  /// Accès direct : onglet Change en racine (usage cambiste).
  BoolColumn get fxPrimaryWorkspace =>
      boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();
}

class AuthSessions extends Table {
  TextColumn get id => text()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get pinVerifiedAt => integer()();
  IntColumn get expiresAt => integer()();
  IntColumn get lastActivityAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get action => text()();
  TextColumn get module => text()();
  IntColumn get entityId => integer()();
  TextColumn get entityTable => text()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get ipOrDevice => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get syncedAt => integer().nullable()();
}

/// Snapshot du contexte identité (offline) issu de GET /auth/identity.
class IdentitySnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userServerId => integer()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAt => integer()();
}
