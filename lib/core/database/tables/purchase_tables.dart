import 'package:drift/drift.dart';
import 'auth_tables.dart';
import 'commerce_tables.dart';

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class PurchaseOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get number => text()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  IntColumn get orderedAt => integer()();
  IntColumn get expectedAt => integer().nullable()();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class PurchaseOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get purchaseOrderId => integer().references(PurchaseOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantityOrdered => integer()();
  IntColumn get quantityReceived => integer().withDefault(const Constant(0))();
  IntColumn get unitCost => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get subtotal => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class PurchaseReceipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get purchaseOrderId =>
      integer().nullable().references(PurchaseOrders, #id)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get receiptType =>
      text().withDefault(const Constant('from_order'))();
  TextColumn get receiptNumber => text()();
  IntColumn get receivedAt => integer()();
  IntColumn get receivedBy => integer().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class PurchaseReceiptItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get purchaseReceiptId => integer().references(PurchaseReceipts, #id)();
  IntColumn get purchaseOrderItemId =>
      integer().nullable().references(PurchaseOrderItems, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantityReceived => integer()();
  IntColumn get unitCost => integer()();
  TextColumn get batchNumber => text().nullable()();
  IntColumn get expiryDate => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SupplierInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get purchaseOrderId => integer().nullable().references(PurchaseOrders, #id)();
  TextColumn get invoiceNumber => text()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  IntColumn get invoiceDate => integer()();
  IntColumn get dueDate => integer().nullable()();
  IntColumn get subtotal => integer()();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class SupplierPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get invoiceId => integer().references(SupplierInvoices, #id)();
  IntColumn get amount => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  IntColumn get paymentDate => integer()();
  TextColumn get reference => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class PurchaseOrderHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get purchaseOrderId => integer().references(PurchaseOrders, #id)();
  TextColumn get action => text()();
  IntColumn get performedBy => integer().references(Users, #id)();
  IntColumn get performedAt => integer()();
  TextColumn get details => text().nullable()();
}
