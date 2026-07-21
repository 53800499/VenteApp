import 'package:drift/drift.dart';

import 'auth_tables.dart';

class FxCurrencies extends Table {
  TextColumn get code => text()();
  TextColumn get label => text()();
  TextColumn get symbol => text()();
  IntColumn get minorUnit => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

class FxShopCurrencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get currencyCode => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class FxRateSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get baseCurrency => text().withDefault(const Constant('XOF'))();
  TextColumn get quoteCurrency => text()();
  IntColumn get buyRateNumerator => integer()();
  IntColumn get buyRateDenominator => integer()();
  IntColumn get sellRateNumerator => integer()();
  IntColumn get sellRateDenominator => integer()();
  IntColumn get effectiveAt => integer()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class FxSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get openedBy => integer().references(Users, #id)();
  IntColumn get closedBy => integer().nullable().references(Users, #id)();
  IntColumn get openedAt => integer()();
  IntColumn get closedAt => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get closingNote => text().nullable()();
  IntColumn get totalMarginFcfa => integer().withDefault(const Constant(0))();
  IntColumn get operationCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class FxSessionBalances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get sessionId => integer().references(FxSessions, #id)();
  TextColumn get currencyCode => text()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  IntColumn get expectedBalance => integer().nullable()();
  IntColumn get countedBalance => integer().nullable()();
  IntColumn get difference => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

/// Taux figés pour une session (politique : gel à l'ouverture, MAJ contrôlée).
class FxSessionRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get sessionId => integer().references(FxSessions, #id)();
  TextColumn get quoteCurrency => text()();
  IntColumn get rateSnapshotId =>
      integer().references(FxRateSnapshots, #id)();
  IntColumn get appliedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class FxOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get sessionId => integer().references(FxSessions, #id)();
  TextColumn get operationType => text()();
  TextColumn get fromCurrency => text()();
  IntColumn get fromAmount => integer()();
  TextColumn get toCurrency => text()();
  IntColumn get toAmount => integer()();
  IntColumn get rateSnapshotId => integer().nullable()();
  IntColumn get marginFcfa => integer().withDefault(const Constant(0))();
  IntColumn get customerId => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class FxMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get sessionId => integer().references(FxSessions, #id)();
  TextColumn get currencyCode => text()();
  TextColumn get movementType => text()();
  IntColumn get amount => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}
