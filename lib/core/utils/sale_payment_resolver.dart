/// Répartit le montant encaissé d'une vente (espèces / MoMo / crédit).
///
/// Les ventes synchronisées depuis le cloud sans détail de paiement ont souvent
/// `amountCash`/`amountMomo`/`amountCredit` à 0 : on déduit alors depuis
/// [paymentMethod] et [totalAmount].
class SalePaymentResolver {
  const SalePaymentResolver._();

  static ({int cash, int momo, int credit}) resolve({
    required int totalAmount,
    required int amountCash,
    required int amountMomo,
    required int amountCredit,
    String? paymentMethod,
  }) {
    if (amountCash + amountMomo + amountCredit > 0) {
      return (cash: amountCash, momo: amountMomo, credit: amountCredit);
    }
    if (totalAmount <= 0) {
      return (cash: 0, momo: 0, credit: 0);
    }

    return switch (paymentMethod) {
      'mtn_momo' || 'moov_money' => (
          cash: 0,
          momo: totalAmount,
          credit: 0,
        ),
      'credit' => (cash: 0, momo: 0, credit: totalAmount),
      'mixed' => (cash: totalAmount, momo: 0, credit: 0),
      _ => (cash: totalAmount, momo: 0, credit: 0),
    };
  }
}
