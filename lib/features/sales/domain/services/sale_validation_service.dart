import '../../../../core/errors/failures.dart';
import '../entities/sale_entities.dart';

class ComputedSaleTotals {
  const ComputedSaleTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountCash,
    required this.amountMomo,
    required this.amountCredit,
  });

  final int subtotal;
  final int discountAmount;
  final int totalAmount;
  final int amountPaid;
  final int amountCash;
  final int amountMomo;
  final int amountCredit;
}

const cancelWindowMs = 24 * 60 * 60 * 1000;

class SaleValidationService {
  const SaleValidationService();

  void assertStandardCart(List<SaleLineDraft> lines) {
    if (lines.isEmpty) {
      throw const ValidationFailure('Le panier est vide.');
    }
    for (final line in lines) {
      if (line.quantity <= 0) {
        throw const ValidationFailure(
          'La quantité de chaque produit doit être supérieure à 0.',
        );
      }
      if (line.unitPrice <= 0) {
        throw const ValidationFailure(
          'Le prix unitaire doit être supérieur à 0.',
        );
      }
      if (line.lineDiscountAmount < 0) {
        throw const ValidationFailure(
          'La remise ligne ne peut pas être négative.',
        );
      }
    }
  }

  int computeLineTotal(SaleLineDraft line) {
    final gross = (line.quantity * line.unitPrice).round();
    return (gross - line.lineDiscountAmount).clamp(0, gross);
  }

  ComputedSaleTotals computeTotals(
    List<SaleLineDraft> lines,
    int globalDiscountAmount,
    PaymentDraft payment,
  ) {
    final subtotal =
        lines.fold<int>(0, (sum, line) => sum + computeLineTotal(line));
    final discountAmount = globalDiscountAmount < 0 ? 0 : globalDiscountAmount;
    if (discountAmount > subtotal) {
      throw const ValidationFailure(
        'La remise ne peut pas dépasser le sous-total.',
      );
    }
    final totalAmount = subtotal - discountAmount;
    final resolved = _resolvePayment(totalAmount, payment);
    return ComputedSaleTotals(
      subtotal: subtotal,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      amountPaid: resolved.amountPaid,
      amountCash: resolved.amountCash,
      amountMomo: resolved.amountMomo,
      amountCredit: resolved.amountCredit,
    );
  }

  ComputedSaleTotals computeQuickTotals(int totalAmount, PaymentDraft payment) {
    if (totalAmount <= 0) {
      throw const ValidationFailure(
        'Le montant doit être supérieur à 0 FCFA.',
      );
    }
    if (payment.amountCredit > 0) {
      throw const ValidationFailure(
        'Le crédit n\'est pas autorisé pour une vente rapide.',
      );
    }
    final resolved = _resolvePayment(
      totalAmount,
      PaymentDraft(
        method: payment.method,
        amountCash: payment.amountCash,
        amountMomo: payment.amountMomo,
      ),
    );
    return ComputedSaleTotals(
      subtotal: totalAmount,
      discountAmount: 0,
      totalAmount: totalAmount,
      amountPaid: resolved.amountPaid,
      amountCash: resolved.amountCash,
      amountMomo: resolved.amountMomo,
      amountCredit: 0,
    );
  }

  void assertCustomerForCredit(int? customerId, int amountCredit) {
    if (amountCredit > 0 && customerId == null) {
      throw const ValidationFailure(
        'Un client est requis pour une vente à crédit.',
      );
    }
  }

  void assertStockAvailable(
    String productName,
    int available,
    int requested,
  ) {
    if (requested > available) {
      throw ValidationFailure(
        'Stock insuffisant pour « $productName » (disponible : $available).',
      );
    }
  }

  void assertCancelWindow(int createdAt, int now) {
    if (now - createdAt > cancelWindowMs) {
      throw const ValidationFailure(
        'L\'annulation n\'est possible que dans les 24 h suivant la vente.',
      );
    }
  }

  void assertCancelReason(String reason) {
    if (reason.trim().length < 5) {
      throw const ValidationFailure(
        'Le motif d\'annulation doit contenir au moins 5 caractères.',
      );
    }
  }

  void assertConvertibleQuickSale(Sale sale) {
    if (sale.saleType != SaleType.quick) {
      throw const ValidationFailure(
        'Seules les ventes rapides peuvent être converties.',
      );
    }
    if (sale.isCancelled) {
      throw const ValidationFailure(
        'Impossible de convertir une vente annulée.',
      );
    }
    if (sale.items.isNotEmpty) {
      throw const ValidationFailure(
        'Cette vente contient déjà des articles détaillés.',
      );
    }
  }

  void assertConversionTotalsMatch({
    required ComputedSaleTotals totals,
    required int quickSaleTotal,
  }) {
    if (totals.totalAmount != quickSaleTotal) {
      throw ValidationFailure(
        'Le total des articles (${totals.totalAmount} FCFA) doit être égal '
        'au montant de la vente rapide ($quickSaleTotal FCFA).',
      );
    }
  }

  ComputedSaleTotals _resolvePayment(int totalAmount, PaymentDraft payment) {
    final amountCash = payment.amountCash < 0 ? 0 : payment.amountCash;
    final amountMomo = payment.amountMomo < 0 ? 0 : payment.amountMomo;
    final amountCredit = payment.amountCredit < 0 ? 0 : payment.amountCredit;
    final amountPaid = amountCash + amountMomo;

    if (amountPaid + amountCredit != totalAmount) {
      throw const ValidationFailure(
        'La somme encaissée (espèces + Mobile Money) + crédit doit être égale au total.',
      );
    }

    if (payment.method == PaymentMethod.credit && amountCredit != totalAmount) {
      throw const ValidationFailure(
        'Paiement crédit : le montant crédit doit couvrir le total.',
      );
    }

    if (payment.method != PaymentMethod.credit &&
        payment.method != PaymentMethod.mixed &&
        amountCredit > 0) {
      throw const ValidationFailure(
        'Crédit non autorisé avec ce mode de paiement.',
      );
    }

    return ComputedSaleTotals(
      subtotal: 0,
      discountAmount: 0,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      amountCash: amountCash,
      amountMomo: amountMomo,
      amountCredit: amountCredit,
    );
  }
}
