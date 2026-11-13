import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entities/subscription_details.dart';
import '../../../../core/licensing/domain/module_access_guard.dart';
import '../../data/services/subscription_remote_service.dart';

/// Contrôleur central de gestion de l'abonnement et du respect des modules actifs.
/// Permet à toute l'application ARIKE de réagir dynamiquement aux droits de la licence.
class SubscriptionController extends ValueNotifier<SubscriptionDetails> {
  static const _cacheKey = 'cached_subscription_details';
  final SubscriptionRemoteService? _remoteService;
  final SharedPreferences? _prefs;

  SubscriptionController({
    SubscriptionDetails? initialDetails,
    SubscriptionRemoteService? remoteService,
    SharedPreferences? prefs,
  })  : _remoteService = remoteService,
        _prefs = prefs,
        super(initialDetails ?? _resolveInitialDetails(prefs)) {
    // Si des détails avaient été sauvegardés précédemment en local, ils sont déjà actifs
  }

  static SubscriptionDetails _resolveInitialDetails(SharedPreferences? prefs) {
    if (prefs != null) {
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          return SubscriptionDetails.fromJson(map);
        } catch (_) {}
      }
    }
    return _defaultDetails;
  }

  Future<void> refreshFromRemote() async {
    if (_remoteService == null) return;
    try {
      final remoteDetails = await _remoteService.fetchMySubscription();
      if (remoteDetails != null) {
        value = remoteDetails;
        if (_prefs != null) {
          try {
            await _prefs.setString(_cacheKey, jsonEncode(remoteDetails.toJson()));
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static final SubscriptionDetails _defaultDetails = SubscriptionDetails(
    planCode: 'FREE',
    planName: 'ARIKE Gratuit',
    status: 'ACTIVE',
    startedAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2036, 1, 1),
    graceUntil: DateTime(2036, 1, 8),
    autoRenew: false,
    grantedModules: const [
      'SALES',
      'INVENTORY',
      'CUSTOMERS',
      'DEBTS',
    ],
    capabilities: const [],
    maxUsers: 1,
    maxShops: 1,
    currentUsersCount: 1,
    currentShopsCount: 1,
    paymentHistory: const [],
  );

  SubscriptionDetails get details => value;

  void updateSubscription(SubscriptionDetails newDetails) {
    value = newDetails;
    if (_prefs != null) {
      try {
        _prefs.setString(_cacheKey, jsonEncode(newDetails.toJson()));
      } catch (_) {}
    }
  }

  /// Vérifie si un module spécifique est débloqué selon les droits de l'abonnement actif.
  bool isModuleGranted(ArikeModule module) {
    if (!value.isActive) return false;

    // Déblocage complet du système si ALL_MODULES ou forfait entreprise
    if (value.grantedModules.contains('ALL_MODULES') ||
        value.planCode.toUpperCase() == 'ENTERPRISE') {
      return true;
    }

    switch (module) {
      case ArikeModule.sales:
        return _hasAnyModule(['Vente & Encaissement', 'SALES', 'ALL_MODULES']);
      case ArikeModule.inventory:
        return _hasAnyModule(['Stock Avancé', 'Stock avancé & Alertes rupture', 'Gestion de Stock simple', 'INVENTORY', 'INVENTORY_SIMPLE', 'INVENTORY_ADVANCED', 'ALL_MODULES']);
      case ArikeModule.purchases:
        return _hasAnyModule(['Approvisionnement & Commandes', 'Approvisionnements & Commandes', 'Approvisionnements & Commandes clients', 'PROCUREMENT', 'ALL_MODULES']);
      case ArikeModule.salesOrders:
        return _hasAnyModule(['Commandes clients', 'Commandes clients & Bons de livraison', 'Commandes clients & Livraisons', 'Approvisionnements & Commandes clients', 'SALES_ORDERS', 'sales_orders', 'ALL_MODULES']);
      case ArikeModule.expenses:
        return _hasAnyModule(['Dépenses & Charges', 'Dépenses & Charges de caisse', 'EXPENSES', 'ALL_MODULES']);
      case ArikeModule.fxExchange:
        return _hasAnyModule(['Bureau de Change FX', 'FX_EXCHANGE', 'ALL_MODULES']);
      case ArikeModule.assistant:
        return _hasAnyModule(['Assistant Vocal ARIKE', 'ASSISTANT', 'ALL_MODULES']);
      case ArikeModule.reports:
        return _hasAnyModule(['Statistiques & Analyses', 'Analyses & Statistiques avancées', 'Rapports de ventes quotidiens', 'REPORTS_BASIC', 'REPORTS_ADVANCED', 'ALL_MODULES']);
      case ArikeModule.multiShop:
        return _hasAnyModule(['Transferts Inter-boutiques', 'Transferts de stock inter-boutiques', 'Multi-entreprises & Distributeurs', 'STOCK_TRANSFERS', 'MULTI_SHOP', 'ALL_MODULES']);
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
    if (value.grantedModules.contains('ALL_MODULES')) return true;
    if (value.isFreePlan || !value.isActive) return false;
    if (capability == 'CLOUD_SYNC') return value.hasCloudSync;
    return value.capabilities.contains(capability);
  }

  /// Vérifie si une entité ou un module de synchronisation est autorisé pour le PULL/PUSH
  bool isModuleNameGranted(String moduleName) {
    if (!value.isActive) return false;
    if (value.grantedModules.contains('ALL_MODULES')) return true;
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
