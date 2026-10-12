import 'package:equatable/equatable.dart';

/// Valorisation financière du stock d'un produit spécifique.
class ProductStockValuation extends Equatable {
  const ProductStockValuation({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.categoryName,
    required this.quantityInStock,
    required this.priceSell,
    this.priceBuy,
    required this.purchaseValue,
    required this.averagePurchasePrice,
    required this.potentialRevenue,
    required this.potentialMargin,
    required this.marginRate,
    required this.lotCount,
    required this.isFifoValued,
    this.lastSaleAt,
    this.daysSinceLastSale,
    required this.isLowStock,
    required this.isDeadStock,
  });

  final int productId;
  final String productName;
  final String? sku;
  final String? categoryName;
  final int quantityInStock;
  final int priceSell;
  final int? priceBuy;

  /// Valeur totale d'achat du stock (FIFO ou fallback).
  final int purchaseValue;

  /// Prix moyen d'achat unitaire (PMP = purchaseValue / quantity).
  final int averagePurchasePrice;

  /// Chiffre d'affaires potentiel si tout est vendu au prix de vente actuel.
  final int potentialRevenue;

  /// Marge brute potentielle = potentialRevenue - purchaseValue.
  final int potentialMargin;

  /// Taux de marge brute en % (potentialMargin / purchaseValue * 100).
  final double marginRate;

  /// Nombre de lots actifs traçables.
  final int lotCount;

  /// Vrai si calculé à partir des lots réels (FIFO).
  final bool isFifoValued;

  /// Horodatage (ms) de la dernière vente enregistrée.
  final int? lastSaleAt;

  /// Nombre de jours écoulés depuis la dernière vente.
  final int? daysSinceLastSale;

  /// Vrai si en alerte de stock bas.
  final bool isLowStock;

  /// Vrai si stock présent sans vente depuis au moins 30 jours.
  final bool isDeadStock;

  @override
  List<Object?> get props => [
        productId,
        productName,
        sku,
        categoryName,
        quantityInStock,
        priceSell,
        priceBuy,
        purchaseValue,
        averagePurchasePrice,
        potentialRevenue,
        potentialMargin,
        marginRate,
        lotCount,
        isFifoValued,
        lastSaleAt,
        daysSinceLastSale,
        isLowStock,
        isDeadStock,
      ];
}

/// Synthèse globale de la valorisation du stock pour une boutique.
class StockValuationSummary extends Equatable {
  const StockValuationSummary({
    required this.totalProductsCount,
    required this.totalUnitsInStock,
    required this.totalPurchaseValue,
    required this.totalPotentialRevenue,
    required this.totalPotentialMargin,
    required this.overallMarginRate,
    required this.deadStockCount,
    required this.lowStockCount,
    required this.items,
  });

  final int totalProductsCount;
  final int totalUnitsInStock;

  /// Capital immobilisé total (coût d'achat FIFO global).
  final int totalPurchaseValue;

  /// Chiffre d'affaires potentiel global.
  final int totalPotentialRevenue;

  /// Marge potentielle globale (Bénéfice brut prévisionnel).
  final int totalPotentialMargin;

  /// Taux de marge global moyen (%).
  final double overallMarginRate;

  /// Nombre de produits en stock dormant (30+ jours sans vente).
  final int deadStockCount;

  /// Nombre de produits en alerte stock faible.
  final int lowStockCount;

  final List<ProductStockValuation> items;

  @override
  List<Object?> get props => [
        totalProductsCount,
        totalUnitsInStock,
        totalPurchaseValue,
        totalPotentialRevenue,
        totalPotentialMargin,
        overallMarginRate,
        deadStockCount,
        lowStockCount,
        items,
      ];
}

/// Dynamique glissante des ventes d'un produit.
class ProductSalesVelocity extends Equatable {
  const ProductSalesVelocity({
    required this.salesToday,
    required this.revenueToday,
    required this.salesThisWeek,
    required this.revenueThisWeek,
    required this.salesThisMonth,
    required this.revenueThisMonth,
    required this.salesTotal,
    required this.revenueTotal,
  });

  final int salesToday;
  final int revenueToday;
  final int salesThisWeek;
  final int revenueThisWeek;
  final int salesThisMonth;
  final int revenueThisMonth;
  final int salesTotal;
  final int revenueTotal;

  static const empty = ProductSalesVelocity(
    salesToday: 0,
    revenueToday: 0,
    salesThisWeek: 0,
    revenueThisWeek: 0,
    salesThisMonth: 0,
    revenueThisMonth: 0,
    salesTotal: 0,
    revenueTotal: 0,
  );

  @override
  List<Object?> get props => [
        salesToday,
        revenueToday,
        salesThisWeek,
        revenueThisWeek,
        salesThisMonth,
        revenueThisMonth,
        salesTotal,
        revenueTotal,
      ];
}
