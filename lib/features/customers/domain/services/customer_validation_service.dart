import '../../../../core/errors/failures.dart';

class CustomerValidationService {
  const CustomerValidationService();

  void assertName(String name) {
    if (name.trim().length < 2) {
      throw const ValidationFailure(
        'Le nom du client doit contenir au moins 2 caractères.',
      );
    }
  }

  void assertCanArchive(int openDebtsCount) {
    if (openDebtsCount > 0) {
      throw const ConflictFailure(
        'Impossible d\'archiver : ce client a encore des dettes ouvertes.',
      );
    }
  }

  void assertNotArchived(bool isArchived) {
    if (isArchived) {
      throw const ConflictFailure('Ce client est déjà archivé.');
    }
  }

  String? phoneWarning(String? phone) {
    final trimmed = phone?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.length < 8) {
      return 'Téléphone manquant ou incomplet — recommandé pour les rappels.';
    }
    return null;
  }
}
