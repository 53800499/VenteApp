import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/licensing/domain/module_access_guard.dart';
import '../../../../core/sync/widgets/sync_status_indicator.dart';
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

/// Barre latérale riche et complète pour Windows Desktop et écrans larges.
/// Regroupe le menu principal et tous les modules issus du menu Plus
/// directement dans l'arborescence de navigation.
///
/// Ne redirige plus vers des pages plein écran, reste constamment affichée
/// et maintient l'état actif du menu sélectionné.
class DesktopSidebar extends StatelessWidget {
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

  bool get _canManageUsers => PermissionGuard.can(
        session.user.permissions,
        Permission.usersRead,
      );

  bool get _canViewRoles => PermissionGuard.can(
        session.user.permissions,
        Permission.rbacRead,
      );

  bool get _canManageShops =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(
        session.user.permissions,
        Permission.shopsSwitch,
      );

  bool get _canViewReports => PermissionGuard.can(
        session.user.permissions,
        Permission.reportsRead,
      );

  bool get _canManageSettings => PermissionGuard.can(
        session.user.permissions,
        Permission.settingsRead,
      );

  bool get _canViewAudit => PermissionGuard.can(
        session.user.permissions,
        Permission.auditRead,
      );

  bool get _canViewExpenses => PermissionGuard.can(
        session.user.permissions,
        Permission.expensesRead,
      );

  bool get _canViewProcurement => PermissionGuard.can(
        session.user.permissions,
        Permission.procurementRead,
      );

  bool get _canViewSalesOrders => PermissionGuard.can(
        session.user.permissions,
        Permission.salesOrdersRead,
      );

  bool get _canViewStockTransfer => PermissionGuard.can(
        session.user.permissions,
        Permission.inventoryTransferRead,
      );

  bool get _canViewCashSessions => PermissionGuard.can(
        session.user.permissions,
        Permission.cashSessionsRead,
      );

  bool get _canUseCalculators => PermissionGuard.can(
        session.user.permissions,
        Permission.calculatorsUse,
      );

  bool get _canViewFxExchange => PermissionGuard.can(
        session.user.permissions,
        Permission.fxExchangeRead,
      );

  bool get _canManageSubscription => session.user.role == UserRole.owner;

  void _openModule(
    BuildContext context, {
    required ArikeModule module,
    required String moduleTitle,
    required SidebarDestination destination,
  }) {
    ensureSubscriptionDependencies();
    final controller = sl<SubscriptionController>();

    if (controller.isModuleGranted(module)) {
      onDestinationSelected(destination);
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
    final subController = sl<SubscriptionController>();

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
              // 1. En-tête : Boutique & Profil Caissier / Gérant
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.heroGradientStart,
                            AppColors.heroGradientEnd,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          session.shop.name.isNotEmpty
                              ? session.shop.name.characters.first.toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: _canManageShops
                            ? () => ShopSwitcherSheet.show(context, session)
                            : null,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.shop.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_canManageShops)
                                    Icon(
                                      Icons.unfold_more_rounded,
                                      size: 16,
                                      color: colorScheme.primary,
                                    ),
                                ],
                              ),
                              Text(
                                '${session.user.name} · ${session.user.roleLabel}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Bouton d'action rapide : "+ Nouvelle Vente"
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: onNewSale,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Nouvelle Vente',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Navigation arborescente scrollable
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  children: [
                    // --- SECTION PRINCIPALE ---
                    const _SidebarSectionTitle('ACTIVITÉ PRINCIPALE'),
                    if (!useFxPrimary) ...[
                      _SidebarItem(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard_rounded,
                        label: 'Tableau de bord',
                        selected: activeDestination == SidebarDestination.dashboard,
                        onTap: () => onDestinationSelected(SidebarDestination.dashboard),
                      ),
                      _SidebarItem(
                        icon: Icons.point_of_sale_outlined,
                        activeIcon: Icons.point_of_sale_rounded,
                        label: 'Ventes & Caisse',
                        selected: activeDestination == SidebarDestination.sales,
                        onTap: () => onDestinationSelected(SidebarDestination.sales),
                      ),
                      _SidebarItem(
                        icon: Icons.inventory_2_outlined,
                        activeIcon: Icons.inventory_2_rounded,
                        label: 'Stock & Produits',
                        selected: activeDestination == SidebarDestination.inventory,
                        onTap: () => onDestinationSelected(SidebarDestination.inventory),
                      ),
                      _SidebarItem(
                        icon: Icons.people_outline,
                        activeIcon: Icons.people_rounded,
                        label: 'Clients & Dettes',
                        selected: activeDestination == SidebarDestination.customers,
                        onTap: () => onDestinationSelected(SidebarDestination.customers),
                      ),
                    ] else ...[
                      _SidebarItem(
                        icon: Icons.currency_exchange,
                        activeIcon: Icons.currency_exchange,
                        label: 'Bureau de Change',
                        selected: activeDestination == SidebarDestination.dashboard,
                        onTap: () => onDestinationSelected(SidebarDestination.dashboard),
                      ),
                      _SidebarItem(
                        icon: Icons.people_outline,
                        activeIcon: Icons.people_rounded,
                        label: 'Clients & Devises',
                        selected: activeDestination == SidebarDestination.customers,
                        onTap: () => onDestinationSelected(SidebarDestination.customers),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xs),

                    // --- SECTION MODULES COMMERCIAUX (Du menu Plus) ---
                    const _SidebarSectionTitle('MODULES & COMMERCE'),
                    if (_canViewCashSessions)
                      _SidebarItem(
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded,
                        label: 'Sessions de Caisse',
                        selected: activeDestination == SidebarDestination.cashSessions,
                        onTap: () => onDestinationSelected(SidebarDestination.cashSessions),
                      ),
                    if (_canViewExpenses)
                      _SidebarItem(
                        icon: Icons.payments_outlined,
                        activeIcon: Icons.payments_rounded,
                        label: 'Dépenses & Charges',
                        selected: activeDestination == SidebarDestination.expenses,
                        badgeText: expensesGranted ? null : 'ESSENTIEL',
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
                        selected: activeDestination == SidebarDestination.procurement,
                        badgeText: procurementGranted ? null : 'ESSENTIEL',
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
                        selected: activeDestination == SidebarDestination.salesOrders,
                        badgeText: salesOrdersGranted ? null : 'ESSENTIEL',
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
                        selected: activeDestination == SidebarDestination.stockTransfer,
                        onTap: () => onDestinationSelected(SidebarDestination.stockTransfer),
                      ),
                    if (_canViewReports) ...[
                      _SidebarItem(
                        icon: Icons.insights_outlined,
                        activeIcon: Icons.insights_rounded,
                        label: 'Statistiques & CA',
                        selected: activeDestination == SidebarDestination.reports,
                        badgeText: reportsGranted ? null : 'PRO',
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
                        selected: activeDestination == SidebarDestination.salesAnalysis,
                        badgeText: reportsGranted ? null : 'PRO',
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
                        selected: activeDestination == SidebarDestination.calculators,
                        onTap: () => onDestinationSelected(SidebarDestination.calculators),
                      ),
                    if (!useFxPrimary && _canViewFxExchange)
                      _SidebarItem(
                        icon: Icons.currency_exchange_rounded,
                        activeIcon: Icons.currency_exchange_rounded,
                        label: 'Change de Devises',
                        selected: activeDestination == SidebarDestination.fxExchange,
                        onTap: () => onDestinationSelected(SidebarDestination.fxExchange),
                      ),

                    const SizedBox(height: AppSpacing.xs),

                    // --- SECTION ENTREPRISE & CONFIGURATION ---
                    const _SidebarSectionTitle('ENTREPRISE & CONFIGURATION'),
                    if (_canManageUsers)
                      _SidebarItem(
                        icon: Icons.badge_outlined,
                        activeIcon: Icons.badge_rounded,
                        label: 'Équipe & Vendeurs',
                        selected: activeDestination == SidebarDestination.users,
                        onTap: () => onDestinationSelected(SidebarDestination.users),
                      ),
                    if (_canViewRoles)
                      _SidebarItem(
                        icon: Icons.admin_panel_settings_outlined,
                        activeIcon: Icons.admin_panel_settings_rounded,
                        label: 'Rôles & Permissions',
                        selected: activeDestination == SidebarDestination.roles,
                        onTap: () => onDestinationSelected(SidebarDestination.roles),
                      ),
                    if (_canManageShops)
                      _SidebarItem(
                        icon: Icons.store_mall_directory_outlined,
                        activeIcon: Icons.store_mall_directory_rounded,
                        label: 'Mes Boutiques',
                        selected: activeDestination == SidebarDestination.shops,
                        onTap: () => onDestinationSelected(SidebarDestination.shops),
                      ),
                    if (_canManageSubscription)
                      _SidebarItem(
                        icon: Icons.workspace_premium_outlined,
                        activeIcon: Icons.workspace_premium_rounded,
                        label: 'Abonnement ARIKE',
                        selected: activeDestination == SidebarDestination.subscription,
                        badgeText: subDetails.planName,
                        badgeColor: Colors.amber.shade800,
                        onTap: () => onDestinationSelected(SidebarDestination.subscription),
                      ),
                    if (_canManageSettings)
                      _SidebarItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded,
                        label: 'Paramètres',
                        selected: activeDestination == SidebarDestination.settings,
                        onTap: () => onDestinationSelected(SidebarDestination.settings),
                      ),
                    if (_canViewAudit)
                      _SidebarItem(
                        icon: Icons.history_rounded,
                        activeIcon: Icons.history_rounded,
                        label: 'Journal d\'Audit',
                        selected: activeDestination == SidebarDestination.audit,
                        onTap: () => onDestinationSelected(SidebarDestination.audit),
                      ),
                  ],
                ),
              ),

              // 4. Pied de Sidebar : Synchro cloud & Verrouillage
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SyncStatusIndicator(session: session),
                    ),
                    IconButton(
                      icon: const Icon(Icons.lock_outline_rounded, size: 20),
                      tooltip: 'Verrouiller l\'application',
                      onPressed: () => context
                          .read<AuthBloc>()
                          .add(const AuthAppLockedRequested()),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        4,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.selected = false,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final effectiveBg =
        selected ? colorScheme.primaryContainer.withValues(alpha: 0.6) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: effectiveBg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 20,
                  color: effectiveColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? colorScheme.secondary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: (badgeColor ?? colorScheme.secondary)
                            .withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: badgeColor ?? colorScheme.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
