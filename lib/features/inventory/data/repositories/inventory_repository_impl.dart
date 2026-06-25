import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' hide Product;
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/time.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/services/category_validation_service.dart';
import '../../domain/services/product_validation_service.dart';
import '../datasources/local/inventory_local_datasource.dart';
import '../mappers/product_mapper.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl({
    required InventoryLocalDatasource local,
    ProductValidationService? validation,
    CategoryValidationService? categoryValidation,
  })  : _local = local,
        _validation = validation ?? const ProductValidationService(),
        _categoryValidation = categoryValidation ?? const CategoryValidationService();

  final InventoryLocalDatasource _local;
  final ProductValidationService _validation;
  final CategoryValidationService _categoryValidation;

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
}
