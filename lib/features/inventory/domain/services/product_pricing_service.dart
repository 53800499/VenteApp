import '../entities/product_pricing_entities.dart';

/// Calcul du prix de vente conseillé selon la règle de marge du produit.
class ProductPricingService {
  const ProductPricingService();

  int? calculateSuggestedSalePrice({
    required int unitCost,
    required ProductPricingMode mode,
    int? marginValue,
  }) {
    if (unitCost <= 0) return null;
    return switch (mode) {
      ProductPricingMode.manual => null,
      ProductPricingMode.fixedMargin =>
        marginValue != null ? unitCost + marginValue : null,
      ProductPricingMode.percentageMargin => marginValue != null
          ? (unitCost * (10000 + marginValue) / 10000).round()
          : null,
    };
  }

  /// Détecte les lignes d'appro dont le coût diffère du dernier coût connu.
  List<ProcurementCostChange> detectCostChanges({
    required List<ProcurementCostCheckInput> items,
  }) {
    final changes = <ProcurementCostChange>[];
    for (final item in items) {
      if (item.newUnitCost == item.referenceUnitCost) continue;
      changes.add(
        ProcurementCostChange(
          productId: item.productId,
          productName: item.productName,
          currentPriceSell: item.currentPriceSell,
          previousUnitCost: item.referenceUnitCost,
          newUnitCost: item.newUnitCost,
          pricingMode: item.pricingMode,
          marginValue: item.marginValue,
        ),
      );
    }
    return changes;
  }
}

class ProcurementCostCheckInput {
  const ProcurementCostCheckInput({
    required this.productId,
    required this.productName,
    required this.currentPriceSell,
    required this.referenceUnitCost,
    required this.newUnitCost,
    required this.pricingMode,
    this.marginValue,
  });

  final int productId;
  final String productName;
  final int currentPriceSell;
  final int referenceUnitCost;
  final int newUnitCost;
  final ProductPricingMode pricingMode;
  final int? marginValue;
}
