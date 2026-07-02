import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/features/auth/domain/entities/setup_field.dart';
import 'package:venteapp/features/auth/domain/services/setup_validation_service.dart';

void main() {
  const service = SetupValidationService();

  test('summaryFor retourne le message unique', () {
    expect(
      service.summaryFor({
        SetupField.shopName: 'La boutique existe déjà.',
      }),
      'La boutique existe déjà.',
    );
  });

  test('summaryFor retourne un message générique pour plusieurs champs', () {
    expect(
      service.summaryFor({
        SetupField.shopName: 'Erreur boutique',
        SetupField.ownerName: 'Erreur patron',
      }),
      contains('Corrigez les champs'),
    );
  });
}
