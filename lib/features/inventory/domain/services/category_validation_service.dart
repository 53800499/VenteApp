import '../../../../core/errors/failures.dart';

class CategoryValidationService {
  const CategoryValidationService();

  static const defaultCategoryName = 'Général';

  void validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      throw const ValidationFailure(
        'Le nom de la catégorie doit comporter au moins 2 caractères.',
      );
    }
  }

  void assertCanDelete(String categoryName) {
    if (categoryName == defaultCategoryName) {
      throw const ConflictFailure(
        'La catégorie « Général » ne peut pas être supprimée.',
      );
    }
  }
}
