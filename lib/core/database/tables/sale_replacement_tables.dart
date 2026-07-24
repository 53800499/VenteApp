import 'package:drift/drift.dart';

import 'auth_tables.dart';
import 'commerce_tables.dart';

class SaleReplacements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get saleId => integer().references(Sales, #id)();
  TextColumn get number => text()();
  IntColumn get replacedAt => integer()();
  IntColumn get replacedBy => integer().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SaleReplacementItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get replacementId =>
      integer().references(SaleReplacements, #id)();
  IntColumn get returnedSaleItemId => integer().references(SaleItems, #id)();
  IntColumn get returnedProductId => integer().references(Products, #id)();
  IntColumn get quantityReturned => integer()();
  IntColumn get issuedProductId => integer().references(Products, #id)();
  IntColumn get quantityIssued => integer()();
  IntColumn get unitPriceIssued => integer()();
  TextColumn get reason => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}
