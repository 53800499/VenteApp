import '../entities/setup_field.dart';

/// Messages agrégés pour les erreurs par champ à l'installation.
class SetupValidationService {  const SetupValidationService();

  String? summaryFor(Map<SetupField, String> fieldErrors) {
    if (fieldErrors.isEmpty) return null;
    if (fieldErrors.length == 1) {
      return fieldErrors.values.first;
    }
    return 'Corrigez les champs signalés ci-dessous avant de continuer.';
  }
}
