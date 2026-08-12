import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/components/feature_ui.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../../core/licensing/domain/module_access_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/widgets/identity_context_card.dart';
import '../../../../core/security/production_message_policy.dart';
import '../../../../app/pages/api_settings_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../sales_analysis/presentation/pages/sales_analysis_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../cash_sessions/presentation/pages/cash_sessions_page.dart';
import '../../../audit/presentation/pages/audit_journal_page.dart';
import '../../../calculators/presentation/pages/calculators_page.dart';
import '../../../debts/presentation/pages/forgiven_debts_page.dart';
import '../../../notifications/presentation/pages/notification_settings_page.dart';
import '../../../sync/presentation/pages/sync_conflicts_page.dart';
import '../../../users/presentation/pages/user_list_page.dart';
import '../../../rbac/presentation/pages/roles_catalog_page.dart';
import '../../../help/presentation/pages/help_hub_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../procurement/presentation/pages/procurement_page.dart';
import '../../../sales_orders/presentation/pages/sales_orders_page.dart';
import '../../../stock_transfer/presentation/pages/stock_transfer_page.dart';
import '../../../../app/di/injection_container.dart';
import '../../../fx_exchange/presentation/fx_workspace_mode_controller.dart';
import '../../../fx_exchange/presentation/pages/fx_exchange_page.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
import '../../../subscription/domain/entities/subscription_details.dart';
import '../../../subscription/domain/services/subscription_controller.dart';
import '../../../subscription/presentation/widgets/module_upsell_dialog.dart';
import 'shop_list_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.session});

  final AuthSession session;

  bool get _canManageUsers => PermissionGuard.can(
        session.user.permissions,
        Permission.usersRead,
      );

  bool get _canViewRoles => PermissionGuard.can(
        session.user.permissions,
        Permission.rbacRead,
      );

  bool get _canManageShops => PermissionGuard.can(
        session.user.permissions,
        Permission.shopsSwitch,
      ) ||
      session.user.role == UserRole.owner;

  bool get _canViewReports => PermissionGuard.can(
        session.user.permissions,
        Permission.reportsRead,
      );

  bool get _canManageSettings => PermissionGuard.can(
        session.user.permissions,
        Permission.settingsRead,
      );

  bool get _canManageAlerts => PermissionGuard.can(
        session.user.permissions,
        Permission.settingsRead,
      );

  bool get _canViewAudit => PermissionGuard.can(
        session.user.permissions,
        Permission.auditRead,
      );

  bool get _canViewDebts => PermissionGuard.can(
        session.user.permissions,
        Permission.debtsRead,
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

  bool get _canManageSync => session.user.role == UserRole.owner;

  bool get _canUseCalculators => PermissionGuard.can(
        session.user.permissions,
        Permission.calculatorsUse,
      );

  bool get _canViewFxExchange => PermissionGuard.can(
        session.user.permissions,
        Permission.fxExchangeRead,
      );

  bool get _canManageSubscription => session.user.role == UserRole.owner;

  void _openModuleIfAuthorized(
    BuildContext context, {
    required ArikeModule module,
    required String moduleTitle,
    required VoidCallback onNavigate,
  }) {
    ensureSubscriptionDependencies();
    final controller = sl<SubscriptionController>();

    if (controller.isModuleGranted(module)) {
      onNavigate();
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
    ensureSubscriptionDependencies();
    final subController = sl<SubscriptionController>();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final activeSession =
            state is AuthAuthenticated ? state.session : session;

        return ValueListenableBuilder<SubscriptionDetails>(
          valueListenable: subController,
          builder: (context, subDetails, _) {
            final reportsGranted = subController.isModuleGranted(ArikeModule.reports);
            final expensesGranted = subController.isModuleGranted(ArikeModule.expenses);
            final procurementGranted = subController.isModuleGranted(ArikeModule.purchases);
            final salesOrdersGranted = subController.isModuleGranted(ArikeModule.purchases);
            final multiShopGranted = subController.isModuleGranted(ArikeModule.multiShop);
            final fxGranted = subController.isModuleGranted(ArikeModule.fxExchange);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      IdentityContextCard(
                        session: activeSession,
                        onChangeIdentity: () => _confirmChangeIdentity(context),
                      ),
                      const SizedBox(height: AppSpacing.md),

                  // ⭐ Section 1: Abonnement ARIKE (Owner Only)
                  if (_canManageSubscription) ...[
                    const _SectionHeader(
                      title: 'Abonnement ARIKE',
                      icon: Icons.workspace_premium_outlined,
                    ),
                    ModuleActionTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Mon abonnement — ${subDetails.planName}',
                      subtitle: subDetails.isRevoked
                          ? '🚫 ACCÈS RÉVOQUÉ — Touchez pour réactiver votre offre'
                          : 'Offre active : ${subDetails.planName} (${subDetails.status}) · Expire le ${subDetails.expiresAt.day}/${subDetails.expiresAt.month}/${subDetails.expiresAt.year}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionPage(),
                        ),
                      ),
                    ),
                  ],

                  // 🏢 Section 2: Mon Entreprise & Équipe
                  if (_canManageShops || _canManageUsers || _canViewRoles) ...[
                    const _SectionHeader(
                      title: 'Mon Entreprise & Équipe',
                      icon: Icons.domain_outlined,
                    ),
                    if (_canManageShops)
                      ModuleActionTile(
                        icon: Icons.store_mall_directory_outlined,
                        title: 'Mes boutiques',
                        subtitle:
                            'Gérer vos boutiques ou touchez le nom en haut pour changer',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ShopListPage(session: activeSession),
                          ),
                        ),
                      ),
                    if (_canManageUsers)
                      ModuleActionTile(
                        icon: Icons.people_outline,
                        title: 'Équipe',
                        subtitle: 'Vendeurs, lecteurs et droits',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserListPage(session: activeSession),
                          ),
                        ),
                      ),
                    if (_canViewRoles)
                      ModuleActionTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Rôles & permissions',
                        subtitle: 'Catalogue des rôles et droits',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RolesCatalogPage(session: activeSession),
                          ),
                        ),
                      ),
                  ],

                  // 📊 Section 3: Gestion Commerciale & Analyses
                  if (_canViewReports ||
                      _canViewExpenses ||
                      _canViewProcurement ||
                      _canViewSalesOrders ||
                      _canViewStockTransfer) ...[
                    const _SectionHeader(
                      title: 'Gestion Commerciale & Analyses',
                      icon: Icons.analytics_outlined,
                    ),
                    if (_canViewReports)
                      ModuleActionTile(
                        icon: Icons.insights_outlined,
                        title: 'Statistiques',
                        subtitle: 'CA, bénéfice, top produits et recouvrement',
                        isLocked: !reportsGranted,
                        lockedBadgeText: 'PRO',
                        onTap: () => _openModuleIfAuthorized(
                          context,
                          module: ArikeModule.reports,
                          moduleTitle: 'Statistiques & Analyses',
                          onNavigate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportsPage(session: activeSession),
                            ),
                          ),
                        ),
                      ),
                    if (_canViewReports)
                      ModuleActionTile(
                        icon: Icons.analytics_outlined,
                        title: 'Analyse des ventes',
                        subtitle: 'Prix pratiqués, produits vendus et écarts',
                        isLocked: !reportsGranted,
                        lockedBadgeText: 'PRO',
                        onTap: () => _openModuleIfAuthorized(
                          context,
                          module: ArikeModule.reports,
                          moduleTitle: 'Analyse des Ventes',
                          onNavigate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SalesAnalysisPage(session: activeSession),
                            ),
                          ),
                        ),
                      ),
                    if (_canViewExpenses)
                      ModuleActionTile(
                        icon: Icons.payments_outlined,
                        title: 'Dépenses',
                        subtitle: 'Charges, caisse et bénéfice réel',
                        isLocked: !expensesGranted,
                        lockedBadgeText: 'ESSENTIEL',
                        onTap: () => _openModuleIfAuthorized(
                          context,
                          module: ArikeModule.expenses,
                          moduleTitle: 'Dépenses & Charges',
                          onNavigate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExpensesPage(session: activeSession),
                            ),
                          ),
                        ),
                      ),
                    if (_canViewProcurement)
                      ModuleActionTile(
                        icon: Icons.local_shipping_outlined,
                        title: 'Approvisionnement',
                        subtitle: 'Commandes fournisseurs, réceptions et stocks',
                        isLocked: !procurementGranted,
                        lockedBadgeText: 'ESSENTIEL',
                        onTap: () => _openModuleIfAuthorized(
                          context,
                          module: ArikeModule.purchases,
                          moduleTitle: 'Approvisionnement & Commandes',
                          onNavigate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProcurementPage(session: activeSession),
                            ),
                          ),
                        ),
                      ),
                    if (_canViewSalesOrders)
                      ModuleActionTile(
                        icon: Icons.assignment_outlined,
                        title: 'Commandes clients',
                        subtitle: 'Commandes, livraisons partielles et refus',
                        isLocked: !salesOrdersGranted,
                        lockedBadgeText: 'ESSENTIEL',
                        onTap: () => _openModuleIfAuthorized(
                          context,
                          module: ArikeModule.purchases,
                          moduleTitle: 'Commandes Clients',
                          onNavigate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SalesOrdersPage(session: activeSession),
                            ),
                          ),
                        ),
                      ),
                    if (_canViewStockTransfer)
                      ModuleActionTile(
                        icon: Icons.swap_horiz_outlined,
                        title: 'Transferts inter-boutiques',
                        subtitle: 'Envoyer ou recevoir du stock entre vos boutiques',
                        isLocked: !multiShopGranted,
                        lockedBadgeText: 'PRO',
                        onTap: () => _openModuleIfAuthorized(
                          context,
                          module: ArikeModule.multiShop,
                          moduleTitle: 'Transferts Inter-boutiques',
                          onNavigate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StockTransferPage(),
                            ),
                          ),
                        ),
                      ),
                  ],

                  // 💰 Section 4: Finance & Outils
                  if (_canViewCashSessions ||
                      _canUseCalculators ||
                      _canViewFxExchange ||
                      _canViewDebts) ...[
                    const _SectionHeader(
                      title: 'Finance & Outils',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    if (_canViewCashSessions)
                      ModuleActionTile(
                        icon: Icons.point_of_sale_outlined,
                        title: 'Gestion de caisse',
                        subtitle: 'Ouverture, suivi et clôture de caisse',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CashSessionsPage(session: activeSession),
                          ),
                        ),
                      ),
                    if (_canViewFxExchange &&
                        !sl<FxWorkspaceModeController>().useFxPrimaryShell)
                      ModuleActionTile(
                        icon: Icons.currency_exchange,
                        title: 'Bureau de change',
                        subtitle: 'Opérations multi-devises, taux et caisses FX',
                        isLocked: !fxGranted,
                        lockedBadgeText: 'PRO',
                        onTap: () => _openModuleIfAuthorized(
                          context,
                          module: ArikeModule.fxExchange,
                          moduleTitle: 'Bureau de Change FX',
                          onNavigate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FxExchangePage(session: activeSession),
                            ),
                          ),
                        ),
                      ),
                    if (_canUseCalculators)
                      ModuleActionTile(
                        icon: Icons.calculate_outlined,
                        title: 'Calculateurs métiers',
                        subtitle: 'Calculateur de carrelage, peinture, béton, etc.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CalculatorsPage(session: activeSession),
                          ),
                        ),
                      ),
                    if (_canViewDebts)
                      ModuleActionTile(
                        icon: Icons.volunteer_activism_outlined,
                        title: 'Dettes pardonnées',
                        subtitle: 'Motif, date et montant annulé',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ForgivenDebtsPage(session: activeSession),
                          ),
                        ),
                      ),
                  ],

                  // ⚙️ Section 5: Administration & Sécurité
                  const _SectionHeader(
                    title: 'Administration & Assistance',
                    icon: Icons.settings_outlined,
                  ),
                  ModuleActionTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Aide & guides',
                    subtitle:
                        'Guides pas à pas pour chaque action de chaque module',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpHubPage()),
                    ),
                  ),
                  if (_canManageSettings)
                    ModuleActionTile(
                      icon: Icons.tune_outlined,
                      title: 'Paramètres',
                      subtitle: 'Boutique, sécurité, reçus et sauvegarde',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(session: activeSession),
                        ),
                      ),
                    ),
                  if (_canManageSync)
                    ModuleActionTile(
                      icon: Icons.sync_problem_outlined,
                      title: 'Conflits de synchronisation',
                      subtitle: 'Résoudre les différences local / cloud',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SyncConflictsPage(session: activeSession),
                        ),
                      ),
                    ),
                  if (_canManageAlerts)
                    ModuleActionTile(
                      icon: Icons.notifications_outlined,
                      title: 'Alertes',
                      subtitle: 'Stock, dettes, résumé du jour et sauvegarde',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              NotificationSettingsPage(session: activeSession),
                        ),
                      ),
                    ),
                  if (_canViewAudit)
                    ModuleActionTile(
                      icon: Icons.history_outlined,
                      title: 'Journal d\'audit',
                      subtitle: 'Actions sensibles — patron uniquement',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AuditJournalPage(session: activeSession),
                        ),
                      ),
                    ),
                  if (ProductionMessagePolicy.showServerConfiguration)
                    ModuleActionTile(
                      icon: Icons.cloud_outlined,
                      title: 'Connexion cloud (dev)',
                      subtitle: 'Configuration avancée du service en ligne',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ApiSettingsPage()),
                      ),
                    ),

                  // 🔐 Section 6: Session
                  const _SectionHeader(
                    title: 'Session & Compte',
                    icon: Icons.lock_person_outlined,
                  ),
                  ModuleActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Verrouiller',
                    subtitle: 'Retour à l\'écran PIN (session conservée)',
                    onTap: () =>
                        context.read<AuthBloc>().add(const AuthAppLockedRequested()),
                  ),
                  ModuleActionTile(
                    icon: Icons.logout_rounded,
                    title: 'Déconnexion',
                    subtitle: 'Quitter cette identité — reconnexion WhatsApp',
                    destructive: true,
                    onTap: () => _confirmLogout(context, activeSession),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  },
);
  }

  Future<void> _confirmChangeIdentity(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer d\'identité'),
        content: const Text(
          'Vous allez quitter l\'identité courante.\n\n'
          'Reconnectez-vous via WhatsApp pour choisir une autre entreprise '
          'ou un autre rôle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: Text(
          'Quitter l\'identité « ${session.user.name} » sur '
          '« ${session.shop.name} » ?\n\n'
          'Votre session sera fermée. Reconnectez-vous via WhatsApp pour '
          'accéder à nouveau à votre identité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xs,
        left: 4,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}
