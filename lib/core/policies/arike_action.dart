import '../licensing/domain/module_access_guard.dart';

/// Enumération exhaustive des actions utilisateur et opérations métier dans l'application ARIKE.
enum ArikeAction {
  /// Création et validation d'une vente directe au comptant.
  createSale(
    requiredModule: ArikeModule.sales,
    requiredPermission: 'sales.create',
    isMutation: true,
  ),

  /// Octroi d'une vente à crédit à un client.
  sellOnCredit(
    requiredModule: ArikeModule.sales,
    requiredPermission: 'sales.credit',
    isMutation: true,
  ),

  /// Application d'une remise sur une vente.
  applyDiscount(
    requiredModule: ArikeModule.sales,
    requiredPermission: 'sales.discount',
    isMutation: false,
  ),

  /// Modification manuelle du prix unitaire d'un article.
  overridePrice(
    requiredModule: ArikeModule.sales,
    requiredPermission: 'sales.price_override',
    isMutation: false,
  ),

  /// Consultation du catalogue et des stocks d'inventaire.
  accessInventory(
    requiredModule: ArikeModule.inventory,
    requiredPermission: 'inventory.read',
    isMutation: false,
  ),

  /// Ajustement manuel de stock (entrée / sortie / inventaire).
  adjustStock(
    requiredModule: ArikeModule.inventory,
    requiredPermission: 'inventory.adjust',
    isMutation: true,
  ),

  /// Consultation du module Bureau de Change.
  accessFxExchange(
    requiredModule: ArikeModule.fxExchange,
    requiredPermission: 'fx.read',
    isMutation: false,
  ),

  /// Exécution d'une opération de change de devises.
  performFxTransaction(
    requiredModule: ArikeModule.fxExchange,
    requiredPermission: 'fx.trade',
    isMutation: true,
  ),

  /// Consultation des rapports et analyses métier.
  accessReports(
    requiredModule: ArikeModule.reports,
    requiredPermission: 'reports.view',
    isMutation: false,
  ),

  /// Modification des paramètres de la boutique.
  manageSettings(
    requiredModule: ArikeModule.sales,
    requiredPermission: 'settings.manage',
    isMutation: true,
  ),

  /// Création d'un bon de commande ou d'achat fournisseur.
  createPurchaseOrder(
    requiredModule: ArikeModule.purchases,
    requiredPermission: 'purchases.create',
    isMutation: true,
  ),

  /// Saisie d'une dépense d'exploitation.
  recordExpense(
    requiredModule: ArikeModule.expenses,
    requiredPermission: 'expenses.create',
    isMutation: true,
  );

  const ArikeAction({
    this.requiredModule,
    this.requiredPermission,
    this.isMutation = false,
  });

  /// Le module commercial Arike requis pour exécuter cette action.
  final ArikeModule? requiredModule;

  /// La permission RBAC nécessaire au niveau utilisateur.
  final String? requiredPermission;

  /// Indique si cette action effectue une écriture / création de donnée métier.
  final bool isMutation;
}
