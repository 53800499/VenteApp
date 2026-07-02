import 'package:drift/drift.dart';

import 'auth_tables.dart';

/// File d'attente cloud (BDD table 14 — créée en V1, utilisée à partir de V2).
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get entityTable => text().named('table_name')();
  IntColumn get recordId => integer()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get localVersion => integer()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get createdAt => integer()();
  IntColumn get processedAt => integer().nullable()();
}
