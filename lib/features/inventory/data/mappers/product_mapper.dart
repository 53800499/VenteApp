import '../../../../core/database/app_database.dart';
import '../../domain/entities/inventory_entities.dart' as inv;
import '../../domain/entities/product_pricing_entities.dart';

class ProductMapper {
  const ProductMapper._();

  static inv.Product fromRow({
    required Product row,
    required int effectiveThreshold,
    String? categoryName,
  }) {
    return inv.Product(
      id: row.id,
      shopId: row.shopId,
      categoryId: row.categoryId ?? 0,
      name: row.name,
      sku: row.sku,
      quantityInStock: row.quantityInStock,
      alertThreshold: effectiveThreshold,
      priceBuy: row.priceBuy,
      priceSell: row.priceSell,
      priceSemiWholesale: row.priceSemiWholesale,
      priceWholesale: row.priceWholesale,
      pricingMode: ProductPricingMode.fromDb(row.pricingMode),
      marginValue: row.marginValue,
      isArchived: row.isArchived,
      isLowStock: !row.isArchived && row.quantityInStock <= effectiveThreshold,
      categoryName: categoryName,
    );
  }

  static inv.ProductCategory categoryFromRow(Category row) {
    return inv.ProductCategory(
      id: row.id,
      shopId: row.shopId,
      name: row.name,
      description: row.description,
      isActive: row.isActive,
      sortOrder: row.sortOrder,
    );
  }

  static inv.StockMovement movementFromRow(StockMovement row) {
    return inv.StockMovement(
      id: row.id,
      productId: row.productId,
      userId: row.userId,
      type: _parseMovementType(row.type),
      quantityChange: row.quantityChange,
      quantityBefore: row.quantityBefore,
      quantityAfter: row.quantityAfter,
      reason: row.reason,
      unitCost: row.unitCost,
      createdAt: row.createdAt,
    );
  }

  static inv.StockMovementType _parseMovementType(String raw) {
    return switch (raw) {
      'sale' => inv.StockMovementType.sale,
      'restock' => inv.StockMovementType.restock,
      'adjustment' => inv.StockMovementType.adjustment,
      'loss' => inv.StockMovementType.loss,
      'return' => inv.StockMovementType.return_,
      'initial' => inv.StockMovementType.initial,
      'sale_cancel' => inv.StockMovementType.saleCancel,
      'transfer_out' => inv.StockMovementType.transferOut,
      'transfer_in' => inv.StockMovementType.transferIn,
      _ => inv.StockMovementType.adjustment,
    };
  }

  static String movementTypeToDb(inv.StockAdjustmentType type) {
    return switch (type) {
      inv.StockAdjustmentType.restock => 'restock',
      inv.StockAdjustmentType.adjustment => 'adjustment',
      inv.StockAdjustmentType.loss => 'loss',
    };
  }
}
