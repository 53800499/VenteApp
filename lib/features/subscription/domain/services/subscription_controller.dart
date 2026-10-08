import 'package:flutter/foundation.dart';
import '../entities/subscription_details.dart';
import '../../../../core/licensing/domain/module_access_guard.dart';
import '../../data/services/subscription_remote_service.dart';

/// Contrôleur central de gestion de l'abonnement et du respect des modules actifs.
/// Permet à toute l'application ARIKE de réagir dynamiquement aux droits de la licence.
class SubscriptionController extends ValueNotifier<SubscriptionDetails> {
  final SubscriptionRemoteService? _remoteService;

  SubscriptionController({
    SubscriptionDetails? initialDetails,
    SubscriptionRemoteService? remoteService,
  })  : _remoteService = remoteService,
        super(initialDetails ?? _defaultDetails);

  Future<void> refreshFromRemote() async {
    if (_remoteService == null) return;
    final remoteDetails = await _remoteService.fetchMySubscription();
    if (remoteDetails != null) {
      value = remoteDetails;
    }
  }

  static final SubscriptionDetails _defaultDetails = SubscriptionDetails(
    planCode: 'ESSENTIEL',
    planName: 'ARIKE Essentiel',
    status: 'ACTIVE',
    startedAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2027, 1, 1),
    graceUntil: DateTime(2027, 1, 8),
    autoRenew: false,
    grantedModules: const [
      'Vente & Encaissement',
      'Stock avancé & Alertes rupture',
      'Dépenses & Charges de caisse',
      'Approvisionnements & Commandes clients',
      'Rapports de ventes quotidiens',
      'Mode 100% Offline',
    ],
    maxUsers: 3,
    maxShops: 1,
    currentUsersCount: 1,
    currentShopsCount: 1,
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
        return _hasAnyModule(['Stock Avancé', 'Stock avancé & Alertes rupture', 'Gestion de Stock simple', 'INVENTORY', 'INVENTORY_SIMPLE', 'INVENTORY_ADVANCED']);
      case ArikeModule.purchases:
        return _hasAnyModule(['Approvisionnement & Commandes', 'Approvisionnements & Commandes', 'Approvisionnements & Commandes clients', 'PROCUREMENT']);
      case ArikeModule.salesOrders:
        return value.isFreePlan || _hasAnyModule(['Commandes clients', 'Commandes clients & Bons de livraison', 'Commandes clients & Livraisons', 'Approvisionnements & Commandes clients', 'SALES_ORDERS', 'sales_orders', 'ALL_MODULES']);
      case ArikeModule.expenses:
        return _hasAnyModule(['Dépenses & Charges', 'Dépenses & Charges de caisse', 'EXPENSES']);
      case ArikeModule.fxExchange:
        return _hasAnyModule(['Bureau de Change FX', 'FX_EXCHANGE']);
      case ArikeModule.assistant:
        return _hasAnyModule(['Assistant Vocal ARIKE', 'ASSISTANT']);
      case ArikeModule.reports:
        return _hasAnyModule(['Statistiques & Analyses', 'Analyses & Statistiques avancées', 'Rapports de ventes quotidiens', 'REPORTS_BASIC', 'REPORTS_ADVANCED']);
      case ArikeModule.multiShop:
        return _hasAnyModule(['Transferts Inter-boutiques', 'Transferts de stock inter-boutiques', 'Multi-entreprises & Distributeurs', 'STOCK_TRANSFERS', 'MULTI_SHOP']);
      case ArikeModule.apiAccess:
        return _hasAnyModule(['Accès API dédiée & Export complet', 'MULTI_TENANT_API', 'ALL_MODULES']);
    }
  }

  bool _hasAnyModule(List<String> moduleNames) {
    if (value.grantedModules.contains('ALL_MODULES')) return true;
    return value.grantedModules.any((m) => moduleNames.contains(m));
  }

  /// Vérifie si une capacité système spécifique est accordée (ex: 'CLOUD_SYNC')
  bool isCapabilityGranted(String capability) {
    if (value.isFreePlan || !value.isActive) return false;
    if (capability == 'CLOUD_SYNC') return value.hasCloudSync;
    return value.capabilities.contains(capability);
  }

  /// Vérifie si une entité ou un module de synchronisation est autorisé pour le PULL/PUSH
  bool isModuleNameGranted(String moduleName) {
    if (!value.isActive) return false;
    final upper = moduleName.toUpperCase();
    switch (upper) {
      case 'CUSTOMERS':
      case 'CUSTOMER':
        return _hasAnyModule(['CUSTOMERS', 'CUSTOMER', 'Clients', 'ALL_MODULES']);
      case 'SALES':
      case 'SALE':
        return isModuleGranted(ArikeModule.sales);
      case 'INVENTORY':
      case 'PRODUCTS':
      case 'CATEGORIES':
      case 'INVENTORY_LOTS':
        return isModuleGranted(ArikeModule.inventory);
      case 'DEBTS':
      case 'DEBT':
        return _hasAnyModule(['DEBTS', 'DEBT', 'Dettes & Recouvrement', 'ALL_MODULES']);
      case 'EXPENSES':
      case 'EXPENSE':
        return isModuleGranted(ArikeModule.expenses);
      case 'CASH_SESSIONS':
      case 'CASH_MOVEMENTS':
      case 'CASH':
        return _hasAnyModule(['CASH_SESSIONS', 'CASH_MOVEMENTS', 'CASH', 'ALL_MODULES']);
      case 'CALCULATORS':
      case 'CALCULATOR_PRODUCT_DATA':
      case 'CALCULATOR_HISTORY':
        return _hasAnyModule(['CALCULATORS', 'SALES', 'ALL_MODULES']);
      case 'PROCUREMENT':
      case 'SUPPLIERS':
      case 'PURCHASE_ORDERS':
      case 'PURCHASE_RECEIPTS':
      case 'SUPPLIER_INVOICES':
      case 'SUPPLIER_PAYMENTS':
        return isModuleGranted(ArikeModule.purchases);
      case 'SALES_ORDERS':
      case 'SALES_ORDER':
        return value.isFreePlan || _hasAnyModule(['SALES_ORDERS', 'sales_orders', 'Approvisionnements & Commandes clients', 'Commandes clients', 'ALL_MODULES']);
      case 'STOCK_TRANSFERS':
      case 'STOCK_TRANSFER':
        return isModuleGranted(ArikeModule.multiShop);
      case 'FX_EXCHANGE':
      case 'FX_SESSIONS':
      case 'FX_OPERATIONS':
      case 'FX_MOVEMENTS':
      case 'FX_RATE_SNAPSHOTS':
      case 'FX_SHOP_CURRENCIES':
        return isModuleGranted(ArikeModule.fxExchange);
      default:
        return true;
    }
  }

  /// Indique le nom du forfait minimum requis pour débloquer un module
  String getRequiredPlanForModule(ArikeModule module) {
    switch (module) {
      case ArikeModule.salesOrders:
        return 'Gratuit';
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
