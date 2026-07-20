import 'package:drift/drift.dart';

import 'auth_tables.dart';
import 'commerce_tables.dart';
import 'purchase_tables.dart';

/// Lot de stock (coût d'achat figé, consommé en FIFO à la vente).
class InventoryLots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get sourceType => text()();
  IntColumn get sourceId => integer().nullable()();
  IntColumn get purchaseReceiptItemId =>
      integer().nullable().references(PurchaseReceiptItems, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get unitCost => integer()();
  IntColumn get quantityReceived => integer()();
  IntColumn get quantityRemaining => integer()();
  IntColumn get quantityReserved =>
      integer().withDefault(const Constant(0))();
  TextColumn get batchNumber => text().nullable()();
  IntColumn get expiryDate => integer().nullable()();
  IntColumn get receivedAt => integer()();
  TextColumn get status =>
      text().withDefault(const Constant('active'))();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

/// Ventilation FIFO d'une ligne de vente sur un ou plusieurs lots.
class SaleItemLotAllocations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get saleItemId => integer().references(SaleItems, #id)();
  IntColumn get inventoryLotId => integer().references(InventoryLots, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitCost => integer()();
  IntColumn get createdAt => integer()();
}
