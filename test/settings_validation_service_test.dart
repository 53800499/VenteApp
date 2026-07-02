import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/features/settings/domain/services/settings_validation_service.dart';

void main() {
  const validation = SettingsValidationService();

  test('rejette un nom boutique vide', () {
    expect(
      () => validation.assertShopName('  '),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('normalise le verrouillage automatique', () {
    expect(validation.normalizeAutoLockMinutes(99), 5);
    expect(validation.normalizeAutoLockMinutes(15), 15);
  });

  test('rejette un pied de reçu trop long', () {
    expect(
      () => validation.assertReceiptFooter('x' * 501),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
