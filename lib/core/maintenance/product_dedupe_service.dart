import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Résultat d'une opération de fusion de produits en doublon.
class ProductDedupeResult {
  const ProductDedupeResult({
    required this.groupsProcessed,
    required this.productsRemoved,
    required this.referencesUpdated,
    required this.stockMerged,
    required this.details,
  });

  final int groupsProcessed;
  final int productsRemoved;
  final int referencesUpdated;
  final int stockMerged;
  final List<String> details;

  bool get hasChanges => productsRemoved > 0;

  @override
  String toString() {
    if (!hasChanges) {
      return 'Aucun doublon trouvé.';
    }
    return '$groupsProcessed groupe(s) fusionné(s), '
        '$productsRemoved produit(s) supprimé(s), '
        '$referencesUpdated référence(s) réassignée(s), '
        '$stockMerged unité(s) de stock consolidée(s).';
  }
}

/// Fusionne les produits portant le même nom (insensible à la casse) au sein d'une boutique.
class ProductDedupeService {
  ProductDedupeService(this._db);

  final AppDatabase _db;

  Future<ProductDedupeResult> dedupeByNameInShop(
    int shopId, {
    bool dryRun = false,
  }) async {
    final products = await (_db.select(_db.products)
          ..where((p) => p.shopId.equals(shopId))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();

    final groups = <String, List<Product>>{};
    for (final product in products) {
      final key = _normalizeName(product.name);
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => []).add(product);
    }

    var groupsProcessed = 0;
    var productsRemoved = 0;
    var referencesUpdated = 0;
    var stockMerged = 0;
    final details = <String>[];

    for (final entry in groups.entries) {
      final rows = entry.value;
      if (rows.length < 2) continue;

      final keeper = _pickKeeper(rows);
      final duplicates =
          rows.where((product) => product.id != keeper.id).toList(growable: false);
      if (duplicates.isEmpty) continue;

      groupsProcessed++;
      var groupStockMerged = 0;
      var groupReferencesUpdated = 0;

      for (final duplicate in duplicates) {
        if (dryRun) {
          groupReferencesUpdated += await _countReferences(duplicate.id);
          groupStockMerged += duplicate.quantityInStock;
          productsRemoved++;
          continue;
        }

        await _db.transaction(() async {
          groupReferencesUpdated += await _reassignReferences(
            keepId: keeper.id,
            dupId: duplicate.id,
          );
          groupStockMerged += duplicate.quantityInStock;

          await (_db.delete(_db.products)..where((p) => p.id.equals(duplicate.id)))
              .go();
        });
        productsRemoved++;
      }

      if (!dryRun && groupStockMerged > 0) {
        final latestKeeper = await (_db.select(_db.products)
              ..where((p) => p.id.equals(keeper.id)))
            .getSingle();
        await (_db.update(_db.products)..where((p) => p.id.equals(keeper.id))).write(
          ProductsCompanion(
            quantityInStock: Value(latestKeeper.quantityInStock + groupStockMerged),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }

      referencesUpdated += groupReferencesUpdated;
      stockMerged += groupStockMerged;
      details.add(
        '« ${keeper.name} » : conservé #${keeper.id}, '
        'supprimé ${duplicates.map((p) => '#${p.id}').join(', ')}'
        '${groupStockMerged > 0 ? ' (+$groupStockMerged stock)' : ''}.',
      );
    }

    return ProductDedupeResult(
      groupsProcessed: groupsProcessed,
      productsRemoved: productsRemoved,
      referencesUpdated: referencesUpdated,
      stockMerged: stockMerged,
      details: details,
    );
  }

  Future<ProductDedupeResult> dedupeByNameAllShops({bool dryRun = false}) async {
    final shops = await _db.select(_db.shops).get();
    var groupsProcessed = 0;
    var productsRemoved = 0;
    var referencesUpdated = 0;
    var stockMerged = 0;
    final details = <String>[];

    for (final shop in shops) {
      final result = await dedupeByNameInShop(shop.id, dryRun: dryRun);
      groupsProcessed += result.groupsProcessed;
      productsRemoved += result.productsRemoved;
      referencesUpdated += result.referencesUpdated;
      stockMerged += result.stockMerged;
      if (result.details.isNotEmpty) {
        details.add('Boutique « ${shop.name} » (${shop.id})');
        details.addAll(result.details);
      }
    }

    return ProductDedupeResult(
      groupsProcessed: groupsProcessed,
      productsRemoved: productsRemoved,
      referencesUpdated: referencesUpdated,
      stockMerged: stockMerged,
      details: details,
    );
  }

  String _normalizeName(String name) => name.trim().toLowerCase();

  Product _pickKeeper(List<Product> rows) {
    final sorted = List<Product>.from(rows)
      ..sort((a, b) {
        final aHasServerId =
            a.serverId != null && a.serverId!.trim().isNotEmpty;
        final bHasServerId =
            b.serverId != null && b.serverId!.trim().isNotEmpty;
        if (aHasServerId != bHasServerId) {
          return aHasServerId ? -1 : 1;
        }
        if (a.isArchived != b.isArchived) {
          return a.isArchived ? 1 : -1;
        }
        if (a.quantityInStock != b.quantityInStock) {
          return b.quantityInStock.compareTo(a.quantityInStock);
        }
        return a.id.compareTo(b.id);
      });
    return sorted.first;
  }

  Future<int> _countReferences(int dupId) async {
    var count = 0;
    count += await _count((_db.select(_db.saleItems)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.stockMovements)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.customerProductPrices)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.inventoryLots)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.purchaseOrderItems)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.purchaseReceiptItems)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.productPriceHistory)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.calculatorProductData)
          ..where((row) => row.productId.equals(dupId)))
        .get());
    count += await _count((_db.select(_db.stockTransferItems)
          ..where(
            (row) =>
                row.sourceProductId.equals(dupId) |
                row.destinationProductId.equals(dupId),
          ))
        .get());
    return count;
  }

  Future<int> _count<T>(Future<List<T>> query) async => (await query).length;

  Future<int> _reassignReferences({
    required int keepId,
    required int dupId,
  }) async {
    var updated = 0;

    updated += await _mergeSaleItems(keepId: keepId, dupId: dupId);
    updated += await _reassignSimple(
      table: _db.stockMovements,
      dupId: dupId,
      keepId: keepId,
      column: (row) => row.productId,
      companion: (keep) => StockMovementsCompanion(productId: Value(keep)),
    );
    updated += await _mergeCustomerProductPrices(keepId: keepId, dupId: dupId);
    updated += await _reassignSimple(
      table: _db.inventoryLots,
      dupId: dupId,
      keepId: keepId,
      column: (row) => row.productId,
      companion: (keep) => InventoryLotsCompanion(productId: Value(keep)),
    );
    updated += await _reassignSimple(
      table: _db.purchaseOrderItems,
      dupId: dupId,
      keepId: keepId,
      column: (row) => row.productId,
      companion: (keep) => PurchaseOrderItemsCompanion(productId: Value(keep)),
    );
    updated += await _reassignSimple(
      table: _db.purchaseReceiptItems,
      dupId: dupId,
      keepId: keepId,
      column: (row) => row.productId,
      companion: (keep) =>
          PurchaseReceiptItemsCompanion(productId: Value(keep)),
    );
    updated += await _reassignSimple(
      table: _db.productPriceHistory,
      dupId: dupId,
      keepId: keepId,
      column: (row) => row.productId,
      companion: (keep) => ProductPriceHistoryCompanion(productId: Value(keep)),
    );
    updated += await _mergeCalculatorProductData(keepId: keepId, dupId: dupId);
    updated += await _reassignStockTransferItems(keepId: keepId, dupId: dupId);

    return updated;
  }

  Future<int> _reassignSimple<T extends Table, D>({
    required TableInfo<T, D> table,
    required int dupId,
    required int keepId,
    required GeneratedColumn<int> Function(T row) column,
    required UpdateCompanion<D> Function(int keepId) companion,
  }) async {
    final count = await (_db.update(table)..where((row) => column(row).equals(dupId)))
        .write(companion(keepId));
    return count;
  }

  Future<int> _mergeSaleItems({
    required int keepId,
    required int dupId,
  }) async {
    final dupItems = await (_db.select(_db.saleItems)
          ..where((row) => row.productId.equals(dupId)))
        .get();
    var updated = 0;

    for (final item in dupItems) {
      final keeperItem = await (_db.select(_db.saleItems)
            ..where(
              (row) =>
                  row.saleId.equals(item.saleId) & row.productId.equals(keepId),
            ))
          .getSingleOrNull();

      if (keeperItem != null) {
        await (_db.update(_db.saleItems)
              ..where((row) => row.id.equals(keeperItem.id)))
            .write(
          SaleItemsCompanion(
            quantity: Value(keeperItem.quantity + item.quantity),
            lineTotal: Value(keeperItem.lineTotal + item.lineTotal),
          ),
        );
        await (_db.update(_db.saleItemLotAllocations)
              ..where((row) => row.saleItemId.equals(item.id)))
            .write(
          SaleItemLotAllocationsCompanion(
            saleItemId: Value(keeperItem.id),
          ),
        );
        await (_db.delete(_db.saleItems)..where((row) => row.id.equals(item.id)))
            .go();
      } else {
        await (_db.update(_db.saleItems)..where((row) => row.id.equals(item.id)))
            .write(SaleItemsCompanion(productId: Value(keepId)));
      }
      updated++;
    }

    return updated;
  }

  Future<int> _mergeCustomerProductPrices({
    required int keepId,
    required int dupId,
  }) async {
    final dupRows = await (_db.select(_db.customerProductPrices)
          ..where((row) => row.productId.equals(dupId)))
        .get();
    var updated = 0;

    for (final row in dupRows) {
      final keeperRow = await (_db.select(_db.customerProductPrices)
            ..where(
              (entry) =>
                  entry.customerId.equals(row.customerId) &
                  entry.productId.equals(keepId),
            ))
          .getSingleOrNull();

      if (keeperRow != null) {
        if (row.updatedAt >= keeperRow.updatedAt) {
          await (_db.update(_db.customerProductPrices)
                ..where((entry) => entry.id.equals(keeperRow.id)))
              .write(
            CustomerProductPricesCompanion(
              lastUnitPrice: Value(row.lastUnitPrice),
              updatedAt: Value(row.updatedAt),
            ),
          );
        }
        await (_db.delete(_db.customerProductPrices)
              ..where((entry) => entry.id.equals(row.id)))
            .go();
      } else {
        await (_db.update(_db.customerProductPrices)
              ..where((entry) => entry.id.equals(row.id)))
            .write(CustomerProductPricesCompanion(productId: Value(keepId)));
      }
      updated++;
    }

    return updated;
  }

  Future<int> _mergeCalculatorProductData({
    required int keepId,
    required int dupId,
  }) async {
    final dupRows = await (_db.select(_db.calculatorProductData)
          ..where((row) => row.productId.equals(dupId)))
        .get();
    var updated = 0;

    for (final row in dupRows) {
      final keeperExists = await (_db.select(_db.calculatorProductData)
            ..where(
              (entry) =>
                  entry.shopId.equals(row.shopId) &
                  entry.productId.equals(keepId) &
                  entry.calculatorType.equals(row.calculatorType),
            ))
          .getSingleOrNull();

      if (keeperExists != null) {
        await (_db.delete(_db.calculatorProductData)
              ..where((entry) => entry.id.equals(row.id)))
            .go();
      } else {
        await (_db.update(_db.calculatorProductData)
              ..where((entry) => entry.id.equals(row.id)))
            .write(CalculatorProductDataCompanion(productId: Value(keepId)));
      }
      updated++;
    }

    return updated;
  }

  Future<int> _reassignStockTransferItems({
    required int keepId,
    required int dupId,
  }) async {
    final sourceUpdated = await (_db.update(_db.stockTransferItems)
          ..where((row) => row.sourceProductId.equals(dupId)))
        .write(StockTransferItemsCompanion(sourceProductId: Value(keepId)));

    final destinationUpdated = await (_db.update(_db.stockTransferItems)
          ..where((row) => row.destinationProductId.equals(dupId)))
        .write(
      StockTransferItemsCompanion(destinationProductId: Value(keepId)),
    );

    return sourceUpdated + destinationUpdated;
  }
}
