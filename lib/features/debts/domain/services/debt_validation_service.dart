import '../../../../core/errors/failures.dart';
import '../entities/debt_entities.dart';

class DebtValidationService {
  const DebtValidationService();

  static const int forgiveReasonMinLength = 10;

  void assertForgivable(Debt debt) {
    if (!debt.isRepayable) {
      throw const ConflictFailure(
        'Cette dette ne peut plus être pardonnée.',
      );
    }
  }

  void assertForgiveReason(String reason) {
    if (reason.trim().length < forgiveReasonMinLength) {
      throw ValidationFailure(
        'Le motif de pardon doit contenir au moins '
        '$forgiveReasonMinLength caractères.',
      );
    }
  }

  void assertRepayable(Debt debt) {
    if (!debt.isRepayable) {
      throw const ConflictFailure(
        'Cette dette n\'est plus remboursable.',
      );
    }
  }

  void assertPaymentAmount(int amount, int amountRemaining) {
    if (amount <= 0) {
      throw const ValidationFailure(
        'Le montant du remboursement doit être supérieur à 0 FCFA.',
      );
    }
    if (amount > amountRemaining) {
      throw ValidationFailure(
        'Le montant ne peut pas dépasser le solde restant ($amountRemaining FCFA).',
      );
    }
  }

  void assertMomoReference(DebtRepaymentMethod method, String? reference) {
    if ((method == DebtRepaymentMethod.mtnMomo ||
            method == DebtRepaymentMethod.moovMoney) &&
        (reference == null || reference.trim().length < 8)) {
      throw const ValidationFailure(
        'La référence MoMo est obligatoire (8 caractères minimum).',
      );
    }
  }

  int computeChangeGiven(
    DebtRepaymentMethod method,
    int amount,
    int? amountTendered,
  ) {
    if (method != DebtRepaymentMethod.cash || amountTendered == null) {
      return 0;
    }
    if (amountTendered < amount) {
      throw const ValidationFailure(
        'Le montant remis en espèces est insuffisant.',
      );
    }
    return amountTendered - amount;
  }

  DebtStatus resolveStatusAfterPayment(int amountRemaining) {
    return amountRemaining == 0 ? DebtStatus.paid : DebtStatus.partial;
  }

  int computeDaysWithoutPayment({
    required int createdAt,
    required int amountPaid,
    required int? lastPaymentAt,
    int? now,
  }) {
    final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
    const dayMs = 24 * 60 * 60 * 1000;
    if (amountPaid > 0 && lastPaymentAt != null) {
      return ((timestamp - lastPaymentAt) / dayMs).floor();
    }
    return ((timestamp - createdAt) / dayMs).floor();
  }
}
