class CategoryApiDto {
  const CategoryApiDto({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  factory CategoryApiDto.fromJson(Map<String, dynamic> json) {
    return CategoryApiDto(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
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

class InventoryLotApiDto {
  const InventoryLotApiDto({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.sourceType,
    this.sourceId,
    this.purchaseReceiptItemId,
    this.supplierId,
    required this.unitCost,
    required this.quantityReceived,
    required this.quantityRemaining,
    this.batchNumber,
    this.expiryDate,
    required this.receivedAt,
    required this.status,
    required this.createdAt,
    required this.version,
  });

  final int id;
  final int shopId;
  final int productId;
  final String sourceType;
  final int? sourceId;
  final int? purchaseReceiptItemId;
  final int? supplierId;
  final int unitCost;
  final int quantityReceived;
  final int quantityRemaining;
  final String? batchNumber;
  final int? expiryDate;
  final int receivedAt;
  final String status;
  final int createdAt;
  final int version;

  factory InventoryLotApiDto.fromJson(Map<String, dynamic> json) {
    return InventoryLotApiDto(
      id: json['id'] as int,
      shopId: json['shopId'] as int,
      productId: json['productId'] as int,
      sourceType: json['sourceType'] as String,
      sourceId: json['sourceId'] as int?,
      purchaseReceiptItemId: json['purchaseReceiptItemId'] as int?,
      supplierId: json['supplierId'] as int?,
      unitCost: json['unitCost'] as int,
      quantityReceived: json['quantityReceived'] as int,
      quantityRemaining: json['quantityRemaining'] as int,
      batchNumber: json['batchNumber'] as String?,
      expiryDate: json['expiryDate'] as int?,
      receivedAt: json['receivedAt'] as int,
      status: json['status'] as String,
      createdAt: json['createdAt'] as int,
      version: json['version'] as int,
    );
  }
}
