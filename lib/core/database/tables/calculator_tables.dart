import 'package:drift/drift.dart';
import 'auth_tables.dart';
import 'commerce_tables.dart';

class TenantModules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get moduleCode => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
}

class CalculatorProductData extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get calculatorType => text()();
  TextColumn get metadata => text()(); // JSON string representation
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable().unique()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()(); // 'pending' | 'synced' | 'conflict'
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

class CalculatorHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get calculatorType => text()();
  TextColumn get inputData => text()(); // JSON string representation
  TextColumn get resultData => text()(); // JSON string representation
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get label => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable().unique()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()(); // 'pending' | 'synced' | 'conflict'
}
