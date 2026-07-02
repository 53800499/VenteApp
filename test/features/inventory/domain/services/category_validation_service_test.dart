import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/features/inventory/domain/services/category_validation_service.dart';

void main() {
  const service = CategoryValidationService();

  test('rejette un nom trop court', () {
    expect(() => service.validateName('a'), throwsA(isA<ValidationFailure>()));
  });

  test('protège la catégorie Général', () {
    expect(
      () => service.assertCanDelete(CategoryValidationService.defaultCategoryName),
      throwsA(isA<ConflictFailure>()),
    );
  });
}
