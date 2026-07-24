import 'package:drift/drift.dart';

import 'auth_tables.dart';
import 'commerce_tables.dart';

class SalesOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get number => text()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  IntColumn get orderedAt => integer()();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get updatedBy => integer().nullable().references(Users, #id)();
  TextColumn get deviceId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SalesOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get salesOrderId => integer().references(SalesOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantityOrdered => integer()();
  IntColumn get quantityDelivered => integer().withDefault(const Constant(0))();
  IntColumn get quantityRefused => integer().withDefault(const Constant(0))();
  IntColumn get quantityReplaced => integer().withDefault(const Constant(0))();
  IntColumn get unitPrice => integer()();
  IntColumn get lineTotal => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SalesOrderDeliveries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get salesOrderId => integer().references(SalesOrders, #id)();
  TextColumn get number => text()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  IntColumn get deliveredAt => integer()();
  IntColumn get deliveredBy => integer().references(Users, #id)();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  TextColumn get notes => text().nullable()();
  TextColumn get driverName => text().nullable()();
  TextColumn get vehiclePlate => text().nullable()();
  TextColumn get remainingReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SalesOrderDeliveryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get deliveryId =>
      integer().references(SalesOrderDeliveries, #id)();
  IntColumn get salesOrderItemId =>
      integer().references(SalesOrderItems, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantitySent => integer()();
  IntColumn get quantityAccepted => integer()();
  IntColumn get quantityRefused => integer().withDefault(const Constant(0))();
  TextColumn get refusalReason => text().nullable()();
  TextColumn get refusalDestination => text().nullable()();
  IntColumn get quantityReplaced => integer().withDefault(const Constant(0))();
  IntColumn get replacementProductId =>
      integer().nullable().references(Products, #id)();
  IntColumn get replacementUnitPrice => integer().nullable()();
  IntColumn get unitPrice => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SalesOrderHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get salesOrderId => integer().references(SalesOrders, #id)();
  TextColumn get action => text()();
  IntColumn get performedBy => integer().references(Users, #id)();
  IntColumn get performedAt => integer()();
  TextColumn get details => text().nullable()();
  TextColumn get payload => text().nullable()();
}
