import 'package:drift/drift.dart';

/// Table Drift pour les préférences strictement locales à l'appareil et à l'utilisateur.
@DataClassName('LocalAppPreferenceData')
class LocalAppPreferences extends Table {
  TextColumn get id => text().withDefault(const Constant('local_user'))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get language => text().withDefault(const Constant('fr'))();
  RealColumn get fontSizeScale => real().withDefault(const Constant(1.0))();
  BoolColumn get compactDashboard => boolean().withDefault(const Constant(false))();
  TextColumn get bluetoothPrinterMac => text().nullable()();
  TextColumn get bluetoothPrinterName => text().nullable()();
  IntColumn get paperWidthMm => integer().withDefault(const Constant(80))();
  BoolColumn get useBiometrics => boolean().withDefault(const Constant(false))();
  IntColumn get autoLockSeconds => integer().withDefault(const Constant(300))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table Drift pour les paramètres métier d'une boutique (syncables).
@DataClassName('LocalBusinessSettingData')
class LocalBusinessSettings extends Table {
  TextColumn get shopId => text()();
  TextColumn get tenantId => text()();
  TextColumn get settingsJson => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {shopId};
}

/// Table Drift pour les politiques administratives ARIKE (imposées par le Back-Office).
@DataClassName('LocalAdminPolicyData')
class LocalAdminPolicies extends Table {
  TextColumn get code => text()();
  TextColumn get valueJson => text()();
  BoolColumn get enforced => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  TextColumn get lockReason => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Table Drift pour les feature flags techniques.
@DataClassName('LocalFeatureFlagData')
class LocalFeatureFlags extends Table {
  TextColumn get key => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get rolloutPercentage => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Table Drift pour le suivi d'état global de la synchronisation de configuration.
@DataClassName('LocalConfigurationStateData')
class LocalConfigurationState extends Table {
  TextColumn get scope => text().withDefault(const Constant('current'))();
  TextColumn get tenantId => text().nullable()();
  TextColumn get shopId => text().nullable()();
  IntColumn get configurationVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastConfigSyncAt => dateTime()();
  DateTimeColumn get lastServerTime => dateTime()();

  @override
  Set<Column> get primaryKey => {scope};
}
