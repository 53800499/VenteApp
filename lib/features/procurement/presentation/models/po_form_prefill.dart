/// Préremplissage du formulaire commande (ex. depuis alerte stock / voix).
class PoFormPrefill {
  const PoFormPrefill({
    required this.productId,
    required this.productName,
    required this.suggestedQuantity,
    this.unitCost,
    this.supplierId,
  });

  final int productId;
  final String productName;
  final int suggestedQuantity;
  final int? unitCost;
  final int? supplierId;
}
