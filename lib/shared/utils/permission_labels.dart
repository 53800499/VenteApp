import '../enums/permission.dart';

/// Libellés FR pour l’UI RBAC (repli si le catalogue API est indisponible).
String permissionLabel(Permission permission) {
  return _labels[permission] ?? permission.code;
}

String permissionModuleLabel(String moduleCode) {
  return _moduleLabels[moduleCode] ?? moduleCode;
}

const _moduleLabels = <String, String>{
  'auth': 'Authentification',
  'dashboard': 'Tableau de bord',
  'inventory': 'Inventaire',
  'sales': 'Ventes',
  'payments': 'Paiements',
  'customers': 'Clients',
  'debts': 'Dettes',
  'settings': 'Paramètres',
  'users': 'Équipe',
  'rbac': 'Rôles & droits',
  'audit': 'Audit',
  'reports': 'Rapports',
  'shops': 'Boutiques',
};

const _labels = <Permission, String>{
  Permission.authSessionTouch: 'Prolonger la session',
  Permission.authBiometricEnable: 'Activer la biométrie',
  Permission.dashboardRead: 'Lire le tableau de bord',
  Permission.dashboardFinancial: 'Indicateurs financiers',
  Permission.inventoryRead: 'Lire l\'inventaire',
  Permission.inventoryWrite: 'Modifier l\'inventaire',
  Permission.inventoryAdjust: 'Ajuster le stock',
  Permission.inventoryArchive: 'Archiver un produit',
  Permission.salesCreate: 'Créer une vente',
  Permission.salesRead: 'Lire les ventes',
  Permission.salesCancel: 'Annuler une vente',
  Permission.salesPriceOverride: 'Modifier le prix à la vente',
  Permission.paymentsCreate: 'Enregistrer un paiement',
  Permission.paymentsRead: 'Lire les paiements',
  Permission.customersRead: 'Lire les clients',
  Permission.customersWrite: 'Modifier les clients',
  Permission.customersArchive: 'Archiver un client',
  Permission.debtsRead: 'Lire les dettes',
  Permission.debtsPayment: 'Encaisser une dette',
  Permission.debtsForgive: 'Pardonner une dette',
  Permission.settingsRead: 'Lire les paramètres',
  Permission.settingsWrite: 'Modifier les paramètres',
  Permission.usersRead: 'Lire l\'équipe',
  Permission.usersCreate: 'Créer un utilisateur',
  Permission.usersUpdateRole: 'Changer un rôle',
  Permission.usersDeactivate: 'Désactiver un utilisateur',
  Permission.usersAssignShop: 'Réaffecter une boutique',
  Permission.rbacRead: 'Consulter les rôles',
  Permission.rbacManage: 'Gérer les rôles',
  Permission.rbacOverride: 'Exceptions de droits',
  Permission.auditRead: 'Journal d\'audit',
  Permission.reportsRead: 'Lire les rapports',
  Permission.reportsFinancial: 'Rapports financiers',
  Permission.expensesRead: 'Consulter les dépenses',
  Permission.expensesCreate: 'Enregistrer une dépense',
  Permission.expensesUpdate: 'Modifier une dépense',
  Permission.expensesArchive: 'Supprimer une dépense',
  Permission.expensesCategories: 'Gérer les catégories de dépenses',
  Permission.shopsRead: 'Lire les boutiques',
  Permission.shopsCreate: 'Créer une boutique',
  Permission.shopsUpdate: 'Modifier une boutique',
  Permission.shopsDeactivate: 'Désactiver une boutique',
  Permission.shopsSwitch: 'Changer de boutique',
  Permission.shopsConsolidatedRead: 'Vue consolidée',
  Permission.cashSessionsRead: 'Consulter les sessions de caisse',
  Permission.cashSessionsOpen: 'Ouvrir une caisse',
  Permission.cashSessionsClose: 'Clôturer une caisse',
  Permission.cashSessionsAdjust: 'Retraits et entrées de caisse',
};

String permissionModuleCode(Permission permission) {
  final parts = permission.code.split(':');
  return parts.isNotEmpty ? parts.first : permission.code;
}
