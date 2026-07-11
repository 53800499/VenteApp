/// Intention de préremplir une vente depuis un calculateur métier.
class CalculationIntent {
  const CalculationIntent({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  /// Quantité entière pour le panier de vente (arrondi au supérieur).
  int get saleQuantity {
    final rounded = quantity.ceil();
    return rounded < 1 ? 1 : rounded;
  }
}
