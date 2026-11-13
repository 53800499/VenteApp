import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/licensing/domain/module_access_guard.dart';
import '../../../../core/sync/widgets/sync_status_indicator.dart';
import '../../../../core/theme/ui_scale_controller.dart';
import '../../../../core/theme/ui_scale_quick_dialog.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../shop/presentation/widgets/shop_switcher_sheet.dart';
import '../../../subscription/domain/entities/subscription_details.dart';
import '../../../subscription/domain/services/subscription_controller.dart';
import '../../../subscription/presentation/widgets/module_upsell_dialog.dart';
import '../models/sidebar_destination.dart';

/// Barre latérale moderne et complète pour Windows Desktop et écrans larges.
///
/// Design moderne inspiré de Windows 11 Fluent Design et des interfaces
/// SaaS contemporaines :
/// - Mode extensible / rétractable avec transition fluide.
/// - En-tête profil & boutique élégant avec carte d'accès rapide.
/// - Bouton d'action proéminent avec dégradé et raccourci visuel.
/// - Éléments de navigation avec indicateur d'accent vertical, micro-interactions
///   au survol, badges de plan pro/essentiel avec icône de verrouillage.
/// - Dock inférieur moderne intégrant l'état de synchronisation cloud et
///   le verrouillage de session sécurisé.
class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({
    super.key,
    required this.session,
    required this.activeDestination,
    required this.onDestinationSelected,
    required this.onNewSale,
    required this.useFxPrimary,
  });

  final AuthSession session;
  final SidebarDestination activeDestination;
  final ValueChanged<SidebarDestination> onDestinationSelected;
  final VoidCallback onNewSale;
  final bool useFxPrimary;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  bool _isCollapsed = false;

  bool get _canManageUsers => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.usersRead,
      );

  bool get _canViewRoles => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.rbacRead,
      );

  bool get _canManageShops =>
      widget.session.user.role == UserRole.owner ||
      PermissionGuard.can(
        widget.session.user.permissions,
        Permission.shopsSwitch,
      );

  bool get _canViewReports => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.reportsRead,
      );

  bool get _canManageSettings => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.settingsRead,
      );

  bool get _canViewAudit => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.auditRead,
      );

  bool get _canViewExpenses => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.expensesRead,
      );

  bool get _canViewProcurement => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.procurementRead,
      );

  bool get _canViewSalesOrders => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesOrdersRead,
      );

  bool get _canViewStockTransfer => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.inventoryTransferRead,
      );

  bool get _canViewCashSessions => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.cashSessionsRead,
      );

  bool get _canUseCalculators => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.calculatorsUse,
      );

  bool get _canViewFxExchange => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.fxExchangeRead,
      );

  bool get _canManageSubscription => widget.session.user.role == UserRole.owner;

  void _openModule(
    BuildContext context, {
    required ArikeModule module,
    required String moduleTitle,
    required SidebarDestination destination,
  }) {
    ensureSubscriptionDependencies();
    final controller = sl<SubscriptionController>();

    if (controller.isModuleGranted(module)) {
      widget.onDestinationSelected(destination);
    } else {
      final requiredPlan = controller.getRequiredPlanForModule(module);
      final currentPlan = controller.details.planName;
      ModuleUpsellDialog.show(
        context,
        moduleName: moduleTitle,
        requiredPlanName: requiredPlan,
        currentPlanName: currentPlan,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ensureSubscriptionDependencies();
    ensureUiScaleDependencies();
    final subController = sl<SubscriptionController>();
    final scaleController = sl<UiScaleController>();

    return ListenableBuilder(
      listenable: scaleController,
      builder: (context, _) {
        final double sidebarWidth = _isCollapsed
            ? 74.0
            : (272.0 *
                    (scaleController.scaleFactor > 1.0
                        ? 1.0 + (scaleController.scaleFactor - 1.0) * 0.35
                        : 1.0))
                .clamp(270.0, 340.0);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
          ),
          child: ValueListenableBuilder<SubscriptionDetails>(
            valueListenable: subController,
            builder: (context, subDetails, _) {
          final reportsGranted =
              subController.isModuleGranted(ArikeModule.reports);
          final expensesGranted =
              subController.isModuleGranted(ArikeModule.expenses);
          final procurementGranted =
              subController.isModuleGranted(ArikeModule.purchases);
          final salesOrdersGranted =
              subController.isModuleGranted(ArikeModule.salesOrders);

          return Column(
            children: [
              // 1. En-tête : Boutique & Profil & Bascule Réduction
              _buildHeader(context, colorScheme, theme),

              // 2. Bouton d'action rapide : "+ Nouvelle Vente"
              _buildActionButton(colorScheme),

              // 3. Navigation arborescente scrollable
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isCollapsed ? 4 : 4,
                    vertical: AppSpacing.xs,
                  ),
                  children: [
                    // --- SECTION PRINCIPALE ---
                    if (!_isCollapsed)
                      const _SidebarSectionTitle('ACTIVITÉ PRINCIPALE')
                    else
                      _buildCollapsedDivider(colorScheme),

                    if (!widget.useFxPrimary) ...[
                      _SidebarItem(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard_rounded,
                        label: 'Tableau de bord',
                        selected: widget.activeDestination ==
                            SidebarDestination.dashboard,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.dashboard),
                      ),
                      _SidebarItem(
                        icon: Icons.point_of_sale_outlined,
                        activeIcon: Icons.point_of_sale_rounded,
                        label: 'Ventes & Caisse',
                        selected: widget.activeDestination ==
                            SidebarDestination.sales,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.sales),
                      ),
                      _SidebarItem(
                        icon: Icons.inventory_2_outlined,
                        activeIcon: Icons.inventory_2_rounded,
                        label: 'Stock & Produits',
                        selected: widget.activeDestination ==
                            SidebarDestination.inventory,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.inventory),
                      ),
                      _SidebarItem(
                        icon: Icons.analytics_outlined,
                        activeIcon: Icons.analytics_rounded,
                        label: 'Analyse du Stock',
                        selected: widget.activeDestination ==
                            SidebarDestination.stockValuation,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget.onDestinationSelected(
                            SidebarDestination.stockValuation),
                      ),
                      _SidebarItem(
                        icon: Icons.people_outline,
                        activeIcon: Icons.people_rounded,
                        label: 'Clients & Dettes',
                        selected: widget.activeDestination ==
                            SidebarDestination.customers,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.customers),
                      ),
                    ] else ...[
                      _SidebarItem(
                        icon: Icons.currency_exchange,
                        activeIcon: Icons.currency_exchange,
                        label: 'Bureau de Change',
                        selected: widget.activeDestination ==
                            SidebarDestination.dashboard,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.dashboard),
                      ),
                      _SidebarItem(
                        icon: Icons.people_outline,
                        activeIcon: Icons.people_rounded,
                        label: 'Clients & Devises',
                        selected: widget.activeDestination ==
                            SidebarDestination.customers,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.customers),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xs),

                    // --- SECTION MODULES COMMERCIAUX ---
                    if (!_isCollapsed)
                      const _SidebarSectionTitle('MODULES & COMMERCE')
                    else
                      _buildCollapsedDivider(colorScheme),

                    if (_canViewCashSessions)
                      _SidebarItem(
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded,
                        label: 'Sessions de Caisse',
                        selected: widget.activeDestination ==
                            SidebarDestination.cashSessions,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget.onDestinationSelected(
                            SidebarDestination.cashSessions),
                      ),
                    if (_canViewExpenses)
                      _SidebarItem(
                        icon: Icons.payments_outlined,
                        activeIcon: Icons.payments_rounded,
                        label: 'Dépenses & Charges',
                        selected: widget.activeDestination ==
                            SidebarDestination.expenses,
                        badgeText: expensesGranted ? null : 'ESSENTIEL',
                        isLocked: !expensesGranted,
                        isCollapsed: _isCollapsed,
                        onTap: () => _openModule(
                          context,
                          module: ArikeModule.expenses,
                          moduleTitle: 'Dépenses & Charges',
                          destination: SidebarDestination.expenses,
                        ),
                      ),
                    if (_canViewProcurement)
                      _SidebarItem(
                        icon: Icons.local_shipping_outlined,
                        activeIcon: Icons.local_shipping_rounded,
                        label: 'Approvisionnements',
                        selected: widget.activeDestination ==
                            SidebarDestination.procurement,
                        badgeText: procurementGranted ? null : 'ESSENTIEL',
                        isLocked: !procurementGranted,
                        isCollapsed: _isCollapsed,
                        onTap: () => _openModule(
                          context,
                          module: ArikeModule.purchases,
                          moduleTitle: 'Approvisionnements & Commandes',
                          destination: SidebarDestination.procurement,
                        ),
                      ),
                    if (_canViewSalesOrders)
                      _SidebarItem(
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long_rounded,
                        label: 'Commandes Clients',
                        selected: widget.activeDestination ==
                            SidebarDestination.salesOrders,
                        badgeText: salesOrdersGranted ? null : 'ESSENTIEL',
                        isLocked: !salesOrdersGranted,
                        isCollapsed: _isCollapsed,
                        onTap: () => _openModule(
                          context,
                          module: ArikeModule.salesOrders,
                          moduleTitle: 'Commandes Clients & Livraisons',
                          destination: SidebarDestination.salesOrders,
                        ),
                      ),
                    if (_canViewStockTransfer)
                      _SidebarItem(
                        icon: Icons.swap_horiz_rounded,
                        activeIcon: Icons.swap_horiz_rounded,
                        label: 'Transferts de Stock',
                        selected: widget.activeDestination ==
                            SidebarDestination.stockTransfer,
                        badgeText: subController.isModuleGranted(ArikeModule.multiShop) ? null : 'PRO',
                        isLocked: !subController.isModuleGranted(ArikeModule.multiShop),
                        isCollapsed: _isCollapsed,
                        onTap: () => _openModule(
                          context,
                          module: ArikeModule.multiShop,
                          moduleTitle: 'Transferts de Stock',
                          destination: SidebarDestination.stockTransfer,
                        ),
                      ),
                    if (_canViewReports) ...[
                      _SidebarItem(
                        icon: Icons.insights_outlined,
                        activeIcon: Icons.insights_rounded,
                        label: 'Statistiques & CA',
                        selected: widget.activeDestination ==
                            SidebarDestination.reports,
                        badgeText: reportsGranted ? null : 'PRO',
                        isLocked: !reportsGranted,
                        isCollapsed: _isCollapsed,
                        onTap: () => _openModule(
                          context,
                          module: ArikeModule.reports,
                          moduleTitle: 'Statistiques & Analyses',
                          destination: SidebarDestination.reports,
                        ),
                      ),
                      _SidebarItem(
                        icon: Icons.analytics_outlined,
                        activeIcon: Icons.analytics_rounded,
                        label: 'Analyse des Ventes',
                        selected: widget.activeDestination ==
                            SidebarDestination.salesAnalysis,
                        badgeText: reportsGranted ? null : 'PRO',
                        isLocked: !reportsGranted,
                        isCollapsed: _isCollapsed,
                        onTap: () => _openModule(
                          context,
                          module: ArikeModule.reports,
                          moduleTitle: 'Analyse des Ventes',
                          destination: SidebarDestination.salesAnalysis,
                        ),
                      ),
                    ],
                    if (_canUseCalculators)
                      _SidebarItem(
                        icon: Icons.calculate_outlined,
                        activeIcon: Icons.calculate_rounded,
                        label: 'Calculateurs & Devis',
                        selected: widget.activeDestination ==
                            SidebarDestination.calculators,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget.onDestinationSelected(
                            SidebarDestination.calculators),
                      ),
                    if (!widget.useFxPrimary && _canViewFxExchange)
                      _SidebarItem(
                        icon: Icons.currency_exchange_rounded,
                        activeIcon: Icons.currency_exchange_rounded,
                        label: 'Change de Devises',
                        selected: widget.activeDestination ==
                            SidebarDestination.fxExchange,
                        badgeText: subController.isModuleGranted(ArikeModule.fxExchange) ? null : 'PRO',
                        isLocked: !subController.isModuleGranted(ArikeModule.fxExchange),
                        isCollapsed: _isCollapsed,
                        onTap: () => _openModule(
                          context,
                          module: ArikeModule.fxExchange,
                          moduleTitle: 'Change de Devises FX',
                          destination: SidebarDestination.fxExchange,
                        ),
                      ),

                    const SizedBox(height: AppSpacing.xs),

                    // --- SECTION ENTREPRISE & CONFIGURATION ---
                    if (!_isCollapsed)
                      const _SidebarSectionTitle('ENTREPRISE & CONFIGURATION')
                    else
                      _buildCollapsedDivider(colorScheme),

                    if (_canManageUsers)
                      _SidebarItem(
                        icon: Icons.badge_outlined,
                        activeIcon: Icons.badge_rounded,
                        label: 'Équipe & Vendeurs',
                        selected: widget.activeDestination ==
                            SidebarDestination.users,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.users),
                      ),
                    if (_canViewRoles)
                      _SidebarItem(
                        icon: Icons.admin_panel_settings_outlined,
                        activeIcon: Icons.admin_panel_settings_rounded,
                        label: 'Rôles & Permissions',
                        selected: widget.activeDestination ==
                            SidebarDestination.roles,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.roles),
                      ),
                    if (_canManageShops)
                      _SidebarItem(
                        icon: Icons.store_mall_directory_outlined,
                        activeIcon: Icons.store_mall_directory_rounded,
                        label: 'Mes Boutiques',
                        selected: widget.activeDestination ==
                            SidebarDestination.shops,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.shops),
                      ),
                    if (_canManageSubscription)
                      _SidebarItem(
                        icon: Icons.workspace_premium_outlined,
                        activeIcon: Icons.workspace_premium_rounded,
                        label: 'Abonnement ARIKE',
                        selected: widget.activeDestination ==
                            SidebarDestination.subscription,
                        badgeText: subDetails.planName,
                        badgeColor: Colors.amber.shade800,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget.onDestinationSelected(
                            SidebarDestination.subscription),
                      ),
                    if (_canManageSettings)
                      _SidebarItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded,
                        label: 'Paramètres',
                        selected: widget.activeDestination ==
                            SidebarDestination.settings,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.settings),
                      ),
                    if (_canViewAudit)
                      _SidebarItem(
                        icon: Icons.history_rounded,
                        activeIcon: Icons.history_rounded,
                        label: 'Journal d\'Audit',
                        selected: widget.activeDestination ==
                            SidebarDestination.audit,
                        isCollapsed: _isCollapsed,
                        onTap: () => widget
                            .onDestinationSelected(SidebarDestination.audit),
                      ),
                  ],
                ),
              ),

              // 4. Pied de Sidebar : Synchro cloud & Verrouillage
              _buildFooter(context, colorScheme),
            ],
          );
        },
      ),
    );
      },
    );
  }

  Widget _buildCollapsedDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(
        height: 1,
        thickness: 1,
        indent: 14,
        endIndent: 14,
        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    if (_isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          children: [
            // Avatar de la boutique avec tooltip
            Tooltip(
              message:
                  '${widget.session.shop.name} (${widget.session.user.roleLabel})',
              waitDuration: const Duration(milliseconds: 300),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _canManageShops
                      ? () => ShopSwitcherSheet.show(context, widget.session)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.heroGradientStart,
                          AppColors.heroGradientEnd,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.heroGradientStart.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.session.shop.name.isNotEmpty
                            ? widget.session.shop.name.characters.first
                                .toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Bouton pour ré-étendre le menu
            Tooltip(
              message: 'Développer le menu',
              waitDuration: const Duration(milliseconds: 300),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _isCollapsed = false),
                  borderRadius: BorderRadius.circular(8),
                  hoverColor:
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.menu_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        AppSpacing.sm + 2,
        AppSpacing.sm + 2,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Carte profil boutique
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _canManageShops
                    ? () => ShopSwitcherSheet.show(context, widget.session)
                    : null,
                borderRadius: BorderRadius.circular(12),
                hoverColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.25),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.heroGradientStart,
                              AppColors.heroGradientEnd,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.heroGradientStart
                                  .withValues(alpha: 0.25),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.session.shop.name.isNotEmpty
                                ? widget.session.shop.name.characters.first
                                    .toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.session.shop.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      letterSpacing: -0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_canManageShops)
                                  Icon(
                                    Icons.unfold_more_rounded,
                                    size: 15,
                                    color: colorScheme.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${widget.session.user.name} · ${widget.session.user.roleLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Bouton pour replier la barre latérale
          Tooltip(
            message: 'Réduire le menu',
            waitDuration: const Duration(milliseconds: 300),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isCollapsed = true),
                borderRadius: BorderRadius.circular(8),
                hoverColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.menu_open_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ColorScheme colorScheme) {
    if (_isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Tooltip(
          message: 'Nouvelle Vente (F1)',
          waitDuration: const Duration(milliseconds: 300),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  Color.lerp(colorScheme.primary, Colors.black, 0.15) ??
                      colorScheme.primary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onNewSale,
                borderRadius: BorderRadius.circular(10),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        AppSpacing.sm,
        AppSpacing.sm + 2,
        AppSpacing.xs,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, Colors.black, 0.12) ??
                  colorScheme.primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onNewSale,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Nouvelle Vente',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'F1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ColorScheme colorScheme) {
    ensureUiScaleDependencies();
    final scaleController = sl<UiScaleController>();

    if (_isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SyncStatusIndicator(session: widget.session),
            const SizedBox(height: 6),
            Tooltip(
              message: 'Taille de police (${scaleController.percentage}%)',
              waitDuration: const Duration(milliseconds: 300),
              child: IconButton(
                icon: const Icon(Icons.format_size_rounded, size: 18),
                onPressed: () => UiScaleQuickDialog.show(context),
              ),
            ),
            const SizedBox(height: 4),
            Tooltip(
              message: 'Verrouiller la session',
              waitDuration: const Duration(milliseconds: 300),
              child: IconButton(
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                onPressed: () => context
                    .read<AuthBloc>()
                    .add(const AuthAppLockedRequested()),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: SyncStatusIndicator(session: widget.session),
            ),
          ),
          const SizedBox(width: 6),
          // Bouton rapide d'ajustement de la taille de police
          Tooltip(
            message: 'Taille de police globale (${scaleController.percentage}%)',
            waitDuration: const Duration(milliseconds: 300),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => UiScaleQuickDialog.show(context),
                borderRadius: BorderRadius.circular(8),
                hoverColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_size_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${scaleController.percentage}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Verrouiller l\'application',
            waitDuration: const Duration(milliseconds: 300),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context
                    .read<AuthBloc>()
                    .add(const AuthAppLockedRequested()),
                borderRadius: BorderRadius.circular(8),
                hoverColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionTitle extends StatelessWidget {
  const _SidebarSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        12,
        4,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.selected = false,
    this.isCollapsed = false,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
    this.isLocked = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;
  final bool isLocked;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isSelected = widget.selected;
    final effectiveIcon = isSelected ? widget.activeIcon : widget.icon;

    final Color iconColor = isSelected
        ? colorScheme.primary
        : (_isHovered
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.85));

    final Color textColor = isSelected
        ? colorScheme.primary
        : (_isHovered ? colorScheme.onSurface : colorScheme.onSurfaceVariant);

    final Color? bgColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.12)
        : (_isHovered
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
            : null);

    if (widget.isCollapsed) {
      final tooltipMessage = widget.badgeText != null
          ? '${widget.label} • ${widget.badgeText}'
          : widget.label;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Tooltip(
          message: tooltipMessage,
          waitDuration: const Duration(milliseconds: 300),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 38,
                decoration: BoxDecoration(
                  color: bgColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: isSelected
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                          width: 1,
                        )
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      Positioned(
                        left: 0,
                        top: 9,
                        bottom: 9,
                        child: Container(
                          width: 3.5,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(3),
                              bottomRight: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    Icon(
                      effectiveIcon,
                      size: 22,
                      color: iconColor,
                    ),
                    if (widget.badgeText != null)
                      Positioned(
                        top: 7,
                        right: 8,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.badgeColor ?? colorScheme.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: bgColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Indicateur vertical d'accent à gauche pour l'élément actif
                Container(
                  width: 3.5,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  effectiveIcon,
                  size: 21,
                  color: iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badgeText != null) ...[
                  const SizedBox(width: 6),
                  _SidebarBadge(
                    text: widget.badgeText!,
                    color: widget.badgeColor ?? colorScheme.secondary,
                    isLocked: widget.isLocked,
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarBadge extends StatelessWidget {
  const _SidebarBadge({
    required this.text,
    required this.color,
    this.isLocked = false,
  });

  final String text;
  final Color color;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLocked) ...[
            Icon(
              Icons.lock_rounded,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 2.5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
