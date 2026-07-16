/// Préremplissage du formulaire commande (ex. depuis alerte stock).
class PoFormPrefill {
  const PoFormPrefill({
    required this.productId,
    required this.productName,
    required this.suggestedQuantity,
    this.unitCost,
  });

  final int productId;
  final String productName;
  final int suggestedQuantity;
  final int? unitCost;
}
