/// Grille tarifaire appliquée lors d'une vente.
enum SalePricingTier {
  retail,
  semiWholesale,
  wholesale;

  String get label => switch (this) {
        SalePricingTier.retail => 'Détail',
        SalePricingTier.semiWholesale => 'Demi-gros',
        SalePricingTier.wholesale => 'Gros',
      };
}

int catalogPriceForTier({
  required int priceSell,
  int? priceSemiWholesale,
  int? priceWholesale,
  required SalePricingTier tier,
}) {
  return switch (tier) {
    SalePricingTier.retail => priceSell,
    SalePricingTier.semiWholesale => priceSemiWholesale ?? priceSell,
    SalePricingTier.wholesale => priceWholesale ?? priceSell,
  };
}
