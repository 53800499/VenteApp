import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/features/debts/domain/entities/debt_entities.dart';
import 'package:venteapp/features/debts/domain/services/debt_validation_service.dart';

void main() {
  const service = DebtValidationService();

  const debt = Debt(
    id: 1,
    shopId: 1,
    customerId: 1,
    originalAmount: 10000,
    amountPaid: 0,
    amountRemaining: 10000,
    status: DebtStatus.open,
    createdAt: 0,
  );

  group('DebtValidationService', () {
    test('accepte un montant valide', () {
      expect(
        () => service.assertPaymentAmount(5000, debt.amountRemaining),
        returnsNormally,
      );
    });

    test('rejette un montant nul ou négatif', () {
      expect(
        () => service.assertPaymentAmount(0, debt.amountRemaining),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejette un montant supérieur au solde', () {
      expect(
        () => service.assertPaymentAmount(15000, debt.amountRemaining),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('exige une référence MoMo', () {
      expect(
        () => service.assertMomoReference(DebtRepaymentMethod.mtnMomo, null),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => service.assertMomoReference(
          DebtRepaymentMethod.mtnMomo,
          '+22990123456',
        ),
        returnsNormally,
      );
    });

    test('calcule la monnaie en espèces', () {
      expect(
        service.computeChangeGiven(
          DebtRepaymentMethod.cash,
          5000,
          10000,
        ),
        5000,
      );
      expect(
        () => service.computeChangeGiven(
          DebtRepaymentMethod.cash,
          5000,
          3000,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('résout le statut après paiement', () {
      expect(service.resolveStatusAfterPayment(0), DebtStatus.paid);
      expect(service.resolveStatusAfterPayment(2000), DebtStatus.partial);
    });

    test('exige un motif de pardon d\'au moins 10 caractères', () {
      expect(
        () => service.assertForgiveReason('court'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => service.assertForgiveReason('Motif valide pour pardon'),
        returnsNormally,
      );
    });

    test('rejette le pardon d\'une dette non remboursable', () {
      const paidDebt = Debt(
        id: 2,
        shopId: 1,
        customerId: 1,
        originalAmount: 5000,
        amountPaid: 5000,
        amountRemaining: 0,
        status: DebtStatus.paid,
        createdAt: 0,
      );
      expect(
        () => service.assertForgivable(paidDebt),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });
}
