import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/utils/sale_payment_resolver.dart';

void main() {
  group('SalePaymentResolver', () {
    test('utilise les montants explicites quand présents', () {
      final r = SalePaymentResolver.resolve(
        totalAmount: 5000,
        amountCash: 2000,
        amountMomo: 3000,
        amountCredit: 0,
        paymentMethod: 'mixed',
      );
      expect(r.cash, 2000);
      expect(r.momo, 3000);
      expect(r.credit, 0);
    });

    test('déduit depuis paymentMethod si montants absents', () {
      final cash = SalePaymentResolver.resolve(
        totalAmount: 4500,
        amountCash: 0,
        amountMomo: 0,
        amountCredit: 0,
        paymentMethod: 'cash',
      );
      expect(cash.cash, 4500);

      final momo = SalePaymentResolver.resolve(
        totalAmount: 4500,
        amountCash: 0,
        amountMomo: 0,
        amountCredit: 0,
        paymentMethod: 'mtn_momo',
      );
      expect(momo.momo, 4500);
    });
  });
}
