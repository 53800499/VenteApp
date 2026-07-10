/// Validations et libellés utilisateur pour les formulaires calculateurs.
class CalculatorFormValidators {
  static String? requiredPositiveDouble(
    String? value, {
    required String label,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Saisissez un nombre valide pour $label.';
    }
    if (parsed <= 0) {
      return '$label doit être supérieur à 0.';
    }
    return null;
  }

  static String? requiredPositiveInt(
    String? value, {
    required String label,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Saisissez un nombre entier valide pour $label.';
    }
    if (parsed <= 0) {
      return '$label doit être supérieur à 0.';
    }
    return null;
  }

  static String? percent(String? value, {required String label}) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Saisissez un pourcentage valide pour $label.';
    }
    if (parsed < 0 || parsed > 100) {
      return '$label doit être entre 0 et 100 %.';
    }
    return null;
  }

  static double? parsePositiveDouble(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static int? parsePositiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static double? parsePercent(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 100) return null;
    return parsed;
  }
}

/// Libellés courts pour les listes déroulantes (évite les débordements UI).
class CalculatorTypeLabels {
  static const short = {
    'tile': 'Carrelage',
    'paint': 'Peinture',
    'concrete': 'Béton & mortier',
  };

  static const detailed = {
    'tile': 'Carrelage — dimensions et cartons',
    'paint': 'Peinture — rendement et fûts',
    'concrete': 'Béton & mortier — dosage ciment',
  };

  static String shortLabel(String? type) =>
      type == null ? 'Aucun' : (short[type] ?? type);

  static String detailedLabel(String type) =>
      detailed[type] ?? type;
}
