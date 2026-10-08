import 'package:flutter/material.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../../subscription/presentation/pages/subscription_page.dart';

class SubscriptionPlanSettingsPage extends StatelessWidget {
  const SubscriptionPlanSettingsPage({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Forfait'),
      ),
      body: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      Icon(Icons.star_outline_rounded, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Abonnement ARIKE',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Gestion de votre formule d\'abonnement, quotas de boutiques et modules actifs.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.workspace_premium, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    title: const Text('Gérer mon forfait'),
                    subtitle: const Text('Renouveler, changer de formule ou voir les factures'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionPage(),
                      ),
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
