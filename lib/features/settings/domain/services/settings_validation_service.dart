import '../../../../core/errors/failures.dart';
import '../entities/settings_entities.dart';

class SettingsValidationService {
  const SettingsValidationService();

  static const receiptFooterMaxLength = 500;
  static const autoLockMin = 1;
  static const autoLockMax = 120;

  void assertShopName(String? name) {
    if (name == null || name.trim().isEmpty) {
      throw const ValidationFailure('Le nom de la boutique est obligatoire.');
    }
  }

  void assertAutoLockMinutes(int minutes) {
    if (!autoLockMinuteOptions.contains(minutes)) {
      throw ValidationFailure(
        'Délai de verrouillage invalide ($autoLockMin–$autoLockMax min).',
      );
    }
  }

  void assertDefaultAlertThreshold(int threshold) {
    if (threshold < 0) {
      throw const ValidationFailure('Le seuil d\'alerte doit être positif.');
    }
  }

  void assertReceiptFooter(String? footer) {
    if (footer != null && footer.length > receiptFooterMaxLength) {
      throw ValidationFailure(
        'Le pied de reçu ne peut pas dépasser $receiptFooterMaxLength caractères.',
      );
    }
  }

  int normalizeAutoLockMinutes(int minutes) {
    return autoLockMinuteOptions.contains(minutes) ? minutes : 5;
  }
}
