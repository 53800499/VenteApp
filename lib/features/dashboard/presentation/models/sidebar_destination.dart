import 'package:flutter/material.dart';

/// Énumération de toutes les destinations possibles de navigation
/// de la barre latérale desktop (DesktopSidebar).
enum SidebarDestination {
  dashboard,
  sales,
  inventory,
  customers,
  // Modules & Commerce
  cashSessions,
  expenses,
  procurement,
  salesOrders,
  stockTransfer,
  reports,
  salesAnalysis,
  calculators,
  fxExchange,
  // Entreprise & Configuration
  users,
  roles,
  shops,
  subscription,
  settings,
  audit,
}

extension SidebarDestinationX on SidebarDestination {
  /// Titre affiché dans le menu et le fil d'Ariane
  String label({bool useFxPrimary = false}) => switch (this) {
        SidebarDestination.dashboard =>
          useFxPrimary ? 'Bureau de Change' : 'Tableau de bord',
        SidebarDestination.sales => 'Ventes & Caisse',
        SidebarDestination.inventory => 'Stock & Produits',
        SidebarDestination.customers =>
          useFxPrimary ? 'Clients & Devises' : 'Clients & Dettes',
        SidebarDestination.cashSessions => 'Sessions de Caisse',
        SidebarDestination.expenses => 'Dépenses & Charges',
        SidebarDestination.procurement => 'Approvisionnements',
        SidebarDestination.salesOrders => 'Commandes Clients',
        SidebarDestination.stockTransfer => 'Transferts de Stock',
        SidebarDestination.reports => 'Statistiques & CA',
        SidebarDestination.salesAnalysis => 'Analyse des Ventes',
        SidebarDestination.calculators => 'Calculateurs & Devis',
        SidebarDestination.fxExchange => 'Change de Devises',
        SidebarDestination.users => 'Équipe & Vendeurs',
        SidebarDestination.roles => 'Rôles & Permissions',
        SidebarDestination.shops => 'Mes Boutiques',
        SidebarDestination.subscription => 'Abonnement ARIKE',
        SidebarDestination.settings => 'Paramètres',
        SidebarDestination.audit => 'Journal d\'Audit',
      };

  /// Libellé de section parente pour le fil d'Ariane
  String get sectionLabel => switch (this) {
        SidebarDestination.dashboard ||
        SidebarDestination.sales ||
        SidebarDestination.inventory ||
        SidebarDestination.customers =>
          'Activité principale',
        SidebarDestination.cashSessions ||
        SidebarDestination.expenses ||
        SidebarDestination.procurement ||
        SidebarDestination.salesOrders ||
        SidebarDestination.stockTransfer ||
        SidebarDestination.reports ||
        SidebarDestination.salesAnalysis ||
        SidebarDestination.calculators ||
        SidebarDestination.fxExchange =>
          'Modules & Commerce',
        SidebarDestination.users ||
        SidebarDestination.roles ||
        SidebarDestination.shops ||
        SidebarDestination.subscription ||
        SidebarDestination.settings ||
        SidebarDestination.audit =>
          'Entreprise & Configuration',
      };

  /// Icône par défaut
  IconData icon({bool useFxPrimary = false}) => switch (this) {
        SidebarDestination.dashboard => useFxPrimary
            ? Icons.currency_exchange
            : Icons.dashboard_outlined,
        SidebarDestination.sales => Icons.point_of_sale_outlined,
        SidebarDestination.inventory => Icons.inventory_2_outlined,
        SidebarDestination.customers => Icons.people_outline,
        SidebarDestination.cashSessions => Icons.account_balance_wallet_outlined,
        SidebarDestination.expenses => Icons.payments_outlined,
        SidebarDestination.procurement => Icons.local_shipping_outlined,
        SidebarDestination.salesOrders => Icons.receipt_long_outlined,
        SidebarDestination.stockTransfer => Icons.swap_horiz_rounded,
        SidebarDestination.reports => Icons.insights_outlined,
        SidebarDestination.salesAnalysis => Icons.analytics_outlined,
        SidebarDestination.calculators => Icons.calculate_outlined,
        SidebarDestination.fxExchange => Icons.currency_exchange_rounded,
        SidebarDestination.users => Icons.badge_outlined,
        SidebarDestination.roles => Icons.admin_panel_settings_outlined,
        SidebarDestination.shops => Icons.store_mall_directory_outlined,
        SidebarDestination.subscription => Icons.workspace_premium_outlined,
        SidebarDestination.settings => Icons.settings_outlined,
        SidebarDestination.audit => Icons.history_rounded,
      };

  /// Icône active/sélectionnée
  IconData activeIcon({bool useFxPrimary = false}) => switch (this) {
        SidebarDestination.dashboard => useFxPrimary
            ? Icons.currency_exchange
            : Icons.dashboard_rounded,
        SidebarDestination.sales => Icons.point_of_sale_rounded,
        SidebarDestination.inventory => Icons.inventory_2_rounded,
        SidebarDestination.customers => Icons.people_rounded,
        SidebarDestination.cashSessions => Icons.account_balance_wallet_rounded,
        SidebarDestination.expenses => Icons.payments_rounded,
        SidebarDestination.procurement => Icons.local_shipping_rounded,
        SidebarDestination.salesOrders => Icons.receipt_long_rounded,
        SidebarDestination.stockTransfer => Icons.swap_horiz_rounded,
        SidebarDestination.reports => Icons.insights_rounded,
        SidebarDestination.salesAnalysis => Icons.analytics_rounded,
        SidebarDestination.calculators => Icons.calculate_rounded,
        SidebarDestination.fxExchange => Icons.currency_exchange_rounded,
        SidebarDestination.users => Icons.badge_rounded,
        SidebarDestination.roles => Icons.admin_panel_settings_rounded,
        SidebarDestination.shops => Icons.store_mall_directory_rounded,
        SidebarDestination.subscription => Icons.workspace_premium_rounded,
        SidebarDestination.settings => Icons.settings_rounded,
        SidebarDestination.audit => Icons.history_rounded,
      };

  /// Vrai si la destination est une sous-page
  bool get isSubpage => this != SidebarDestination.dashboard;

  /// Clé d'aide contextuelle
  String? get helpArticleId => switch (this) {
        SidebarDestination.dashboard => 'dashboard',
        SidebarDestination.sales => 'sales',
        SidebarDestination.inventory => 'inventory',
        SidebarDestination.customers => 'customers',
        SidebarDestination.cashSessions => 'cash_sessions',
        SidebarDestination.expenses => 'expenses',
        SidebarDestination.procurement => 'procurement',
        SidebarDestination.salesOrders => 'sales_orders',
        SidebarDestination.stockTransfer => 'stock_transfer',
        SidebarDestination.reports => 'reports',
        SidebarDestination.salesAnalysis => 'sales_analysis',
        SidebarDestination.calculators => 'calculators',
        SidebarDestination.fxExchange => 'fx_exchange',
        SidebarDestination.users => 'users',
        SidebarDestination.roles => 'roles',
        SidebarDestination.shops => 'shops',
        SidebarDestination.subscription => 'subscription',
        SidebarDestination.settings => 'settings_security',
        SidebarDestination.audit => 'audit',
      };
}
