import 'arike_settings_snapshot.dart';
import 'policy_decision.dart';

/// Politique métier appliquée aux ventes.
class SalesPolicy {
  const SalesPolicy(this.settings);

  final SalesSettings settings;

  PolicyDecision canSellOnCredit() {
    if (!settings.allowCredit) {
      return const PolicyDecision.deny(
        reason: 'Les ventes à crédit sont désactivées dans la configuration boutique.',
        errorCode: 'SALES_CREDIT_DISABLED',
      );
    }
    return const PolicyDecision.allow();
  }

  PolicyDecision canApplyDiscount({required double requestedPercent}) {
    if (!settings.allowDiscount && requestedPercent > 0) {
      return const PolicyDecision.deny(
        reason: 'Les remises sont désactivées sur cette boutique.',
        errorCode: 'SALES_DISCOUNT_DISABLED',
      );
    }
    if (requestedPercent > settings.maxDiscountPercent) {
      return PolicyDecision.deny(
        reason: 'La remise demandée ($requestedPercent%) dépasse le maximum autorisé (${settings.maxDiscountPercent}%).',
        errorCode: 'SALES_DISCOUNT_EXCEEDED',
      );
    }
    return const PolicyDecision.allow();
  }

  PolicyDecision canOverridePrice({required Set<String> userPermissions}) {
    if (!settings.allowPriceOverride) {
      return const PolicyDecision.deny(
        reason: 'La modification du prix unitaire est désactivée.',
        errorCode: 'SALES_PRICE_OVERRIDE_DISABLED',
      );
    }
    if (!userPermissions.contains('sales.price_override') && !userPermissions.contains('admin')) {
      return const PolicyDecision.deny(
        reason: 'Vous n\'avez pas la permission de modifier le prix unitaire.',
        errorCode: 'SALES_PRICE_OVERRIDE_FORBIDDEN',
        requiredPermission: 'sales.price_override',
      );
    }
    return const PolicyDecision.allow();
  }
}

/// Politique métier appliquée au stock.
class InventoryPolicy {
  const InventoryPolicy(this.settings);

  final InventorySettings settings;

  PolicyDecision canDecreaseStock({
    required double currentStock,
    required double requestedQuantity,
  }) {
    final remaining = currentStock - requestedQuantity;

    if (remaining < 0) {
      switch (settings.negativeStockMode) {
        case NegativeStockMode.deny:
          return PolicyDecision.deny(
            reason: 'Stock insuffisant ($currentStock dispo, $requestedQuantity demandé) et stock négatif interdit.',
            errorCode: 'INVENTORY_NEGATIVE_STOCK_DENIED',
          );
        case NegativeStockMode.warning:
          return PolicyDecision.deny(
            reason: 'Attention : le stock deviendra négatif ($remaining). Confirmation requise.',
            errorCode: 'INVENTORY_NEGATIVE_STOCK_WARNING',
          );
        case NegativeStockMode.allow:
          return const PolicyDecision.allow();
      }
    }
    return const PolicyDecision.allow();
  }
}

/// Politique métier appliquée à la caisse.
class CashPolicy {
  const CashPolicy(this.settings);

  final CashSettings settings;

  PolicyDecision canPerformCashTransaction({required bool isCashSessionOpen}) {
    if (settings.requireCashSessionOpening && !isCashSessionOpen) {
      return const PolicyDecision.deny(
        reason: 'Une session de caisse ouverte est obligatoire pour enregistrer cette opération.',
        errorCode: 'CASH_SESSION_REQUIRED',
      );
    }
    return const PolicyDecision.allow();
  }
}

/// Politique métier appliquée aux dettes et crédits clients.
class DebtPolicy {
  const DebtPolicy(this.settings);

  final DebtSettings settings;

  PolicyDecision canGrantCredit({
    required double currentCustomerDebt,
    required double newCreditAmount,
    required double? customerCreditLimit,
  }) {
    if (!settings.allowCreditSales) {
      return const PolicyDecision.deny(
        reason: 'L\'octroi de crédit client est désactivé sur cette boutique.',
        errorCode: 'DEBT_CREDIT_DISABLED',
      );
    }

    final effectiveLimit = customerCreditLimit ?? settings.defaultCreditLimit;
    if (effectiveLimit > 0) {
      final totalDebt = currentCustomerDebt + newCreditAmount;
      if (totalDebt > effectiveLimit) {
        return PolicyDecision.deny(
          reason: 'Le plafond de crédit du client ($effectiveLimit FCFA) sera dépassé ($totalDebt FCFA).',
          errorCode: 'DEBT_LIMIT_EXCEEDED',
        );
      }
    }
    return const PolicyDecision.allow();
  }
}

/// Politique métier appliquée aux commandes et livraisons.
class OrderPolicy {
  const OrderPolicy(this.settings);

  final OrderSettings settings;

  PolicyDecision canDeliverPartially() {
    if (!settings.allowPartialDelivery) {
      return const PolicyDecision.deny(
        reason: 'Les livraisons partielles sont désactivées pour cette boutique.',
        errorCode: 'ORDER_PARTIAL_DELIVERY_DISABLED',
      );
    }
    return const PolicyDecision.allow();
  }

  PolicyDecision canReplaceProduct() {
    if (!settings.allowProductReplacement) {
      return const PolicyDecision.deny(
        reason: 'Le remplacement d\'articles dans une commande n\'est pas autorisé.',
        errorCode: 'ORDER_REPLACEMENT_DISABLED',
      );
    }
    return const PolicyDecision.allow();
  }
}

/// Politique métier appliquée aux reçus.
class ReceiptPolicy {
  const ReceiptPolicy(this.settings);

  final ReceiptSettings settings;

  bool shouldAutoPrint() => settings.autoPrint;
}

/// Politique métier appliquée à la licence et l'utilisation offline.
class LicensePolicy {
  const LicensePolicy();

  PolicyDecision canOperateOffline({
    required int offlineDaysCount,
    int maxOfflineDaysAllowed = 7,
  }) {
    if (offlineDaysCount > maxOfflineDaysAllowed) {
      return PolicyDecision.deny(
        reason: 'Durée maximale hors-ligne dépassée ($offlineDaysCount jours). Veuillez synchroniser votre appareil.',
        errorCode: 'LICENSE_OFFLINE_EXPIRED',
      );
    }
    return const PolicyDecision.allow();
  }
}
