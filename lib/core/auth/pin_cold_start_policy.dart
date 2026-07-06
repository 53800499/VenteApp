/// Politique de demande du PIN au démarrage à froid de l'application.
enum PinColdStartPolicy {
  /// PIN obligatoire à chaque ouverture (défaut).
  always('always', 'Toujours demander le PIN'),

  /// Pas de PIN si déverrouillé dans les 8 dernières heures.
  remember8Hours('remember_8h', 'Se souvenir de moi 8 heures'),

  /// Pas de PIN si déjà déverrouillé aujourd'hui (fuseau Bénin).
  rememberToday('remember_today', 'Se souvenir de moi aujourd\'hui');

  const PinColdStartPolicy(this.code, this.label);

  final String code;
  final String label;

  static PinColdStartPolicy fromCode(String? code) {
    return PinColdStartPolicy.values.firstWhere(
      (policy) => policy.code == code,
      orElse: () => PinColdStartPolicy.always,
    );
  }
}
