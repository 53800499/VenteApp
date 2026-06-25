import '../../domain/entities/inventory_entities.dart';
import '../../domain/repositories/inventory_repository.dart';

class ListProducts {
  const ListProducts(this._repository);

  final InventoryRepository _repository;

  Future<List<Product>> call({
    required int shopId,
    required ProductListFilters filters,
    int defaultAlertThreshold = 0,
  }) =>
      _repository.listProducts(
        shopId: shopId,
        filters: filters,
        defaultAlertThreshold: defaultAlertThreshold,
      );
}

class ListCategories {
  const ListCategories(this._repository);

  final InventoryRepository _repository;

  Future<List<ProductCategory>> call({
    required int shopId,
    bool activeOnly = true,
  }) =>
      _repository.listCategories(shopId: shopId, activeOnly: activeOnly);
}

class ListCategoriesWithStats {
  const ListCategoriesWithStats(this._repository);

  final InventoryRepository _repository;

  Future<List<CategoryWithStats>> call({
    required int shopId,
    bool activeOnly = false,
  }) =>
      _repository.listCategoriesWithStats(
        shopId: shopId,
        activeOnly: activeOnly,
      );
}

class CreateCategory {
  const CreateCategory(this._repository);

  final InventoryRepository _repository;

  Future<ProductCategory> call({
    required int shopId,
    required CreateCategoryInput input,
  }) =>
      _repository.createCategory(shopId: shopId, input: input);
}

class UpdateCategory {
  const UpdateCategory(this._repository);

  final InventoryRepository _repository;

  Future<ProductCategory> call({
    required int shopId,
    required int categoryId,
    required UpdateCategoryInput input,
  }) =>
      _repository.updateCategory(
        shopId: shopId,
        categoryId: categoryId,
        input: input,
      );
}

class DeleteCategory {
  const DeleteCategory(this._repository);

  final InventoryRepository _repository;

  Future<void> call({
    required int shopId,
    required int categoryId,
  }) =>
      _repository.deleteCategory(shopId: shopId, categoryId: categoryId);
}

class GetProductDetail {
  const GetProductDetail(this._repository);

  final InventoryRepository _repository;

  Future<ProductDetail> call({
    required int shopId,
    required int productId,
    int defaultAlertThreshold = 0,
  }) =>
      _repository.getProductDetail(
        shopId: shopId,
        productId: productId,
        defaultAlertThreshold: defaultAlertThreshold,
      );
}

class CreateProduct {
  const CreateProduct(this._repository);

  final InventoryRepository _repository;

  Future<Product> call({
    required int shopId,
    required int userId,
    required CreateProductInput input,
    int defaultAlertThreshold = 0,
  }) =>
      _repository.createProduct(
        shopId: shopId,
        userId: userId,
        input: input,
        defaultAlertThreshold: defaultAlertThreshold,
      );
}

class UpdateProduct {
  const UpdateProduct(this._repository);

  final InventoryRepository _repository;

  Future<Product> call({
    required int shopId,
    required int productId,
    required UpdateProductInput input,
    int defaultAlertThreshold = 0,
  }) =>
      _repository.updateProduct(
        shopId: shopId,
        productId: productId,
        input: input,
        defaultAlertThreshold: defaultAlertThreshold,
      );
}

class ArchiveProduct {
  const ArchiveProduct(this._repository);

  final InventoryRepository _repository;

  Future<void> call({
    required int shopId,
    required int productId,
  }) =>
      _repository.archiveProduct(shopId: shopId, productId: productId);
}

class AdjustProductStock {
  const AdjustProductStock(this._repository);

  final InventoryRepository _repository;

  Future<Product> call({
    required int shopId,
    required int userId,
    required int productId,
    required AdjustStockInput input,
    int defaultAlertThreshold = 0,
  }) =>
      _repository.adjustStock(
        shopId: shopId,
        userId: userId,
        productId: productId,
        input: input,
        defaultAlertThreshold: defaultAlertThreshold,
      );
}
