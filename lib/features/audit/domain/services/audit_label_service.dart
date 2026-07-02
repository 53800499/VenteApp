import '../../../../shared/enums/audit_enums.dart';
import '../entities/audit_entities.dart';

/// Libellés FR des actions et modules — aligné sur le backend.
class AuditLabelService {
  const AuditLabelService();

  static const _actionLabels = <String, String>{
    'emergency_unlock': 'Déblocage d\'urgence',
    'user_role_changed': 'Changement de rôle',
    'user_shop_assigned': 'Affectation boutique',
    'rbac_overrides_replaced': 'Permissions personnalisées',
    'debt_created': 'Dette créée',
    'debt_payment_recorded': 'Remboursement dette',
    'debt_forgiven': 'Dette pardonnée',
    'sale_created': 'Vente enregistrée',
    'sale_cancelled': 'Vente annulée',
    'stock_adjusted': 'Ajustement de stock',
    'product_price_changed': 'Modification de prix',
    'product_archived': 'Produit archivé',
    'product_deleted': 'Produit supprimé',
    'category_deleted': 'Catégorie supprimée',
    'shop_created': 'Boutique créée',
    'shop_updated': 'Boutique modifiée',
    'shop_deactivated': 'Boutique désactivée',
    'shop_default_set': 'Boutique par défaut',
    'shop_switched': 'Changement de boutique',
    'customer_archived': 'Client archivé',
    'customer_created': 'Client créé',
    'customer_updated': 'Client modifié',
    'settings_updated': 'Paramètres modifiés',
        'backup_recorded': 'Sauvegarde enregistrée',
        'pin_changed': 'PIN modifié',
    'sync_settings_updated': 'Sync cloud modifiée',
    'sync_conflict_resolved': 'Conflit de sync résolu',
  };

  static const _moduleLabels = <String, String>{
    'auth': 'Authentification',
    'settings': 'Paramètres',
    'users': 'Utilisateurs',
    'sales': 'Ventes',
    'debts': 'Dettes',
    'products': 'Inventaire',
    'shops': 'Boutiques',
    'customers': 'Clients',
  };

  String actionLabel(String action) =>
      _actionLabels[action] ?? action;

  String moduleLabel(String module) =>
      _moduleLabels[module] ?? module;

  AuditFilterOptions listFilterOptions() {
    return AuditFilterOptions(
      modules: AuditModule.values
          .map(
            (m) => AuditFilterOption(
              code: m.code,
              label: moduleLabel(m.code),
            ),
          )
          .toList(),
      actions: AuditAction.values
          .map(
            (a) => AuditFilterOption(
              code: a.code,
              label: actionLabel(a.code),
            ),
          )
          .toList(),
    );
  }
}
