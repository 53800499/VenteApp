import 'package:drift/drift.dart';

import 'auth_tables.dart';
import 'commerce_tables.dart';
import 'inventory_lot_tables.dart';

/// Transfert de stock inter-boutiques (document métier).
class StockTransfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reference => text()();
  IntColumn get sourceShopId => integer().references(Shops, #id)();
  IntColumn get destinationShopId => integer().references(Shops, #id)();
  TextColumn get sourceShopName => text().nullable()();
  TextColumn get destinationShopName => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get transferType =>
      text().withDefault(const Constant('outbound'))();
  IntColumn get parentTransferId =>
      integer().nullable().references(StockTransfers, #id)();
  TextColumn get notes => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id)();
  IntColumn get validatedBy => integer().nullable().references(Users, #id)();
  IntColumn get shippedBy => integer().nullable().references(Users, #id)();
  IntColumn get receivedBy => integer().nullable().references(Users, #id)();
  IntColumn get closedBy => integer().nullable().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get validatedAt => integer().nullable()();
  IntColumn get shippedAt => integer().nullable()();
  IntColumn get receivedAt => integer().nullable()();
  IntColumn get closedAt => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().nullable()();
}

class StockTransferItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferId => integer().references(StockTransfers, #id)();
  IntColumn get sourceProductId => integer().references(Products, #id)();
  IntColumn get destinationProductId =>
      integer().nullable().references(Products, #id)();
  TextColumn get productServerId => text().nullable()();
  IntColumn get quantityRequested => integer()();
  IntColumn get quantityShipped => integer().withDefault(const Constant(0))();
  IntColumn get quantityReceived => integer().withDefault(const Constant(0))();
}

/// Expédition (multi-expéditions phase 2).
class StockTransferShipments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferId => integer().references(StockTransfers, #id)();
  TextColumn get reference => text().withDefault(const Constant(''))();
  TextColumn get label => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get driverName => text().nullable()();
  TextColumn get vehiclePlate => text().nullable()();
  IntColumn get shippedBy => integer().references(Users, #id)();
  IntColumn get shippedAt => integer()();
}

/// Réservation FIFO à la validation (libérée à l'expédition ou l'annulation).
class StockTransferLotReservations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferItemId =>
      integer().references(StockTransferItems, #id)();
  IntColumn get lotId => integer().references(InventoryLots, #id)();
  IntColumn get quantity => integer()();
  IntColumn get quantityShipped => integer().withDefault(const Constant(0))();
  IntColumn get unitCost => integer()();
}

/// Tranches FIFO expédiées (prix d'achat préservé lot par lot).
class StockTransferLotLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferItemId =>
      integer().references(StockTransferItems, #id)();
  IntColumn get shipmentId =>
      integer().nullable().references(StockTransferShipments, #id)();
  IntColumn get sourceLotId =>
      integer().nullable().references(InventoryLots, #id)();
  IntColumn get destinationLotId =>
      integer().nullable().references(InventoryLots, #id)();
  IntColumn get quantity => integer()();
  IntColumn get quantityReceived => integer().withDefault(const Constant(0))();
  IntColumn get unitCost => integer()();
}

class StockTransferEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferId => integer().references(StockTransfers, #id)();
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get eventType => text()();
  IntColumn get actorUserId => integer().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  TextColumn get payloadJson => text().nullable()();
  IntColumn get createdAt => integer()();
}

class StockTransferDiscrepancies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferId => integer().references(StockTransfers, #id)();
  IntColumn get transferItemId =>
      integer().references(StockTransferItems, #id)();
  IntColumn get quantity => integer()();
  TextColumn get reason => text()();
  TextColumn get resolution => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get resolvedBy => integer().references(Users, #id)();
  IntColumn get resolvedAt => integer()();
  IntColumn get createdAt => integer()();
}

class StockTransferReceipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferId => integer().references(StockTransfers, #id)();
  IntColumn get shipmentId =>
      integer().nullable().references(StockTransferShipments, #id)();
  TextColumn get reference => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get receivedBy => integer().references(Users, #id)();
  IntColumn get receivedAt => integer()();
  IntColumn get createdAt => integer()();
}

class StockTransferReceiptItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get receiptId =>
      integer().references(StockTransferReceipts, #id)();
  IntColumn get transferItemId =>
      integer().references(StockTransferItems, #id)();
  IntColumn get quantityReceived => integer()();
  IntColumn get quantityRefused =>
      integer().withDefault(const Constant(0))();
  TextColumn get refusalReason => text().nullable()();
  TextColumn get refusalResolution => text().nullable()();
  IntColumn get createdAt => integer()();
}
