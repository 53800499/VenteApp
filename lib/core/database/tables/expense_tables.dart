import 'package:drift/drift.dart';

import 'auth_tables.dart';

class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(ExpenseCategories, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get amount => integer()();
  IntColumn get expenseDate => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  IntColumn get createdBy => integer().references(Users, #id)();
  TextColumn get supplier => text().nullable()();
  TextColumn get invoiceNumber => text().nullable()();
  TextColumn get repeatSchedule =>
      text().withDefault(const Constant('none'))();
  TextColumn get status => text().withDefault(const Constant('validated'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class ExpenseAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get expenseId => integer().references(Expenses, #id)();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get localPath => text()();
  IntColumn get createdAt => integer()();
}

class ExpenseHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get expenseId => integer().references(Expenses, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get fieldName => text()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  IntColumn get createdAt => integer()();
}

class CategoryBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get categoryId =>
      integer().references(ExpenseCategories, #id)();
  IntColumn get monthlyAmount => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}
