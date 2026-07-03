import 'package:equatable/equatable.dart';

enum ProductSort { nameAsc, nameDesc, stockAsc, stockDesc, priceAsc, priceDesc }

enum StockAdjustmentType { restock, adjustment, loss }

enum StockMovementType {
  sale,
  restock,
  adjustment,
  loss,
  return_,
  initial,
  saleCancel,
}

class ProductCategory extends Equatable {
  const ProductCategory({
    required this.id,
    required this.shopId,
    required this.name,
    this.description,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final int shopId;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  @override
  List<Object?> get props => [id, shopId, name, description, isActive, sortOrder];
}

class CategoryWithStats extends Equatable {
  const CategoryWithStats({
    required this.category,
    required this.productCount,
  });

  final ProductCategory category;
  final int productCount;

  @override
  List<Object?> get props => [category, productCount];
}

class CreateCategoryInput extends Equatable {
  const CreateCategoryInput({
    required this.name,
    this.description,
    this.sortOrder = 0,
  });

  final String name;
  final String? description;
  final int sortOrder;

  @override
  List<Object?> get props => [name, description, sortOrder];
}

class UpdateCategoryInput extends Equatable {
  const UpdateCategoryInput({
    this.name,
    this.description,
    this.isActive,
    this.sortOrder,
  });

  final String? name;
  final String? description;
  final bool? isActive;
  final int? sortOrder;

  @override
  List<Object?> get props => [name, description, isActive, sortOrder];
}

class Product extends Equatable {
  const Product({
    required this.id,
    required this.shopId,
    required this.categoryId,
    required this.name,
    this.sku,
    required this.quantityInStock,
    required this.alertThreshold,
    this.priceBuy,
    required this.priceSell,
    this.priceSemiWholesale,
    this.priceWholesale,
    required this.isArchived,
    required this.isLowStock,
    this.categoryName,
  });

  final int id;
  final int shopId;
  final int categoryId;
  final String name;
  final String? sku;
  final int quantityInStock;
  final int alertThreshold;
  final int? priceBuy;
  final int priceSell;
  final int? priceSemiWholesale;
  final int? priceWholesale;
  final bool isArchived;
  final bool isLowStock;
  final String? categoryName;

  @override
  List<Object?> get props => [
        id,
        shopId,
        categoryId,
        name,
        sku,
        quantityInStock,
        alertThreshold,
        priceBuy,
        priceSell,
        priceSemiWholesale,
        priceWholesale,
        isArchived,
        isLowStock,
        categoryName,
      ];
}

class StockMovement extends Equatable {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.userId,
    required this.type,
    required this.quantityChange,
    required this.quantityBefore,
    required this.quantityAfter,
    this.reason,
    this.unitCost,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final int userId;
  final StockMovementType type;
  final int quantityChange;
  final int quantityBefore;
  final int quantityAfter;
  final String? reason;
  final int? unitCost;
  final int createdAt;

  @override
  List<Object?> get props => [
        id,
        productId,
        userId,
        type,
        quantityChange,
        quantityBefore,
        quantityAfter,
        reason,
        unitCost,
        createdAt,
      ];
}

class ProductDetail extends Equatable {
  const ProductDetail({
    required this.product,
    required this.recentMovements,
    required this.saleItemCount,
  });

  final Product product;
  final List<StockMovement> recentMovements;
  final int saleItemCount;

  @override
  List<Object?> get props => [product, recentMovements, saleItemCount];
}

class CreateProductInput extends Equatable {
  const CreateProductInput({
    required this.name,
    required this.categoryId,
    this.sku,
    required this.priceSell,
    this.priceBuy,
    this.priceSemiWholesale,
    this.priceWholesale,
    required this.initialQuantity,
    this.alertThreshold,
  });

  final String name;
  final int categoryId;
  final String? sku;
  final int priceSell;
  final int? priceBuy;
  final int? priceSemiWholesale;
  final int? priceWholesale;
  final int initialQuantity;
  final int? alertThreshold;

  @override
  List<Object?> get props => [
        name,
        categoryId,
        sku,
        priceSell,
        priceBuy,
        priceSemiWholesale,
        priceWholesale,
        initialQuantity,
        alertThreshold,
      ];
}

class UpdateProductInput extends Equatable {
  const UpdateProductInput({
    this.name,
    this.categoryId,
    this.sku,
    this.priceSell,
    this.priceBuy,
    this.priceSemiWholesale,
    this.priceWholesale,
    this.clearPriceBuy = false,
    this.alertThreshold,
  });

  final String? name;
  final int? categoryId;
  final String? sku;
  final int? priceSell;
  final int? priceBuy;
  final int? priceSemiWholesale;
  final int? priceWholesale;
  final bool clearPriceBuy;
  final int? alertThreshold;

  @override
  List<Object?> get props => [
        name,
        categoryId,
        sku,
        priceSell,
        priceBuy,
        priceSemiWholesale,
        priceWholesale,
        clearPriceBuy,
        alertThreshold,
      ];
}

class AdjustStockInput extends Equatable {
  const AdjustStockInput({
    required this.type,
    required this.quantityChange,
    this.reason,
    this.unitCost,
  });

  final StockAdjustmentType type;
  final int quantityChange;
  final String? reason;
  final int? unitCost;

  @override
  List<Object?> get props => [type, quantityChange, reason, unitCost];
}

class ProductListFilters extends Equatable {
  const ProductListFilters({
    this.search,
    this.categoryId,
    this.lowStockOnly = false,
    this.includeArchived = false,
    this.sort = ProductSort.nameAsc,
  });

  final String? search;
  final int? categoryId;
  final bool lowStockOnly;
  final bool includeArchived;
  final ProductSort sort;

  ProductListFilters copyWith({
    String? search,
    int? categoryId,
    bool? lowStockOnly,
    bool? includeArchived,
    ProductSort? sort,
    bool clearSearch = false,
    bool clearCategory = false,
  }) {
    return ProductListFilters(
      search: clearSearch ? null : (search ?? this.search),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      includeArchived: includeArchived ?? this.includeArchived,
      sort: sort ?? this.sort,
    );
  }

  @override
  List<Object?> get props => [
        search,
        categoryId,
        lowStockOnly,
        includeArchived,
        sort,
      ];
}
