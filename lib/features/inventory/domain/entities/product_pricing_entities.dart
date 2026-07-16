import 'package:equatable/equatable.dart';

/// Mode de calcul du prix de vente conseillé lors d'un changement de coût.
enum ProductPricingMode {
  manual,
  fixedMargin,
  percentageMargin;

  static ProductPricingMode fromDb(String raw) => switch (raw) {
        'fixed_margin' => ProductPricingMode.fixedMargin,
        'percentage_margin' => ProductPricingMode.percentageMargin,
        _ => ProductPricingMode.manual,
      };

  String toDb() => switch (this) {
        ProductPricingMode.manual => 'manual',
        ProductPricingMode.fixedMargin => 'fixed_margin',
        ProductPricingMode.percentageMargin => 'percentage_margin',
      };

  String get label => switch (this) {
        ProductPricingMode.manual => 'Prix de vente manuel',
        ProductPricingMode.fixedMargin => 'Marge fixe (FCFA)',
        ProductPricingMode.percentageMargin => 'Pourcentage de marge',
      };
}

class ProductPriceHistoryEntry extends Equatable {
  const ProductPriceHistoryEntry({
    required this.id,
    required this.shopId,
    required this.productId,
    this.unitCost,
    required this.priceSell,
    required this.reason,
    this.notes,
    required this.createdAt,
  });

  final int id;
  final int shopId;
  final int productId;
  final int? unitCost;
  final int priceSell;
  final String reason;
  final String? notes;
  final int createdAt;

  String get reasonLabel => switch (reason) {
        'creation' => 'Création',
        'procurement' => 'Approvisionnement',
        'manual' => 'Modification manuelle',
        'margin_rule' => 'Règle de marge',
        'migration' => 'Initialisation',
        _ => reason,
      };

  @override
  List<Object?> get props =>
      [id, shopId, productId, unitCost, priceSell, reason, notes, createdAt];
}

/// Produit dont le coût d'achat diffère lors d'un approvisionnement.
class ProcurementCostChange extends Equatable {
  const ProcurementCostChange({
    required this.productId,
    required this.productName,
    required this.currentPriceSell,
    required this.previousUnitCost,
    required this.newUnitCost,
    required this.pricingMode,
    this.marginValue,
  });

  final int productId;
  final String productName;
  final int currentPriceSell;
  final int previousUnitCost;
  final int newUnitCost;
  final ProductPricingMode pricingMode;
  final int? marginValue;

  double? get costChangePercent {
    if (previousUnitCost <= 0) return null;
    return ((newUnitCost - previousUnitCost) / previousUnitCost) * 100;
  }

  @override
  List<Object?> get props => [
        productId,
        productName,
        currentPriceSell,
        previousUnitCost,
        newUnitCost,
        pricingMode,
        marginValue,
      ];
}

enum ProcurementPriceDecisionType {
  keepCurrent,
  updateManual,
  applySuggested,
  decideLater,
}

class ProcurementPriceDecision extends Equatable {
  const ProcurementPriceDecision({
    required this.productId,
    required this.type,
    this.newPriceSell,
  });

  final int productId;
  final ProcurementPriceDecisionType type;
  final int? newPriceSell;

  @override
  List<Object?> get props => [productId, type, newPriceSell];
}
