import 'package:flutter/foundation.dart';
import '../entities/subscription_details.dart';
import '../../../../core/licensing/domain/module_access_guard.dart';

/// Contrôleur central de gestion de l'abonnement et du respect des modules actifs.
/// Permet à toute l'application ARIKE de réagir dynamiquement aux droits de la licence.
class SubscriptionController extends ValueNotifier<SubscriptionDetails> {
  SubscriptionController({SubscriptionDetails? initialDetails})
      : super(initialDetails ?? _defaultDetails);

  static final SubscriptionDetails _defaultDetails = SubscriptionDetails(
    planCode: 'PRO',
    planName: '⭐ ARIKE Pro',
    status: 'ACTIVE',
    startedAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2027, 1, 1),
    graceUntil: DateTime(2027, 1, 8),
    autoRenew: false,
    grantedModules: const [
      'Vente & Encaissement',
      'Stock Avancé',
      'Dépenses & Charges',
      'Approvisionnements & Commandes',
      'Bureau de Change FX',
      'Assistant Vocal ARIKE',
      'Transferts de stock inter-boutiques',
      'Statistiques & Analyses',
    ],
    maxUsers: 10,
    maxShops: 5,
    currentUsersCount: 3,
    currentShopsCount: 2,
    paymentHistory: const [],
  );

  SubscriptionDetails get details => value;

  void updateSubscription(SubscriptionDetails newDetails) {
    value = newDetails;
  }

  /// Vérifie si un module spécifique est débloqué selon les droits de l'abonnement actif.
  bool isModuleGranted(ArikeModule module) {
    if (!value.isActive) return false;

    switch (module) {
      case ArikeModule.sales:
        return _hasAnyModule(['Vente & Encaissement', 'SALES']);
      case ArikeModule.inventory:
        return _hasAnyModule(['Stock Avancé', 'Stock avancé & Alertes rupture', 'Gestion de Stock simple', 'INVENTORY_SIMPLE', 'INVENTORY_ADVANCED']);
      case ArikeModule.purchases:
        return _hasAnyModule(['Approvisionnement & Commandes', 'Approvisionnements & Commandes', 'Approvisionnements & Commandes clients', 'PROCUREMENT', 'SALES_ORDERS']);
      case ArikeModule.expenses:
        return _hasAnyModule(['Dépenses & Charges', 'Dépenses & Charges de caisse', 'EXPENSES']);
      case ArikeModule.fxExchange:
        return _hasAnyModule(['Bureau de Change FX', 'FX_EXCHANGE']);
      case ArikeModule.assistant:
        return _hasAnyModule(['Assistant Vocal ARIKE', 'ASSISTANT']);
      case ArikeModule.reports:
        return _hasAnyModule(['Statistiques & Analyses', 'Analyses & Statistiques avancées', 'Rapports de ventes quotidiens', 'REPORTS_ADVANCED']);
      case ArikeModule.multiShop:
        return _hasAnyModule(['Transferts Inter-boutiques', 'Transferts de stock inter-boutiques', 'Multi-entreprises & Distributeurs', 'STOCK_TRANSFER']);
      case ArikeModule.apiAccess:
        return _hasAnyModule(['Accès API dédiée & Export complet', 'MULTI_TENANT_API']);
    }
  }

  bool _hasAnyModule(List<String> moduleNames) {
    return value.grantedModules.any((m) => moduleNames.contains(m));
  }

  /// Indique le nom du forfait minimum requis pour débloquer un module
  String getRequiredPlanForModule(ArikeModule module) {
    switch (module) {
      case ArikeModule.expenses:
      case ArikeModule.purchases:
        return 'ARIKE Essentiel';
      case ArikeModule.fxExchange:
      case ArikeModule.assistant:
      case ArikeModule.multiShop:
      case ArikeModule.reports:
        return 'ARIKE Pro';
      case ArikeModule.apiAccess:
        return 'ARIKE Business';
      default:
        return 'ARIKE Essentiel';
    }
  }
}
