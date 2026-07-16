import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/inventory_lot_entities.dart' as lot_entity;

/// Gestion locale des lots de stock et allocations FIFO.
class InventoryLotLocalDatasource {
  InventoryLotLocalDatasource(this._db);

  final AppDatabase _db;

  /// Crée un lot entrant (réception, ajustement +, migration initiale).
  Future<int> createLot({
    required int shopId,
    required int productId,
    required String sourceType,
    int? sourceId,
    int? purchaseReceiptItemId,
    int? supplierId,
    required int unitCost,
    required int quantity,
    String? batchNumber,
    int? expiryDate,
    int? receivedAt,
  }) async {
    if (quantity <= 0) {
      throw const ValidationFailure('La quantité du lot doit être positive.');
    }

    final timestamp = nowMs();
    final lotId = await _db.into(_db.inventoryLots).insert(
          InventoryLotsCompanion.insert(
            shopId: shopId,
            productId: productId,
            sourceType: sourceType,
            sourceId: Value(sourceId),
            purchaseReceiptItemId: Value(purchaseReceiptItemId),
            supplierId: Value(supplierId),
            unitCost: unitCost,
            quantityReceived: quantity,
            quantityRemaining: quantity,
            batchNumber: Value(batchNumber),
            expiryDate: Value(expiryDate),
            receivedAt: receivedAt ?? timestamp,
            status: const Value(lot_entity.InventoryLotStatus.active),
            createdAt: timestamp,
          ),
        );

    await refreshProductStockFromLots(shopId: shopId, productId: productId);
    return lotId;
  }

  /// Consomme [quantity] unités en FIFO ; retourne les tranches allouées.
  Future<List<lot_entity.LotAllocationSlice>> allocateFifo({
    required int shopId,
    required int productId,
    required int quantity,
  }) async {
    if (quantity <= 0) return const [];

    await _ensureLotsForAllocation(shopId: shopId, productId: productId);

    final lots = await (_db.select(_db.inventoryLots)
          ..where(
            (l) =>
                l.shopId.equals(shopId) &
                l.productId.equals(productId) &
                l.quantityRemaining.isBiggerThanValue(0),
          )
          ..orderBy([
            (l) => OrderingTerm.asc(l.receivedAt),
            (l) => OrderingTerm.asc(l.id),
          ]))
        .get();

    var remaining = quantity;
    final slices = <lot_entity.LotAllocationSlice>[];

    for (final lot in lots) {
      if (remaining <= 0) break;
      final take = lot.quantityRemaining < remaining
          ? lot.quantityRemaining
          : remaining;
      if (take <= 0) continue;

      final newRemaining = lot.quantityRemaining - take;
      await (_db.update(_db.inventoryLots)..where((l) => l.id.equals(lot.id)))
          .write(
        InventoryLotsCompanion(
          quantityRemaining: Value(newRemaining),
          status: Value(
            newRemaining <= 0
                ? lot_entity.InventoryLotStatus.depleted
                : lot_entity.InventoryLotStatus.active,
          ),
          version: Value(lot.version + 1),
        ),
      );

      slices.add(
        lot_entity.LotAllocationSlice(
          lotId: lot.id,
          quantity: take,
          unitCost: lot.unitCost,
        ),
      );
      remaining -= take;
    }

    if (remaining > 0) {
      throw ValidationFailure(
        'Stock lot insuffisant pour le produit #$productId '
        '(manque $remaining unité(s)).',
      );
    }

    await refreshProductStockFromLots(shopId: shopId, productId: productId);
    return slices;
  }

  /// Enregistre les allocations liées à une ligne de vente.
  Future<void> recordSaleItemAllocations({
    required int shopId,
    required int saleItemId,
    required List<lot_entity.LotAllocationSlice> slices,
  }) async {
    final timestamp = nowMs();
    for (final slice in slices) {
      await _db.into(_db.saleItemLotAllocations).insert(
            SaleItemLotAllocationsCompanion.insert(
              shopId: shopId,
              saleItemId: saleItemId,
              inventoryLotId: slice.lotId,
              quantity: slice.quantity,
              unitCost: slice.unitCost,
              createdAt: timestamp,
            ),
          );
    }
  }

  /// Coût unitaire moyen pondéré d'une liste de tranches FIFO.
  static int weightedUnitCost(List<lot_entity.LotAllocationSlice> slices) {
    if (slices.isEmpty) return 0;
    var totalCost = 0;
    var totalQty = 0;
    for (final s in slices) {
      totalCost += s.quantity * s.unitCost;
      totalQty += s.quantity;
    }
    if (totalQty <= 0) return 0;
    return (totalCost / totalQty).round();
  }

  /// Restaure le stock des lots après annulation d'une vente.
  Future<void> restoreLotsForSale({
    required int shopId,
    required int saleId,
  }) async {
    final items = await (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(saleId) & i.shopId.equals(shopId)))
        .get();

    final productIds = <int>{};

    for (final item in items) {
      final allocations = await (_db.select(_db.saleItemLotAllocations)
            ..where((a) => a.saleItemId.equals(item.id)))
          .get();

      for (final alloc in allocations) {
        final lot = await (_db.select(_db.inventoryLots)
              ..where((l) => l.id.equals(alloc.inventoryLotId)))
            .getSingleOrNull();
        if (lot == null) continue;

        final newRemaining = lot.quantityRemaining + alloc.quantity;
        await (_db.update(_db.inventoryLots)
              ..where((l) => l.id.equals(lot.id)))
            .write(
          InventoryLotsCompanion(
            quantityRemaining: Value(newRemaining),
            status: const Value(lot_entity.InventoryLotStatus.active),
            version: Value(lot.version + 1),
          ),
        );
        productIds.add(lot.productId);
      }

      await (_db.delete(_db.saleItemLotAllocations)
            ..where((a) => a.saleItemId.equals(item.id)))
          .go();
    }

    for (final productId in productIds) {
      await refreshProductStockFromLots(shopId: shopId, productId: productId);
    }
  }

  /// Recalcule `quantityInStock` à partir des lots actifs.
  Future<void> refreshProductStockFromLots({
    required int shopId,
    required int productId,
  }) async {
    final lots = await (_db.select(_db.inventoryLots)
          ..where(
            (l) => l.shopId.equals(shopId) & l.productId.equals(productId),
          ))
        .get();

    final total = lots.fold<int>(0, (sum, l) => sum + l.quantityRemaining);
    final timestamp = nowMs();

    await (_db.update(_db.products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        quantityInStock: Value(total),
        updatedAt: Value(timestamp),
      ),
    );
  }

  /// Met à jour `priceBuy` avec le coût du dernier lot reçu (indicateur UI).
  Future<void> updateLastPurchasePrice({
    required int productId,
    required int unitCost,
  }) async {
    await (_db.update(_db.products)..where((p) => p.id.equals(productId)))
        .write(
      ProductsCompanion(
        priceBuy: Value(unitCost),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  /// Coût unitaire du lot le plus récemment reçu (référence pour l'appro).
  Future<int?> getLatestUnitCost({
    required int shopId,
    required int productId,
  }) async {
    final lot = await (_db.select(_db.inventoryLots)
          ..where(
            (l) => l.shopId.equals(shopId) & l.productId.equals(productId),
          )
          ..orderBy([
            (l) => OrderingTerm.desc(l.receivedAt),
            (l) => OrderingTerm.desc(l.id),
          ])
          ..limit(1))
        .getSingleOrNull();
    return lot?.unitCost;
  }

  /// Coût de référence : dernier lot ou `priceBuy` produit en repli.
  Future<int> getReferenceUnitCost({
    required int shopId,
    required int productId,
  }) async {
    final latest = await getLatestUnitCost(
      shopId: shopId,
      productId: productId,
    );
    if (latest != null) return latest;

    final product = await (_db.select(_db.products)
          ..where(
            (p) => p.shopId.equals(shopId) & p.id.equals(productId),
          ))
        .getSingleOrNull();
    return product?.priceBuy ?? 0;
  }

  /// Migration : un lot initial par produit ayant du stock.
  Future<void> backfillInitialLotsForShop(int shopId) async {
    final products = await (_db.select(_db.products)
          ..where(
            (p) => p.shopId.equals(shopId) & p.quantityInStock.isBiggerThanValue(0),
          ))
        .get();

    final timestamp = nowMs();

    for (final product in products) {
      final existing = await (_db.select(_db.inventoryLots)
            ..where(
              (l) =>
                  l.shopId.equals(shopId) &
                  l.productId.equals(product.id) &
                  l.sourceType.equals(lot_entity.InventoryLotSourceType.initialMigration),
            )
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) continue;

      await _db.into(_db.inventoryLots).insert(
            InventoryLotsCompanion.insert(
              shopId: shopId,
              productId: product.id,
              sourceType: lot_entity.InventoryLotSourceType.initialMigration,
              unitCost: product.priceBuy ?? 0,
              quantityReceived: product.quantityInStock,
              quantityRemaining: product.quantityInStock,
              receivedAt: timestamp,
              status: const Value(lot_entity.InventoryLotStatus.active),
              createdAt: timestamp,
            ),
          );
    }
  }

  /// Crée un lot initial si le produit a du stock mais aucun lot actif.
  Future<void> _ensureLotsForAllocation({
    required int shopId,
    required int productId,
  }) async {
    final activeLots = await (_db.select(_db.inventoryLots)
          ..where(
            (l) =>
                l.shopId.equals(shopId) &
                l.productId.equals(productId) &
                l.quantityRemaining.isBiggerThanValue(0),
          )
          ..limit(1))
        .get();
    if (activeLots.isNotEmpty) return;

    final product = await (_db.select(_db.products)
          ..where((p) => p.shopId.equals(shopId) & p.id.equals(productId)))
        .getSingleOrNull();
    if (product == null || product.quantityInStock <= 0) return;

    final timestamp = nowMs();
    await _db.into(_db.inventoryLots).insert(
          InventoryLotsCompanion.insert(
            shopId: shopId,
            productId: productId,
            sourceType: lot_entity.InventoryLotSourceType.initialMigration,
            unitCost: product.priceBuy ?? 0,
            quantityReceived: product.quantityInStock,
            quantityRemaining: product.quantityInStock,
            receivedAt: timestamp,
            status: const Value(lot_entity.InventoryLotStatus.active),
            createdAt: timestamp,
          ),
        );
  }

  /// Lots actifs d'un produit (ordre FIFO).
  Future<List<lot_entity.InventoryLot>> listActiveLotsForProduct({
    required int shopId,
    required int productId,
  }) async {
    final rows = await (_db.select(_db.inventoryLots)
          ..where(
            (l) =>
                l.shopId.equals(shopId) &
                l.productId.equals(productId) &
                l.quantityRemaining.isBiggerThanValue(0),
          )
          ..orderBy([
            (l) => OrderingTerm.asc(l.receivedAt),
            (l) => OrderingTerm.asc(l.id),
          ]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<bool> hasLotForReceiptItem(int purchaseReceiptItemId) async {
    final row = await (_db.select(_db.inventoryLots)
          ..where((l) => l.purchaseReceiptItemId.equals(purchaseReceiptItemId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Idempotent : lot pour une ligne de bon de réception (pull sync).
  Future<void> ensureLotForReceiptItem({
    required int shopId,
    required int productId,
    required int purchaseReceiptItemId,
    int? receiptId,
    int? supplierId,
    required int unitCost,
    required int quantity,
    String? batchNumber,
    int? expiryDate,
    required int receivedAt,
  }) async {
    if (quantity <= 0) return;
    if (await hasLotForReceiptItem(purchaseReceiptItemId)) return;

    await createLot(
      shopId: shopId,
      productId: productId,
      sourceType: lot_entity.InventoryLotSourceType.procurementReceipt,
      sourceId: receiptId,
      purchaseReceiptItemId: purchaseReceiptItemId,
      supplierId: supplierId,
      unitCost: unitCost,
      quantity: quantity,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      receivedAt: receivedAt,
    );
  }

  Future<void> upsertLotFromRemote({
    required int shopId,
    required int productId,
    required String serverId,
    required String sourceType,
    int? sourceId,
    int? purchaseReceiptItemId,
    int? supplierId,
    required int unitCost,
    required int quantityReceived,
    required int quantityRemaining,
    String? batchNumber,
    int? expiryDate,
    required int receivedAt,
    required String status,
    required int createdAt,
    required int version,
  }) async {
    final existing = await (_db.select(_db.inventoryLots)
          ..where((l) => l.shopId.equals(shopId) & l.serverId.equals(serverId)))
        .getSingleOrNull();

    final companion = InventoryLotsCompanion(
      shopId: Value(shopId),
      productId: Value(productId),
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      purchaseReceiptItemId: Value(purchaseReceiptItemId),
      supplierId: Value(supplierId),
      unitCost: Value(unitCost),
      quantityReceived: Value(quantityReceived),
      quantityRemaining: Value(quantityRemaining),
      batchNumber: Value(batchNumber),
      expiryDate: Value(expiryDate),
      receivedAt: Value(receivedAt),
      status: Value(status),
      createdAt: Value(createdAt),
      version: Value(version),
      serverId: Value(serverId),
      syncStatus: const Value('synced'),
    );

    if (existing == null) {
      await _db.into(_db.inventoryLots).insert(companion);
    } else {
      await (_db.update(_db.inventoryLots)..where((l) => l.id.equals(existing.id)))
          .write(companion);
    }

    await refreshProductStockFromLots(shopId: shopId, productId: productId);
  }

  lot_entity.InventoryLot _toEntity(InventoryLot row) {
    return lot_entity.InventoryLot(
      id: row.id,
      shopId: row.shopId,
      productId: row.productId,
      sourceType: row.sourceType,
      sourceId: row.sourceId,
      purchaseReceiptItemId: row.purchaseReceiptItemId,
      supplierId: row.supplierId,
      unitCost: row.unitCost,
      quantityReceived: row.quantityReceived,
      quantityRemaining: row.quantityRemaining,
      batchNumber: row.batchNumber,
      expiryDate: row.expiryDate,
      receivedAt: row.receivedAt,
      status: row.status,
      createdAt: row.createdAt,
      version: row.version,
    );
  }
}
