import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../app/pages/api_settings_page.dart';
import '../../../users/presentation/pages/user_list_page.dart';
import 'shop_list_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.session});

  final AuthSession session;

  bool get _canManageShops => session.user.role == UserRole.owner;

  bool get _canManageUsers => session.user.role == UserRole.owner;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final activeSession =
            state is AuthAuthenticated ? state.session : session;

        return ResponsivePage(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Plus',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
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
                  subtitle: 'Vendeurs, lecteurs et rôles',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserListPage(session: activeSession),
                    ),
                  ),
                ),
              _MoreTile(
                icon: Icons.dns_outlined,
                title: 'Connexion serveur',
                subtitle: 'Adresse IP du backend (téléphone physique)',
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
              Text(
                'Bientôt : paramètres, statistiques, sauvegarde',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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
          'Votre session en ligne sera fermée. Pour accéder à nouveau aux '
          'données serveur, reconnectez-vous avec votre PIN (internet requis).',
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
        subtitle: Text('Quitter $shopName'),
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
