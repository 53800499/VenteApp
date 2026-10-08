import 'package:flutter/material.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../../rbac/presentation/pages/roles_catalog_page.dart';
import '../../../../users/presentation/pages/user_list_page.dart';

class TeamAccessSettingsPage extends StatelessWidget {
  const TeamAccessSettingsPage({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Équipe & Accès'),
      ),
      body: AppPageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_alt_outlined, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administration des collaborateurs',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Gestion des utilisateurs, des rôles, permissions et des accès aux boutiques (shop_access).',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.group_outlined, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    title: const Text('Utilisateurs et employés'),
                    subtitle: const Text('Inviter, modifier, activer/désactiver des comptes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserListPage(session: session),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(Icons.admin_panel_settings_outlined,
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                    title: const Text('Rôles & Permissions'),
                    subtitle: const Text('Catalogue des rôles métier et matrice des droits'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RolesCatalogPage(session: session),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Politique d\'accès unifiée',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Dans l\'architecture unifiée d\'ARIKE, l\'accès d\'un employé à une boutique s\'appuie sur son affectation (shop_access). La boutique par défaut de la session est personnalisable par l\'utilisateur.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
