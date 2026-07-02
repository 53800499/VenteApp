import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../app/pages/api_settings_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../audit/presentation/pages/audit_journal_page.dart';
import '../../../debts/presentation/pages/forgiven_debts_page.dart';
import '../../../notifications/presentation/pages/notification_settings_page.dart';
import '../../../sync/presentation/pages/sync_conflicts_page.dart';
import '../../../users/presentation/pages/user_list_page.dart';
import '../../../rbac/presentation/pages/roles_catalog_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
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

  bool get _canManageSync => session.user.role == UserRole.owner;

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
              if (_canManageShops)
                _MoreTile(
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
                _MoreTile(
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
                _MoreTile(
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
                _MoreTile(
                  icon: Icons.insights_outlined,
                  title: 'Statistiques',
                  subtitle: 'CA, bénéfice, top produits et recouvrement',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportsPage(session: activeSession),
                    ),
                  ),
                ),
              if (_canViewDebts)
                _MoreTile(
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
                _MoreTile(
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
                _MoreTile(
                  icon: Icons.sync_problem_outlined,
                  title: 'Conflits de synchronisation',
                  subtitle: 'Résoudre les différences local / serveur',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SyncConflictsPage(session: activeSession),
                    ),
                  ),
                ),
              if (_canManageAlerts)
                _MoreTile(
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
                _MoreTile(
                  icon: Icons.history_outlined,
                  title: 'Journal d\'audit',
                  subtitle: 'Actions sensibles — patron uniquement',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuditJournalPage(session: activeSession),
                    ),
                  ),
                ),
              _MoreTile(
                icon: Icons.dns_outlined,
                title: 'Connexion serveur',
                subtitle: 'Backend cloud ou adresse personnalisée',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ApiSettingsPage()),
                ),
              ),
              _MoreTile(
                icon: Icons.lock_outline_rounded,
                title: 'Verrouiller',
                subtitle: 'Retour à l\'écran PIN (session conservée)',
                onTap: () =>
                    context.read<AuthBloc>().add(const AuthAppLockedRequested()),
              ),
              _LogoutTile(
                shopName: activeSession.shop.name,
                onLogout: () => _confirmLogout(context, activeSession.shop.name),
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

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({
    required this.shopName,
    required this.onLogout,
  });

  final String shopName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.errorContainer,
          child: Icon(Icons.logout_rounded, color: colorScheme.error),
        ),
        title: Text(
          'Déconnexion',
          style: TextStyle(color: colorScheme.error),
        ),
        subtitle: const Text('Quitter le compte — reconnexion WhatsApp'),
        trailing: Icon(Icons.chevron_right, color: colorScheme.error),
        onTap: onLogout,
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(icon, color: colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
