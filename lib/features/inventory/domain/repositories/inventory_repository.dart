import '../entities/inventory_entities.dart';

abstract class InventoryRepository {
  Future<List<ProductCategory>> listCategories({
    required int shopId,
    bool activeOnly = true,
  });

  Future<List<CategoryWithStats>> listCategoriesWithStats({
    required int shopId,
    bool activeOnly = false,
  });

  Future<int> ensureDefaultCategory(int shopId);

  Future<ProductCategory> createCategory({
    required int shopId,
    required CreateCategoryInput input,
  });

  Future<ProductCategory> updateCategory({
    required int shopId,
    required int categoryId,
    required UpdateCategoryInput input,
  });

  Future<void> deleteCategory({
    required int shopId,
    required int categoryId,
  });

  Future<List<Product>> listProducts({
    required int shopId,
    required ProductListFilters filters,
    required int defaultAlertThreshold,
  });

  Future<ProductDetail> getProductDetail({
    required int shopId,
    required int productId,
    required int defaultAlertThreshold,
  });

  Future<Product> createProduct({
    required int shopId,
    required int userId,
    required CreateProductInput input,
    required int defaultAlertThreshold,
  });

  Future<Product> updateProduct({
    required int shopId,
    required int productId,
    required UpdateProductInput input,
    required int defaultAlertThreshold,
  });

  Future<void> archiveProduct({
    required int shopId,
    required int productId,
  });

  Future<Product> adjustStock({
    required int shopId,
    required int userId,
    required int productId,
    required AdjustStockInput input,
    required int defaultAlertThreshold,
  });
}
