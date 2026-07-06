abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Tailles UI normalisées — icônes, tuiles, illustrations, contrôles.
abstract final class AppSizes {
  /// Icône dans badge ou texte inline.
  static const iconSm = 18.0;

  /// Icône dans avatar de liste (Plus, Aide, paramètres).
  static const iconMd = 22.0;

  /// Icône d'action / chevron.
  static const iconLg = 24.0;

  /// Avatar rond des tuiles module (diamètre).
  static const leadingAvatar = 40.0;
  static const leadingRadius = leadingAvatar / 2;

  /// Illustration vide / placeholder.
  static const illustration = 64.0;

  /// Hauteur minimale d'une tuile module.
  static const listTileMinHeight = 72.0;

  /// Rangée horizontale de filtres (chips).
  static const filterChipRowHeight = 40.0;

  /// Marge verticale des états vides scrollables.
  static const emptyStatePadding = 96.0;

  /// Hauteur des boutons principaux et champs.
  static const controlHeight = 52.0;

  /// Interligne corps de texte.
  static const lineHeightBody = 1.45;

  /// Interligne compacte (sous-titres de tuiles).
  static const lineHeightTight = 1.35;
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}
