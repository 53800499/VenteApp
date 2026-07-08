import 'package:drift/drift.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/inventory_entities.dart'
    show ProductCategory, ProductListFilters, ProductSort;
import '../../mappers/product_mapper.dart';

class InventoryLocalDatasource {
  InventoryLocalDatasource(this._db);

  final AppDatabase _db;

  Future<int> getDefaultAlertThreshold(int shopId) async {
    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId)))
        .getSingleOrNull();
    return settings?.defaultAlertThreshold ?? AppConstants.defaultAlertThreshold;
  }

  Future<int> ensureDefaultCategory(int shopId) async {
    final existing = await (_db.select(_db.categories)
          ..where(
            (c) => c.shopId.equals(shopId) & c.name.equals('Général'),
          ))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final timestamp = nowMs();
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            shopId: shopId,
            name: 'Général',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<List<ProductCategory>> listCategories({
    required int shopId,
    bool activeOnly = true,
  }) async {
    final rows = await (_db.select(_db.categories)
          ..where((c) {
            var expr = c.shopId.equals(shopId);
            if (activeOnly) {
              expr = expr & c.isActive.equals(true);
            }
            return expr;
          })
          ..orderBy([
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.name),
          ]))
        .get();
    return rows.map(ProductMapper.categoryFromRow).toList();
  }

  Future<Category?> findCategory(int shopId, int categoryId) async {
    return (_db.select(_db.categories)
          ..where(
            (c) => c.id.equals(categoryId) & c.shopId.equals(shopId),
          ))
        .getSingleOrNull();
  }

  Future<bool> existsCategoryByName(
    int shopId,
    String name, {
    int? excludeId,
  }) async {
    final row = await (_db.select(_db.categories)
          ..where((c) {
            var expr =
                c.shopId.equals(shopId) & c.name.equals(name.trim());
            if (excludeId != null) {
              expr = expr & c.id.equals(excludeId).not();
            }
            return expr;
          }))
        .getSingleOrNull();
    return row != null;
  }

  Future<int> countProductsByCategory(int shopId, int categoryId) async {
    final rows = await (_db.select(_db.products)
          ..where(
            (p) =>
                p.shopId.equals(shopId) &
                p.categoryId.equals(categoryId) &
                p.isArchived.equals(false),
          ))
        .get();
    return rows.length;
  }

  Future<int> insertCategory({
    required int shopId,
    required String name,
    String? description,
    int sortOrder = 0,
  }) async {
    final timestamp = nowMs();
    final trimmedDescription = description?.trim();
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            shopId: shopId,
            name: name.trim(),
            description: trimmedDescription == null || trimmedDescription.isEmpty
                ? const Value.absent()
                : Value(trimmedDescription),
            sortOrder: Value(sortOrder),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> updateCategoryRow(
    int categoryId,
    CategoriesCompanion patch,
  ) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(categoryId)))
        .write(patch);
  }

  Future<void> deleteCategoryRow(int categoryId) async {
    await (_db.delete(_db.categories)..where((c) => c.id.equals(categoryId)))
        .go();
  }

  Future<Category?> findActiveCategory(int shopId, int categoryId) async {
    return (_db.select(_db.categories)
          ..where(
            (c) =>
                c.id.equals(categoryId) &
                c.shopId.equals(shopId) &
                c.isActive.equals(true),
          ))
        .getSingleOrNull();
  }

  Future<List<({Product product, String? categoryName})>> listProductRows({
    required int shopId,
    required ProductListFilters filters,
  }) async {
    var filter = _db.products.shopId.equals(shopId);

    if (!filters.includeArchived) {
      filter = filter & _db.products.isArchived.equals(false);
    }
    if (filters.categoryId != null) {
      filter = filter & _db.products.categoryId.equals(filters.categoryId!);
    }
    final search = filters.search?.trim();
    if (search != null && search.isNotEmpty) {
      final pattern = '%${search.toLowerCase()}%';
      filter = filter & _db.products.name.lower().like(pattern);
    }

    final query = _db.select(_db.products).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.products.categoryId),
      ),
    ])
      ..where(filter);

    switch (filters.sort) {
      case ProductSort.nameAsc:
        query.orderBy([OrderingTerm.asc(_db.products.name)]);
      case ProductSort.nameDesc:
        query.orderBy([OrderingTerm.desc(_db.products.name)]);
      case ProductSort.stockAsc:
        query.orderBy([OrderingTerm.asc(_db.products.quantityInStock)]);
      case ProductSort.stockDesc:
        query.orderBy([OrderingTerm.desc(_db.products.quantityInStock)]);
      case ProductSort.priceAsc:
        query.orderBy([OrderingTerm.asc(_db.products.priceSell)]);
      case ProductSort.priceDesc:
        query.orderBy([OrderingTerm.desc(_db.products.priceSell)]);
    }

    final rows = await query.get();
    return rows
        .map(
          (row) => (
            product: row.readTable(_db.products),
            categoryName: row.readTableOrNull(_db.categories)?.name,
          ),
        )
        .toList();
  }

  Future<Product?> findProduct(int shopId, int productId) async {
    return (_db.select(_db.products)
          ..where(
            (p) => p.id.equals(productId) & p.shopId.equals(shopId),
          ))
        .getSingleOrNull();
  }

  Future<String?> findCategoryName(int categoryId) async {
    final row = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(categoryId)))
        .getSingleOrNull();
    return row?.name;
  }

  Future<int> countSaleItems(int shopId, int productId) async {
    final rows = await (_db.select(_db.saleItems)
          ..where(
            (si) =>
                si.shopId.equals(shopId) & si.productId.equals(productId),
          ))
        .get();
    return rows.length;
  }

  Future<List<StockMovement>> listRecentMovements(
    int shopId,
    int productId, {
    int limit = 10,
  }) async {
    final rows = await (_db.select(_db.stockMovements)
          ..where(
            (m) =>
                m.shopId.equals(shopId) & m.productId.equals(productId),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(limit))
        .get();
    return rows;
  }

  Future<int> insertProduct({
    required int shopId,
    required int categoryId,
    required String name,
    String? sku,
    required int quantityInStock,
    required int alertThreshold,
    int? priceBuy,
    required int priceSell,
    int? priceSemiWholesale,
    int? priceWholesale,
  }) async {
    final timestamp = nowMs();
    return _db.into(_db.products).insert(
          ProductsCompanion.insert(
            shopId: shopId,
            categoryId: Value(categoryId),
            name: name,
            sku: Value(sku),
            quantityInStock: Value(quantityInStock),
            alertThreshold: Value(alertThreshold),
            priceBuy: Value(priceBuy),
            priceSell: priceSell,
            priceSemiWholesale: Value(priceSemiWholesale),
            priceWholesale: Value(priceWholesale),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> insertStockMovement({
    required int shopId,
    required int productId,
    required int userId,
    required String type,
    required int quantityChange,
    required int quantityBefore,
    required int quantityAfter,
    String? reason,
    int? unitCost,
  }) async {
    final timestamp = nowMs();
    await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            shopId: shopId,
            productId: productId,
            userId: userId,
            type: type,
            quantityChange: quantityChange,
            quantityBefore: quantityBefore,
            quantityAfter: quantityAfter,
            reason: Value(reason),
            unitCost: Value(unitCost),
            createdAt: timestamp,
          ),
        );
  }

  Future<void> updateProductRow(int productId, ProductsCompanion patch) async {
    await (_db.update(_db.products)..where((p) => p.id.equals(productId)))
        .write(patch);
  }

  Future<Category?> findCategoryByName(int shopId, String name) async {
    return (_db.select(_db.categories)
          ..where(
            (c) => c.shopId.equals(shopId) & c.name.equals(name.trim()),
          ))
        .getSingleOrNull();
  }

  Future<int> upsertCategoryFromRemote({
    required int shopId,
    required String name,
    String? description,
    required bool isActive,
    required int sortOrder,
    int? createdAt,
    int? updatedAt,
  }) async {
    final timestamp = nowMs();
    final trimmedDescription = description?.trim();
    final existing = await findCategoryByName(shopId, name);
    if (existing != null) {
      await updateCategoryRow(
        existing.id,
        CategoriesCompanion(
          description: trimmedDescription == null || trimmedDescription.isEmpty
              ? const Value(null)
              : Value(trimmedDescription),
          isActive: Value(isActive),
          sortOrder: Value(sortOrder),
          updatedAt: Value(updatedAt ?? timestamp),
        ),
      );
      return existing.id;
    }

    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            shopId: shopId,
            name: name.trim(),
            description: trimmedDescription == null || trimmedDescription.isEmpty
                ? const Value.absent()
                : Value(trimmedDescription),
            isActive: Value(isActive),
            sortOrder: Value(sortOrder),
            createdAt: createdAt ?? timestamp,
            updatedAt: updatedAt ?? timestamp,
          ),
        );
  }

  Future<void> upsertProductFromRemote({
    required int shopId,
    required int? categoryId,
    required String serverId,
    required String name,
    String? sku,
    required int quantityInStock,
    int? alertThreshold,
    int? priceBuy,
    required int priceSell,
    int? priceSemiWholesale,
    int? priceWholesale,
    required bool isArchived,
    int? createdAt,
    int? updatedAt,
  }) async {
    final timestamp = nowMs();
    final existingRows = await (_db.select(_db.products)
          ..where(
            (p) => p.shopId.equals(shopId) & p.serverId.equals(serverId),
          ))
        .get();
    final existing = existingRows.isEmpty ? null : existingRows.first;

    if (existing != null) {
      await updateProductRow(
        existing.id,
        ProductsCompanion(
          categoryId: Value(categoryId),
          name: Value(name),
          sku: Value(sku),
          quantityInStock: Value(quantityInStock),
          alertThreshold: Value(alertThreshold),
          priceBuy: Value(priceBuy),
          priceSell: Value(priceSell),
          priceSemiWholesale: Value(priceSemiWholesale),
          priceWholesale: Value(priceWholesale),
          isArchived: Value(isArchived),
          updatedAt: Value(updatedAt ?? timestamp),
          syncedAt: Value(timestamp),
        ),
      );
      if (existingRows.length > 1) {
        final duplicateIds = existingRows.skip(1).map((p) => p.id).toList();
        await (_db.delete(_db.products)..where((p) => p.id.isIn(duplicateIds))).go();
      }
      return;
    }

    await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            shopId: shopId,
            categoryId: Value(categoryId),
            name: name,
            sku: Value(sku),
            quantityInStock: Value(quantityInStock),
            alertThreshold: Value(alertThreshold),
            priceBuy: Value(priceBuy),
            priceSell: priceSell,
            priceSemiWholesale: Value(priceSemiWholesale),
            priceWholesale: Value(priceWholesale),
            isArchived: Value(isArchived),
            createdAt: createdAt ?? timestamp,
            updatedAt: updatedAt ?? timestamp,
            serverId: Value(serverId),
            syncedAt: Value(timestamp),
          ),
        );
  }

  Future<void> updateProductServerSync({
    required int productId,
    required String serverId,
  }) async {
    final timestamp = nowMs();
    await (_db.update(_db.products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        serverId: Value(serverId),
        syncedAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }
}
