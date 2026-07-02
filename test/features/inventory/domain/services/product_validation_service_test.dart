import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/features/inventory/domain/entities/inventory_entities.dart';
import 'package:venteapp/features/inventory/domain/services/product_validation_service.dart';

void main() {
  const service = ProductValidationService();

  group('ProductValidationService', () {
    test('rejette un nom trop court (RG-INV-01)', () {
      expect(
        () => service.validateName('a'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('accepte un prix de vente valide (RG-INV-02)', () {
      expect(() => service.validatePrices(priceSell: 500), returnsNormally);
    });

    test('rejette prix achat >= prix vente (RG-INV-03)', () {
      expect(
        () => service.validatePrices(priceSell: 500, priceBuy: 600),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejette un stock négatif après ajustement (RG-INV-11)', () {
      expect(
        () => service.validateStockAdjustment(
          type: StockAdjustmentType.loss,
          currentStock: 2,
          quantityChange: -5,
          reason: 'casse magasin',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('exige un motif pour une perte (RG-INV-10)', () {
      expect(
        () => service.validateStockAdjustment(
          type: StockAdjustmentType.loss,
          currentStock: 10,
          quantityChange: -1,
          reason: 'ab',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
