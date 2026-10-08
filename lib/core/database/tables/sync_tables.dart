import 'package:drift/drift.dart';

import 'auth_tables.dart';

/// File d'attente cloud (BDD table 14 — créée en V1, utilisée à partir de V2).
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get domain => text().withDefault(const Constant('SALES'))();
  TextColumn get entityTable => text().named('table_name')();
  IntColumn get recordId => integer()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  TextColumn get idempotencyKey => text().nullable()();
  TextColumn get businessCriticality => text().withDefault(const Constant('NORMAL'))();
  IntColumn get basePriority => integer().withDefault(const Constant(10))();
  IntColumn get dependencyBoost => integer().withDefault(const Constant(0))();
  IntColumn get localVersion => integer()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get suggestedAction => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get processedAt => integer().nullable()();
  IntColumn get discardedAt => integer().nullable()();
  IntColumn get discardedBy => integer().nullable()();
  TextColumn get discardReason => text().nullable()();
}

/// Horodatage du dernier pull cloud par entité (stale time navigation).
class SyncEntityCache extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get entity => text()();
  IntColumn get lastSyncedAt => integer()();

  @override
  Set<Column> get primaryKey => {shopId, entity};
}
