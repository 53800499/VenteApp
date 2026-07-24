import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/features/sales/domain/entities/sale_entities.dart';

void main() {
  group('saleItemQuantityReturnable', () {
    test('reste = vendu − déjà retourné', () {
      expect(
        saleItemQuantityReturnable(soldQuantity: 10, alreadyReturned: 3),
        7,
      );
    });

    test('reste ne descend pas sous 0', () {
      expect(
        saleItemQuantityReturnable(soldQuantity: 5, alreadyReturned: 8),
        0,
      );
    });

    test('rien retourné → tout retournable', () {
      expect(
        saleItemQuantityReturnable(soldQuantity: 20, alreadyReturned: 0),
        20,
      );
    });

    test('tout retourné → 0', () {
      expect(
        saleItemQuantityReturnable(soldQuantity: 4, alreadyReturned: 4),
        0,
      );
    });
  });
}
