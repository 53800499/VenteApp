import '../licensing/domain/module_access_guard.dart';
import 'arike_action.dart';
import 'effective_settings_resolver.dart';
import 'policy_decision.dart';

/// Moteur de résolution d'accès unique orchestrant la chaîne d'évaluation 4 étapes :
///
/// 1. Statut Tenant & Politiques Admin (Suspension, Mode lecture seule).
/// 2. Licence Commerciale Ed25519 (Module inclus dans le forfait ?).
/// 3. Permissions Utilisateur (Habilitation RBAC).
/// 4. Paramètres Métier Effectifs (Stock négatif, plafond remise, octroi crédit).
class AccessPolicyResolver {
  const AccessPolicyResolver({
    required this.effectiveSettingsResolver,
    this.moduleAccessGuard,
  });

  final EffectiveSettingsResolver effectiveSettingsResolver;
  final ModuleAccessGuard? moduleAccessGuard;

  /// Évalue si une [ArikeAction] peut être exécutée par l'utilisateur courant dans le contexte actif.
  PolicyDecision evaluateAction({
    required ArikeAction action,
    required Set<String> userPermissions,
    Map<String, dynamic>? contextData,
  }) {
    // =========================================================================
    // 1. VÉRIFICATION DE SÉCURITÉ ADMIN & TENANT
    // =========================================================================
    final tenantActiveSetting = effectiveSettingsResolver.isTenantActive;
    if (!tenantActiveSetting.value) {
      return PolicyDecision.deny(
        reason: tenantActiveSetting.lockReason ??
            'Le compte de votre entreprise est temporairement suspendu par l\'administration ARIKE.',
        errorCode: 'TENANT_SUSPENDED',
      );
    }

    final readonlySetting = effectiveSettingsResolver.isForceReadonly;
    if (action.isMutation && readonlySetting.value) {
      return PolicyDecision.deny(
        reason: readonlySetting.lockReason ??
            'L\'application est actuellement en mode lecture seule imposé par l\'administration.',
        errorCode: 'FORCE_READONLY',
      );
    }

    // =========================================================================
    // 2. VÉRIFICATION DE LA LICENCE COMMERCIALE (ModuleAccessGuard)
    // =========================================================================
    if (action.requiredModule != null && moduleAccessGuard != null) {
      if (!moduleAccessGuard!.isModuleAuthorized(action.requiredModule!)) {
        final state = moduleAccessGuard!.getLicenseState();
        if (state == LicenseState.suspended) {
          return const PolicyDecision.deny(
            reason: 'La licence commerciale de votre entreprise a été révoquée ou suspendue.',
            errorCode: 'LICENSE_SUSPENDED',
          );
        }

        return PolicyDecision.deny(
          reason: 'Le module "${action.requiredModule!.name}" n\'est pas inclus dans votre forfait d\'abonnement actuel.',
          errorCode: 'LICENSE_MODULE_DISABLED',
        );
      }

      if (action.isMutation && !moduleAccessGuard!.canCreateNewTransaction()) {
        return const PolicyDecision.deny(
          reason: 'Votre licence est expirée ou restreinte. Les nouvelles transactions sont bloquées.',
          errorCode: 'LICENSE_TRANSACTION_BLOCKED',
        );
      }
    }

    // =========================================================================
    // 3. VÉRIFICATION HABILITATION UTILISATEUR (RBAC)
    // =========================================================================
    if (action.requiredPermission != null) {
      final hasPermission = userPermissions.contains(action.requiredPermission) ||
          userPermissions.contains('admin') ||
          userPermissions.contains('*');

      if (!hasPermission) {
        return PolicyDecision.deny(
          reason: 'Vous ne possédez pas la permission requise (${action.requiredPermission}).',
          errorCode: 'PERMISSIONS_FORBIDDEN',
          requiredPermission: action.requiredPermission,
        );
      }
    }

    // =========================================================================
    // 4. VÉRIFICATION DES RÈGLES ET PARAMÈTRES MÉTIER EFFECTIFS
    // =========================================================================
    switch (action) {
      case ArikeAction.sellOnCredit:
        final creditSetting = effectiveSettingsResolver.allowCreditSales;
        if (!creditSetting.value) {
          return PolicyDecision.deny(
            reason: creditSetting.lockReason ??
                'L\'octroi de ventes à crédit est désactivé dans la configuration de la boutique.',
            errorCode: 'SALES_CREDIT_DISABLED',
          );
        }
        break;

      case ArikeAction.applyDiscount:
        final discountSetting = effectiveSettingsResolver.maxDiscountPercent;
        final requestedPercent =
            (contextData?['requestedPercent'] as num?)?.toDouble() ?? 0.0;

        if (requestedPercent > discountSetting.value) {
          return PolicyDecision.deny(
            reason: discountSetting.lockReason ??
                'La remise demandée ($requestedPercent%) dépasse le maximum effectif autorisé (${discountSetting.value}%).',
            errorCode: 'SALES_DISCOUNT_EXCEEDED',
          );
        }
        break;

      default:
        break;
    }

    return const PolicyDecision.allow();
  }
}
