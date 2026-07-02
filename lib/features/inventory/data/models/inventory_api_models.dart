class CategoryApiDto {
  const CategoryApiDto({
    required this.id,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final bool isActive;
  final int sortOrder;

  factory CategoryApiDto.fromJson(Map<String, dynamic> json) {
    return CategoryApiDto(
      id: json['id'] as int,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class ProductApiDto {
  const ProductApiDto({
    required this.id,
    required this.name,
    this.categoryId,
    this.sku,
    required this.quantityInStock,
    this.alertThreshold,
    this.priceBuy,
    required this.priceSell,
    required this.isArchived,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final int? categoryId;
  final String? sku;
  final int quantityInStock;
  final int? alertThreshold;
  final int? priceBuy;
  final int priceSell;
  final bool isArchived;
  final int? createdAt;
  final int? updatedAt;

  factory ProductApiDto.fromJson(Map<String, dynamic> json) {
    return ProductApiDto(
      id: json['id'] as int,
      name: json['name'] as String,
      categoryId: json['categoryId'] as int?,
      sku: json['sku'] as String?,
      quantityInStock: json['quantityInStock'] as int? ?? 0,
      alertThreshold: json['alertThreshold'] as int?,
      priceBuy: json['priceBuy'] as int?,
      priceSell: json['priceSell'] as int,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: json['createdAt'] as int?,
      updatedAt: json['updatedAt'] as int?,
    );
  }
}
