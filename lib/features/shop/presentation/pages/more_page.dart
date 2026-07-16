import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/components/feature_ui.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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

  bool get _canViewCashSessions => PermissionGuard.can(
        session.user.permissions,
        Permission.cashSessionsRead,
      );

  bool get _canManageSync => session.user.role == UserRole.owner;

  bool get _canUseCalculators => PermissionGuard.can(
        session.user.permissions,
        Permission.calculatorsUse,
      );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final activeSession =
            state is AuthAuthenticated ? state.session : session;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
              ModuleActionTile(
                icon: Icons.menu_book_outlined,
                title: 'Aide & guides',
                subtitle:
                    'Guides pas à pas pour chaque action de chaque module',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpHubPage()),
                ),
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
              if (_canViewReports)
                ModuleActionTile(
                  icon: Icons.insights_outlined,
                  title: 'Statistiques',
                  subtitle: 'CA, bénéfice, top produits et recouvrement',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportsPage(session: activeSession),
                    ),
                  ),
                ),
              if (_canViewReports)
                ModuleActionTile(
                  icon: Icons.analytics_outlined,
                  title: 'Analyse des ventes',
                  subtitle: 'Prix pratiqués, produits vendus et écarts',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SalesAnalysisPage(session: activeSession),
                    ),
                  ),
                ),
              if (_canViewExpenses)
                ModuleActionTile(
                  icon: Icons.payments_outlined,
                  title: 'Dépenses',
                  subtitle: 'Charges, caisse et bénéfice réel',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExpensesPage(session: activeSession),
                    ),
                  ),
                ),
              if (_canViewProcurement)
                ModuleActionTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Approvisionnement',
                  subtitle: 'Commandes fournisseurs, réceptions et stocks',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProcurementPage(session: activeSession),
                    ),
                  ),
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
                subtitle: 'Quitter le compte — reconnexion WhatsApp',
                destructive: true,
                onTap: () => _confirmLogout(context, activeSession.shop.name),
              ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context, String shopName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: Text(
          'Quitter la boutique « $shopName » ?\n\n'
          'Votre session sera fermée. Reconnectez-vous via WhatsApp pour '
          'accéder à nouveau à votre compte.',
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
