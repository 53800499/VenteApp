import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/utils/time.dart';
import 'package:frontend/features/inventory/data/datasources/local/inventory_local_datasource.dart';
import 'package:frontend/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:frontend/core/errors/failures.dart';
import 'package:frontend/features/inventory/domain/entities/inventory_entities.dart';

import '../../../../support/auth_test_helpers.dart';

void main() {
  late AppDatabase database;
  late InventoryRepositoryImpl repository;
  late int shopId;
  late int userId;
  late int categoryId;

  setUp(() async {
    database = createTestDatabase();
    repository = InventoryRepositoryImpl(
      local: InventoryLocalDatasource(database),
    );

    final timestamp = nowMs();
    shopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(
            name: const Value('Boutique Test'),
            createdAt: timestamp,
          ),
        );

    userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: shopId,
            name: 'Patron',
            pinHash: 'hash',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );

    categoryId = await repository.ensureDefaultCategory(shopId);
  });

  test('crée un produit avec stock initial (UC-03)', () async {
    final product = await repository.createProduct(
      shopId: shopId,
      userId: userId,
      input: CreateProductInput(
        name: 'Riz 25kg',
        categoryId: categoryId,
        priceSell: 15000,
        priceBuy: 12000,
        initialQuantity: 10,
      ),
      defaultAlertThreshold: 5,
    );

    expect(product.name, 'Riz 25kg');
    expect(product.quantityInStock, 10);
    expect(product.priceSell, 15000);
  });

  test('liste les produits en stock faible', () async {
    await repository.createProduct(
      shopId: shopId,
      userId: userId,
      input: CreateProductInput(
        name: 'Huile',
        categoryId: categoryId,
        priceSell: 2000,
        initialQuantity: 2,
        alertThreshold: 5,
      ),
      defaultAlertThreshold: 5,
    );

    final lowStock = await repository.listProducts(
      shopId: shopId,
      filters: const ProductListFilters(lowStockOnly: true),
      defaultAlertThreshold: 5,
    );

    expect(lowStock, hasLength(1));
    expect(lowStock.first.isLowStock, isTrue);
  });

  test('ajuste le stock par réapprovisionnement (UC-04)', () async {
    final created = await repository.createProduct(
      shopId: shopId,
      userId: userId,
      input: CreateProductInput(
        name: 'Sucre',
        categoryId: categoryId,
        priceSell: 1000,
        initialQuantity: 5,
      ),
      defaultAlertThreshold: 5,
    );

    final updated = await repository.adjustStock(
      shopId: shopId,
      userId: userId,
      productId: created.id,
      input: const AdjustStockInput(
        type: StockAdjustmentType.restock,
        quantityChange: 10,
      ),
      defaultAlertThreshold: 5,
    );

    expect(updated.quantityInStock, 15);
  });

  test('crée et supprime une catégorie vide', () async {
    final created = await repository.createCategory(
      shopId: shopId,
      input: const CreateCategoryInput(name: 'Boissons'),
    );

    expect(created.name, 'Boissons');

    await repository.deleteCategory(shopId: shopId, categoryId: created.id);

    final categories = await repository.listCategories(shopId: shopId);
    expect(categories.any((c) => c.id == created.id), isFalse);
  });

  test('refuse de supprimer une catégorie avec produits', () async {
    final category = await repository.createCategory(
      shopId: shopId,
      input: const CreateCategoryInput(name: 'Épicerie'),
    );

    await repository.createProduct(
      shopId: shopId,
      userId: userId,
      input: CreateProductInput(
        name: 'Pâtes',
        categoryId: category.id,
        priceSell: 500,
        initialQuantity: 1,
      ),
      defaultAlertThreshold: 5,
    );

    expect(
      () => repository.deleteCategory(shopId: shopId, categoryId: category.id),
      throwsA(isA<ConflictFailure>()),
    );
  });

  test('refuse un nom de catégorie en doublon', () async {
    await repository.createCategory(
      shopId: shopId,
      input: const CreateCategoryInput(name: 'Hygiène'),
    );

    expect(
      () => repository.createCategory(
        shopId: shopId,
        input: const CreateCategoryInput(name: 'Hygiène'),
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
