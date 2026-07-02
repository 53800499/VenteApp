import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' hide Product;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/utils/time.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/services/category_validation_service.dart';
import '../../domain/services/product_validation_service.dart';
import '../datasources/local/inventory_local_datasource.dart';
import '../datasources/remote/inventory_remote_datasource.dart';
import '../mappers/product_mapper.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl({
    required InventoryLocalDatasource local,
    InventoryRemoteDatasource? remote,
    RemoteApiGuard? apiGuard,
    ProductValidationService? validation,
    CategoryValidationService? categoryValidation,
    LocalWriteSyncRecorder? recorder,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _validation = validation ?? const ProductValidationService(),
        _categoryValidation = categoryValidation ?? const CategoryValidationService(),
        _recorder = recorder;

  final InventoryLocalDatasource _local;
  final InventoryRemoteDatasource? _remote;
  final RemoteApiGuard? _apiGuard;
  final ProductValidationService _validation;
  final CategoryValidationService _categoryValidation;
  final LocalWriteSyncRecorder? _recorder;

  @override
  Future<List<ProductCategory>> listCategories({
    required int shopId,
    bool activeOnly = true,
  }) async {
    await _local.ensureDefaultCategory(shopId);
    return _local.listCategories(shopId: shopId, activeOnly: activeOnly);
  }

  @override
  Future<int> ensureDefaultCategory(int shopId) =>
      _local.ensureDefaultCategory(shopId);

  @override
  Future<List<CategoryWithStats>> listCategoriesWithStats({
    required int shopId,
    bool activeOnly = false,
  }) async {
    await _local.ensureDefaultCategory(shopId);
    final categories =
        await _local.listCategories(shopId: shopId, activeOnly: activeOnly);

    final stats = <CategoryWithStats>[];
    for (final category in categories) {
      final count = await _local.countProductsByCategory(shopId, category.id);
      stats.add(CategoryWithStats(category: category, productCount: count));
    }
    return stats;
  }

  @override
  Future<ProductCategory> createCategory({
    required int shopId,
    required CreateCategoryInput input,
  }) async {
    _categoryValidation.validateName(input.name);

    final exists = await _local.existsCategoryByName(shopId, input.name);
    if (exists) {
      throw ValidationFailure(
        'Une catégorie « ${input.name.trim()} » existe déjà.',
      );
    }

    final id = await _local.insertCategory(
      shopId: shopId,
      name: input.name,
      sortOrder: input.sortOrder,
    );

    final row = await _local.findCategory(shopId, id);
    if (row == null) {
      throw const NotFoundFailure('Catégorie introuvable après création.');
    }
    await _recorder?.recordCategoryCreate(
      shopId: shopId,
      categoryId: id,
      name: row.name,
      sortOrder: row.sortOrder,
    );
    return ProductMapper.categoryFromRow(row);
  }

  @override
  Future<ProductCategory> updateCategory({
    required int shopId,
    required int categoryId,
    required UpdateCategoryInput input,
  }) async {
    final existing = await _local.findCategory(shopId, categoryId);
    if (existing == null) {
      throw const NotFoundFailure('Catégorie introuvable.');
    }

    if (input.name != null) {
      _categoryValidation.validateName(input.name!);
      final exists = await _local.existsCategoryByName(
        shopId,
        input.name!,
        excludeId: categoryId,
      );
      if (exists) {
        throw ValidationFailure(
          'Une catégorie « ${input.name!.trim()} » existe déjà.',
        );
      }
    }

    await _local.updateCategoryRow(
      categoryId,
      CategoriesCompanion(
        name: input.name != null ? Value(input.name!.trim()) : const Value.absent(),
        isActive:
            input.isActive != null ? Value(input.isActive!) : const Value.absent(),
        sortOrder:
            input.sortOrder != null ? Value(input.sortOrder!) : const Value.absent(),
        updatedAt: Value(nowMs()),
      ),
    );

    final updated = await _local.findCategory(shopId, categoryId);
    await _recorder?.recordCategoryUpdate(
      shopId: shopId,
      categoryId: categoryId,
      fields: {
        if (input.name != null) 'name': input.name!.trim(),
        if (input.isActive != null) 'isActive': input.isActive,
        if (input.sortOrder != null) 'sortOrder': input.sortOrder,
      },
    );
    return ProductMapper.categoryFromRow(updated!);
  }

  @override
  Future<void> deleteCategory({
    required int shopId,
    required int categoryId,
  }) async {
    final existing = await _local.findCategory(shopId, categoryId);
    if (existing == null) {
      throw const NotFoundFailure('Catégorie introuvable.');
    }

    _categoryValidation.assertCanDelete(existing.name);

    final productCount = await _local.countProductsByCategory(shopId, categoryId);
    if (productCount > 0) {
      throw ConflictFailure(
        'Impossible de supprimer : $productCount produit(s) utilisent cette catégorie.',
      );
    }

    await _local.deleteCategoryRow(categoryId);
  }

  @override
  Future<List<Product>> listProducts({
    required int shopId,
    required ProductListFilters filters,
    required int defaultAlertThreshold,
  }) async {
    await _local.ensureDefaultCategory(shopId);
    final threshold =
        defaultAlertThreshold > 0 ? defaultAlertThreshold : await _local.getDefaultAlertThreshold(shopId);

    final rows = await _local.listProductRows(
      shopId: shopId,
      filters: filters,
    );

    final products = rows
        .map(
          (row) => ProductMapper.fromRow(
            row: row.product,
            effectiveThreshold:
                row.product.alertThreshold ?? threshold,
            categoryName: row.categoryName,
          ),
        )
        .toList();

    if (filters.lowStockOnly) {
      return products.where((p) => p.isLowStock).toList();
    }
    return products;
  }

  @override
  Future<ProductDetail> getProductDetail({
    required int shopId,
    required int productId,
    required int defaultAlertThreshold,
  }) async {
    final row = await _local.findProduct(shopId, productId);
    if (row == null) {
      throw const NotFoundFailure('Produit introuvable.');
    }

    final threshold = defaultAlertThreshold > 0
        ? defaultAlertThreshold
        : await _local.getDefaultAlertThreshold(shopId);
    final effective = row.alertThreshold ?? threshold;
    final categoryName = row.categoryId != null
        ? await _local.findCategoryName(row.categoryId!)
        : null;

    final movements = await _local.listRecentMovements(shopId, productId);
    final saleItemCount = await _local.countSaleItems(shopId, productId);

    return ProductDetail(
      product: ProductMapper.fromRow(
        row: row,
        effectiveThreshold: effective,
        categoryName: categoryName,
      ),
      recentMovements: movements
          .map(ProductMapper.movementFromRow)
          .toList(),
      saleItemCount: saleItemCount,
    );
  }

  @override
  Future<Product> createProduct({
    required int shopId,
    required int userId,
    required CreateProductInput input,
    required int defaultAlertThreshold,
  }) async {
    _validation.validateName(input.name);
    _validation.validatePrices(
      priceSell: input.priceSell,
      priceBuy: input.priceBuy,
    );
    _validation.validateInitialQuantity(input.initialQuantity);

    final category = await _local.findActiveCategory(shopId, input.categoryId);
    if (category == null) {
      throw const ValidationFailure('Catégorie invalide ou inactive.');
    }

    final shopDefault = defaultAlertThreshold > 0
        ? defaultAlertThreshold
        : await _local.getDefaultAlertThreshold(shopId);
    final alertThreshold = _validation.resolveAlertThreshold(
      input.alertThreshold,
      shopDefault: shopDefault,
    );

    final productId = await _local.insertProduct(
      shopId: shopId,
      categoryId: input.categoryId,
      name: input.name.trim(),
      sku: input.sku?.trim().isEmpty == true ? null : input.sku?.trim(),
      quantityInStock: input.initialQuantity,
      alertThreshold: alertThreshold,
      priceBuy: input.priceBuy,
      priceSell: input.priceSell,
    );

    if (input.initialQuantity > 0) {
      await _local.insertStockMovement(
        shopId: shopId,
        productId: productId,
        userId: userId,
        type: 'initial',
        quantityChange: input.initialQuantity,
        quantityBefore: 0,
        quantityAfter: input.initialQuantity,
        reason: 'Stock initial à la création',
      );
    }

    final detail = await getProductDetail(
      shopId: shopId,
      productId: productId,
      defaultAlertThreshold: shopDefault,
    );
    await _recorder?.recordProductCreate(
      shopId: shopId,
      productId: productId,
      payload: {
        'name': input.name.trim(),
        'localCategoryId': input.categoryId,
        if (input.sku != null && input.sku!.trim().isNotEmpty)
          'sku': input.sku!.trim(),
        'priceSell': input.priceSell,
        if (input.priceBuy != null) 'priceBuy': input.priceBuy,
        'initialQuantity': input.initialQuantity,
        'alertThreshold': alertThreshold,
      },
    );
    return detail.product;
  }

  @override
  Future<Product> updateProduct({
    required int shopId,
    required int productId,
    required UpdateProductInput input,
    required int defaultAlertThreshold,
  }) async {
    final existing = await _local.findProduct(shopId, productId);
    if (existing == null) {
      throw const NotFoundFailure('Produit introuvable.');
    }
    if (existing.isArchived) {
      throw const ConflictFailure('Ce produit est archivé.');
    }

    if (input.name != null) _validation.validateName(input.name!);

    final nextPriceSell = input.priceSell ?? existing.priceSell;
    final nextPriceBuy = input.clearPriceBuy
        ? null
        : (input.priceBuy ?? existing.priceBuy);
    if (input.priceSell != null || input.priceBuy != null || input.clearPriceBuy) {
      _validation.validatePrices(priceSell: nextPriceSell, priceBuy: nextPriceBuy);
    }

    if (input.categoryId != null) {
      final category =
          await _local.findActiveCategory(shopId, input.categoryId!);
      if (category == null) {
        throw const ValidationFailure('Catégorie invalide ou inactive.');
      }
    }

    final shopDefault = defaultAlertThreshold > 0
        ? defaultAlertThreshold
        : await _local.getDefaultAlertThreshold(shopId);

    await _local.updateProductRow(
      productId,
      ProductsCompanion(
        name: input.name != null ? Value(input.name!.trim()) : const Value.absent(),
        categoryId: input.categoryId != null
            ? Value(input.categoryId!)
            : const Value.absent(),
        sku: input.sku != null
            ? Value(input.sku!.trim().isEmpty ? null : input.sku!.trim())
            : const Value.absent(),
        priceSell: input.priceSell != null
            ? Value(input.priceSell!)
            : const Value.absent(),
        priceBuy: input.clearPriceBuy
            ? const Value(null)
            : input.priceBuy != null
                ? Value(input.priceBuy)
                : const Value.absent(),
        alertThreshold: input.alertThreshold != null
            ? Value(
                _validation.resolveAlertThreshold(
                  input.alertThreshold,
                  shopDefault: shopDefault,
                ),
              )
            : const Value.absent(),
        updatedAt: Value(nowMs()),
        version: Value(existing.version + 1),
      ),
    );

    final detail = await getProductDetail(
      shopId: shopId,
      productId: productId,
      defaultAlertThreshold: shopDefault,
    );
    await _recorder?.recordProductUpdate(
      shopId: shopId,
      productId: productId,
      fields: {
        if (input.name != null) 'name': input.name!.trim(),
        if (input.categoryId != null) 'localCategoryId': input.categoryId,
        if (input.sku != null) 'sku': input.sku!.trim(),
        if (input.priceSell != null) 'priceSell': input.priceSell,
        if (input.priceBuy != null) 'priceBuy': input.priceBuy,
        if (input.clearPriceBuy) 'priceBuy': null,
        if (input.alertThreshold != null) 'alertThreshold': input.alertThreshold,
      },
      version: existing.version + 1,
    );
    return detail.product;
  }

  @override
  Future<void> archiveProduct({
    required int shopId,
    required int productId,
  }) async {
    final existing = await _local.findProduct(shopId, productId);
    if (existing == null) {
      throw const NotFoundFailure('Produit introuvable.');
    }
    if (existing.isArchived) {
      throw const ConflictFailure('Ce produit est déjà archivé.');
    }

    await _local.updateProductRow(
      productId,
      ProductsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(nowMs()),
        version: Value(existing.version + 1),
      ),
    );
    await _recorder?.recordProductArchive(
      shopId: shopId,
      productId: productId,
    );
  }

  @override
  Future<Product> adjustStock({
    required int shopId,
    required int userId,
    required int productId,
    required AdjustStockInput input,
    required int defaultAlertThreshold,
  }) async {
    final existing = await _local.findProduct(shopId, productId);
    if (existing == null || existing.isArchived) {
      throw const NotFoundFailure('Produit introuvable.');
    }

    if (input.quantityChange == 0) {
      final detail = await getProductDetail(
        shopId: shopId,
        productId: productId,
        defaultAlertThreshold: defaultAlertThreshold,
      );
      return detail.product;
    }

    final result = _validation.validateStockAdjustment(
      type: input.type,
      currentStock: existing.quantityInStock,
      quantityChange: input.quantityChange,
      reason: input.reason,
    );

    await _local.updateProductRow(
      productId,
      ProductsCompanion(
        quantityInStock: Value(result.quantityAfter),
        updatedAt: Value(nowMs()),
        version: Value(existing.version + 1),
      ),
    );

    await _local.insertStockMovement(
      shopId: shopId,
      productId: productId,
      userId: userId,
      type: ProductMapper.movementTypeToDb(input.type),
      quantityChange: input.quantityChange,
      quantityBefore: result.quantityBefore,
      quantityAfter: result.quantityAfter,
      reason: input.reason?.trim(),
      unitCost: input.type == StockAdjustmentType.restock ? input.unitCost : null,
    );

    await _recorder?.recordStockAdjust(
      shopId: shopId,
      productId: productId,
      payload: {
        'type': ProductMapper.movementTypeToDb(input.type),
        'quantityChange': input.quantityChange,
        if (input.reason != null && input.reason!.trim().isNotEmpty)
          'reason': input.reason!.trim(),
        if (input.type == StockAdjustmentType.restock && input.unitCost != null)
          'unitCost': input.unitCost,
      },
    );

    final shopDefault = defaultAlertThreshold > 0
        ? defaultAlertThreshold
        : await _local.getDefaultAlertThreshold(shopId);

    final detail = await getProductDetail(
      shopId: shopId,
      productId: productId,
      defaultAlertThreshold: shopDefault,
    );
    return detail.product;
  }

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    final remote = _remote;
    final apiGuard = _apiGuard;
    if (remote == null || apiGuard == null) {
      throw const NetworkFailure('API distante non configurée.');
    }

    await apiGuard.ensureReady();
    final remoteCategories = await remote.listCategories();
    final categoryMap = <int, int>{};

    for (final category in remoteCategories) {
      final localId = await _local.upsertCategoryFromRemote(
        shopId: shopId,
        name: category.name,
        isActive: category.isActive,
        sortOrder: category.sortOrder,
      );
      categoryMap[category.id] = localId;
    }

    final defaultCategoryId = await _local.ensureDefaultCategory(shopId);
    final remoteProducts = await remote.listProducts(includeArchived: true);

    for (final product in remoteProducts) {
      final localCategoryId = product.categoryId == null
          ? defaultCategoryId
          : categoryMap[product.categoryId] ?? defaultCategoryId;

      await _local.upsertProductFromRemote(
        shopId: shopId,
        categoryId: localCategoryId,
        serverId: '${product.id}',
        name: product.name,
        sku: product.sku,
        quantityInStock: product.quantityInStock,
        alertThreshold: product.alertThreshold,
        priceBuy: product.priceBuy,
        priceSell: product.priceSell,
        isArchived: product.isArchived,
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
      );
    }
  }
}
