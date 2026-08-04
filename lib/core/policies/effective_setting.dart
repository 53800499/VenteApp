/// Source d'origine d'un paramètre dans l'arbre d'arbitrage ARIKE.
enum SettingSource {
  /// Décision administrative ARIKE imposée et verrouillée.
  adminPolicy(1),

  /// Politique globale définie au niveau de l'organisation.
  orgSetting(2),

  /// Réglage spécifique à la boutique active.
  shopSetting(3),

  /// Préférence personnelle de l'utilisateur ou de l'appareil.
  userPreference(4),

  /// Valeur par défaut intégrée dans l'application mobile.
  appDefault(5);

  const SettingSource(this.priority);

  /// Niveau de priorité (1 = le plus prioritaire).
  final int priority;
}

/// Représente un paramètre résolu avec sa valeur finale, sa provenance
/// et son état de verrouillage pour l'interface utilisateur.
class EffectiveSetting<T> {
  const EffectiveSetting({
    required this.value,
    required this.source,
    this.isLocked = false,
    this.lockReason,
    this.policyCode,
  });

  /// Création d'un paramètre résolu à partir de la valeur par défaut de l'application.
  factory EffectiveSetting.appDefault(T defaultValue) {
    return EffectiveSetting<T>(
      value: defaultValue,
      source: SettingSource.appDefault,
      isLocked: false,
    );
  }

  /// Création d'un paramètre résolu à partir d'un paramètre boutique.
  factory EffectiveSetting.shop(T shopValue) {
    return EffectiveSetting<T>(
      value: shopValue,
      source: SettingSource.shopSetting,
      isLocked: false,
    );
  }

  /// Création d'un paramètre résolu à partir d'une politique administrative verrouillée.
  factory EffectiveSetting.adminLocked({
    required T value,
    required String policyCode,
    required String lockReason,
  }) {
    return EffectiveSetting<T>(
      value: value,
      source: SettingSource.adminPolicy,
      isLocked: true,
      lockReason: lockReason,
      policyCode: policyCode,
    );
  }

  /// La valeur finale à appliquer.
  final T value;

  /// La source d'origine ayant fourni la valeur.
  final SettingSource source;

  /// Indique si ce réglage est verrouillé par une politique administrative.
  /// Si `true`, l'interface utilisateur doit désactiver le composant de saisie.
  final bool isLocked;

  /// Le motif d'explication du verrouillage (affiché sous forme de tooltip ou de sous-titre dans l'UI).
  final String? lockReason;

  /// Le code de la politique administrative ayant imposé ce réglage (ex: `MAX_DISCOUNT_CAP`).
  final String? policyCode;

  Map<String, dynamic> toJson(Object? Function(T value) valueToJson) => {
        'value': valueToJson(value),
        'source': source.name,
        'isLocked': isLocked,
        'lockReason': lockReason,
        'policyCode': policyCode,
      };

  @override
  String toString() {
    return 'EffectiveSetting<$T>(value: $value, source: ${source.name}, isLocked: $isLocked, lockReason: $lockReason)';
  }
}
