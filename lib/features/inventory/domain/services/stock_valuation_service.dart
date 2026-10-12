import '../../../../core/utils/time.dart';
import '../entities/inventory_entities.dart';
import '../entities/inventory_lot_entities.dart';
import '../entities/stock_valuation_entities.dart';

/// Service métier de valorisation du stock (FIFO / PMP / CA potentiel / Marge).
class StockValuationService {
  const StockValuationService();

  /// Calcule la valorisation d'un produit en respectant le FIFO des lots réels
  /// avec repli gracieux sur le prix d'achat catalogue.
  ProductStockValuation calculateProductValuation({
    required Product product,
    List<InventoryLot> activeLots = const [],
    int? lastSaleAt,
    int? currentTimestampMs,
  }) {
    final now = currentTimestampMs ?? nowMs();
    final qty = product.quantityInStock;

    if (qty <= 0) {
      final baseBuy = product.priceBuy ?? 0;
      return ProductStockValuation(
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        categoryName: product.categoryName,
        quantityInStock: 0,
        priceSell: product.priceSell,
        priceBuy: product.priceBuy,
        purchaseValue: 0,
        averagePurchasePrice: baseBuy,
        potentialRevenue: 0,
        potentialMargin: 0,
        marginRate: 0.0,
        lotCount: 0,
        isFifoValued: false,
        lastSaleAt: lastSaleAt,
        daysSinceLastSale: _computeDaysSince(lastSaleAt, now),
        isLowStock: product.isLowStock,
        isDeadStock: false,
      );
    }

    int purchaseVal = 0;
    bool isFifo = false;

    if (activeLots.isNotEmpty) {
      isFifo = true;
      var remainingToCover = qty;
      var computedLotsCost = 0;

      for (final lot in activeLots) {
        if (remainingToCover <= 0) break;
        final take = lot.quantityRemaining.clamp(0, remainingToCover);
        computedLotsCost += take * lot.unitCost;
        remainingToCover -= take;
      }

      // Si le stock physique dépasse la somme des lots tracés, repli pour le solde
      if (remainingToCover > 0) {
        final fallbackUnit = product.priceBuy ??
            (qty > remainingToCover && (qty - remainingToCover) > 0
                ? (computedLotsCost / (qty - remainingToCover)).round()
                : 0);
        computedLotsCost += remainingToCover * fallbackUnit;
      }

      purchaseVal = computedLotsCost;
    } else {
      // Repli catalogue
      final unitBuy = product.priceBuy ?? 0;
      purchaseVal = qty * unitBuy;
      isFifo = false;
    }

    final avgBuy = qty > 0 ? (purchaseVal / qty).round() : (product.priceBuy ?? 0);
    final potentialRev = qty * product.priceSell;
    final potentialMarg = potentialRev - purchaseVal;
    final marginPct =
        purchaseVal > 0 ? (potentialMarg / purchaseVal) * 100.0 : 0.0;

    final days = _computeDaysSince(lastSaleAt, now);
    final isDead = qty > 0 && (lastSaleAt == null || (days != null && days >= 30));

    return ProductStockValuation(
      productId: product.id,
      productName: product.name,
      sku: product.sku,
      categoryName: product.categoryName,
      quantityInStock: qty,
      priceSell: product.priceSell,
      priceBuy: product.priceBuy,
      purchaseValue: purchaseVal,
      averagePurchasePrice: avgBuy,
      potentialRevenue: potentialRev,
      potentialMargin: potentialMarg,
      marginRate: marginPct,
      lotCount: activeLots.length,
      isFifoValued: isFifo,
      lastSaleAt: lastSaleAt,
      daysSinceLastSale: days,
      isLowStock: product.isLowStock,
      isDeadStock: isDead,
    );
  }

  /// Synthèse consolidée pour l'ensemble des articles d'une boutique.
  StockValuationSummary calculateSummary(List<ProductStockValuation> items) {
    if (items.isEmpty) {
      return const StockValuationSummary(
        totalProductsCount: 0,
        totalUnitsInStock: 0,
        totalPurchaseValue: 0,
        totalPotentialRevenue: 0,
        totalPotentialMargin: 0,
        overallMarginRate: 0.0,
        deadStockCount: 0,
        lowStockCount: 0,
        items: [],
      );
    }

    final totalUnits = items.fold<int>(0, (sum, i) => sum + i.quantityInStock);
    final totalPurchase = items.fold<int>(0, (sum, i) => sum + i.purchaseValue);
    final totalPotential =
        items.fold<int>(0, (sum, i) => sum + i.potentialRevenue);
    final totalMargin = totalPotential - totalPurchase;
    final overallRate =
        totalPurchase > 0 ? (totalMargin / totalPurchase) * 100.0 : 0.0;

    final deadCount = items.where((i) => i.isDeadStock).length;
    final lowCount = items.where((i) => i.isLowStock).length;

    return StockValuationSummary(
      totalProductsCount: items.length,
      totalUnitsInStock: totalUnits,
      totalPurchaseValue: totalPurchase,
      totalPotentialRevenue: totalPotential,
      totalPotentialMargin: totalMargin,
      overallMarginRate: overallRate,
      deadStockCount: deadCount,
      lowStockCount: lowCount,
      items: items,
    );
  }

  int? _computeDaysSince(int? timestampMs, int nowMs) {
    if (timestampMs == null) return null;
    final diff = nowMs - timestampMs;
    if (diff < 0) return 0;
    return (diff / (1000 * 60 * 60 * 24)).floor();
  }
}
