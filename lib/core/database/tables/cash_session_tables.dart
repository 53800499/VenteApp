import 'package:drift/drift.dart';

import 'auth_tables.dart';

class CashSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get openedBy => integer().references(Users, #id)();
  IntColumn get closedBy => integer().nullable().references(Users, #id)();
  IntColumn get openedAt => integer()();
  IntColumn get closedAt => integer().nullable()();
  IntColumn get openingCash => integer().withDefault(const Constant(0))();
  IntColumn get openingMomo => integer().withDefault(const Constant(0))();
  IntColumn get salesCash => integer().withDefault(const Constant(0))();
  IntColumn get salesMomo => integer().withDefault(const Constant(0))();
  IntColumn get expensesCash => integer().withDefault(const Constant(0))();
  IntColumn get expensesMomo => integer().withDefault(const Constant(0))();
  IntColumn get depositsCash => integer().withDefault(const Constant(0))();
  IntColumn get depositsMomo => integer().withDefault(const Constant(0))();
  IntColumn get withdrawalsCash => integer().withDefault(const Constant(0))();
  IntColumn get withdrawalsMomo => integer().withDefault(const Constant(0))();
  IntColumn get expectedCash => integer().nullable()();
  IntColumn get expectedMomo => integer().nullable()();
  IntColumn get countedCash => integer().nullable()();
  IntColumn get countedMomo => integer().nullable()();
  IntColumn get differenceCash => integer().nullable()();
  IntColumn get differenceMomo => integer().nullable()();
  IntColumn get saleCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get closingNote => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class CashMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get sessionId => integer().references(CashSessions, #id)();
  TextColumn get movementType => text()();
  TextColumn get registerType => text().withDefault(const Constant('cash'))();
  IntColumn get amount => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}
