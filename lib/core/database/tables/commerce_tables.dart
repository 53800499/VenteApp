import 'package:drift/drift.dart';

import 'auth_tables.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  IntColumn get quantityInStock => integer().withDefault(const Constant(0))();
  IntColumn get alertThreshold => integer().nullable()();
  IntColumn get priceBuy => integer().nullable()();
  IntColumn get priceSell => integer()();
  IntColumn get priceSemiWholesale => integer().nullable()();
  IntColumn get priceWholesale => integer().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isShared =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get receiptNumber => text().nullable()();
  TextColumn get saleType =>
      text().withDefault(const Constant('standard'))();
  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  IntColumn get amountCash => integer().withDefault(const Constant(0))();
  IntColumn get amountMomo => integer().withDefault(const Constant(0))();
  IntColumn get amountCredit => integer().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer().nullable()();
  IntColumn get cancelledAt => integer().nullable()();
  IntColumn get cancelledByUserId => integer().nullable().references(Users, #id)();
  TextColumn get cancelReason => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().nullable().references(Products, #id)();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  IntColumn get unitPrice => integer()();
  IntColumn get unitCost => integer().nullable()();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();
  IntColumn get lineTotal => integer()();
  IntColumn get createdAt => integer()();
}

class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  IntColumn get originalAmount => integer()();
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  IntColumn get amountRemaining => integer()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  IntColumn get createdAt => integer()();
  IntColumn get dueAt => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get type => text()();
  IntColumn get quantityChange => integer()();
  IntColumn get quantityBefore => integer()();
  IntColumn get quantityAfter => integer()();
  TextColumn get reason => text().nullable()();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  IntColumn get unitCost => integer().nullable()();
  IntColumn get createdAt => integer()();
}

/// Dernier prix unitaire pratiqué pour un couple client × produit.
class CustomerProductPrices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get lastUnitPrice => integer()();
  IntColumn get updatedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {customerId, productId},
      ];
}
