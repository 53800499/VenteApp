import 'admin_policy.dart';
import 'app_preferences.dart';
import 'arike_settings_snapshot.dart';
import 'effective_setting.dart';

/// Moteur d'arbitrage centralisé ARIKE calculant la configuration effective finale
/// en fusionnant les 5 couches de paramètres selon l'ordre de priorité strict :
///
/// 1. Décision administrative ARIKE (AdminPolicies - Priorité 1, Verrouillé)
/// 2. Politique de l’organisation (Org BusinessSettings - Priorité 2)
/// 3. Paramètre spécifique de la boutique (Shop BusinessSettings - Priorité 3)
/// 4. Préférence utilisateur local (AppPreferences - Priorité 4)
/// 5. Valeur par défaut de l’application (AppDefaults - Priorité 5)
class EffectiveSettingsResolver {
  EffectiveSettingsResolver({
    required this.preferences,
    required this.baseSnapshot,
    this.adminPolicies = const [],
    this.featureFlags = const {},
  }) : _policyMap = {for (final p in adminPolicies) p.code: p};

  final AppPreferences preferences;
  final ArikeSettingsSnapshot baseSnapshot;
  final List<AdminPolicy> adminPolicies;
  final Map<String, bool> featureFlags;

  final Map<String, AdminPolicy> _policyMap;

  // ===========================================================================
  // 1. STATUT ET POLITIQUES GLOBALES TENANT / PLATEFORME
  // ===========================================================================

  /// Statut d'activation du tenant / de l'organisation.
  EffectiveSetting<bool> get isTenantActive {
    final policy = _policyMap[AdminPolicy.tenantStatus];
    if (policy != null && policy.enforced) {
      final isActive = (policy.value as String?)?.toUpperCase() == 'ACTIVE';
      return EffectiveSetting.adminLocked(
        value: isActive,
        policyCode: AdminPolicy.tenantStatus,
        lockReason: policy.lockReason ?? 'Statut du compte contrôlé par l\'administration ARIKE.',
      );
    }
    return EffectiveSetting.shop(true);
  }

  /// Mode lecture seule imposé à la boutique.
  EffectiveSetting<bool> get isForceReadonly {
    final policy = _policyMap[AdminPolicy.forceReadonly];
    if (policy != null && policy.enforced) {
      return EffectiveSetting.adminLocked(
        value: policy.value as bool? ?? true,
        policyCode: AdminPolicy.forceReadonly,
        lockReason: policy.lockReason ?? 'Accès en lecture seule imposé par l\'administration ARIKE.',
      );
    }
    return EffectiveSetting.shop(false);
  }

  // ===========================================================================
  // 2. PARAMÈTRES VENTES & REMISES
  // ===========================================================================

  /// Plafond maximal de remise autorisé (en %).
  EffectiveSetting<double> get maxDiscountPercent {
    final policy = _policyMap[AdminPolicy.maxDiscountCap];
    final shopVal = baseSnapshot.sales.maxDiscountPercent;

    if (policy != null && policy.enforced) {
      final cap = (policy.value as num).toDouble();
      // Si la boutique avait un plafond inférieur au cap admin, la boutique prime
      final effectiveVal = shopVal < cap ? shopVal : cap;
      final isLocked = shopVal > cap;

      return EffectiveSetting<double>(
        value: effectiveVal,
        source: isLocked ? SettingSource.adminPolicy : SettingSource.shopSetting,
        isLocked: isLocked,
        lockReason: isLocked
            ? (policy.lockReason ?? 'Remise maximale plafonnée à $cap% par la politique ARIKE.')
            : null,
        policyCode: isLocked ? AdminPolicy.maxDiscountCap : null,
      );
    }

    return EffectiveSetting.shop(shopVal);
  }

  /// Autorisation de vente à crédit.
  EffectiveSetting<bool> get allowCreditSales {
    final policy = _policyMap[AdminPolicy.creditSalesOverride];
    if (policy != null && policy.enforced) {
      return EffectiveSetting.adminLocked(
        value: policy.value as bool? ?? false,
        policyCode: AdminPolicy.creditSalesOverride,
        lockReason: policy.lockReason ?? 'Octroi de crédit désactivé par l\'administration ARIKE.',
      );
    }
    return EffectiveSetting.shop(baseSnapshot.sales.allowCredit && baseSnapshot.debts.allowCreditSales);
  }

  // ===========================================================================
  // 3. PARAMÈTRES STOCK & INVENTAIRE
  // ===========================================================================

  /// Règle de gestion du stock négatif.
  EffectiveSetting<NegativeStockMode> get negativeStockMode {
    final policy = _policyMap[AdminPolicy.negativeStockOverride];
    if (policy != null && policy.enforced) {
      final modeStr = policy.value as String?;
      final mode = NegativeStockMode.fromString(modeStr);
      return EffectiveSetting.adminLocked(
        value: mode,
        policyCode: AdminPolicy.negativeStockOverride,
        lockReason: policy.lockReason ?? 'Gestion du stock négatif imposée par ARIKE.',
      );
    }
    return EffectiveSetting.shop(baseSnapshot.inventory.negativeStockMode);
  }

  // ===========================================================================
  // 4. PREFERENCES LOCALES UTILISATEUR / APPAREIL
  // ===========================================================================

  /// Thème visuel de l'application.
  EffectiveSetting<String> get themeMode => EffectiveSetting(
        value: preferences.themeMode,
        source: SettingSource.userPreference,
        isLocked: false,
      );

  /// Langue de l'interface.
  EffectiveSetting<String> get language => EffectiveSetting(
        value: preferences.language,
        source: SettingSource.userPreference,
        isLocked: false,
      );

  // ===========================================================================
  // CONSTRUCTEUR DU SNAPSHOT EFFECTIF POUR LE POLICY ENGINE
  // ===========================================================================

  /// Génère un [ArikeSettingsSnapshot] résolu combinant toutes les politiques actives.
  ArikeSettingsSnapshot resolveToSnapshot({int? overrideVersion}) {
    final resolvedSales = SalesSettings(
      allowCredit: allowCreditSales.value,
      allowDiscount: baseSnapshot.sales.allowDiscount && maxDiscountPercent.value > 0,
      maxDiscountPercent: maxDiscountPercent.value,
      allowPriceOverride: baseSnapshot.sales.allowPriceOverride && !isForceReadonly.value,
      requireSaleConfirmation: baseSnapshot.sales.requireSaleConfirmation,
      allowMinimumPriceBypass: baseSnapshot.sales.allowMinimumPriceBypass && !isForceReadonly.value,
    );

    final resolvedInventory = InventorySettings(
      negativeStockMode: negativeStockMode.value,
      defaultAlertThreshold: baseSnapshot.inventory.defaultAlertThreshold,
      trackLots: baseSnapshot.inventory.trackLots,
    );

    final resolvedDebts = DebtSettings(
      allowCreditSales: allowCreditSales.value,
      defaultCreditLimit: baseSnapshot.debts.defaultCreditLimit,
      maxOverdueDays: baseSnapshot.debts.maxOverdueDays,
    );

    final resolvedSecurity = SecuritySettings(
      autoLockMinutes: (preferences.autoLockSeconds / 60).round(),
      requireBiometrics: preferences.useBiometrics,
    );

    return ArikeSettingsSnapshot(
      version: overrideVersion ?? baseSnapshot.version,
      company: baseSnapshot.company,
      sales: resolvedSales,
      inventory: resolvedInventory,
      orders: baseSnapshot.orders,
      procurement: baseSnapshot.procurement,
      debts: resolvedDebts,
      cash: baseSnapshot.cash,
      receipts: baseSnapshot.receipts,
      notifications: baseSnapshot.notifications,
      sync: baseSnapshot.sync,
      security: resolvedSecurity,
      updatedAt: DateTime.now(),
    );
  }
}
