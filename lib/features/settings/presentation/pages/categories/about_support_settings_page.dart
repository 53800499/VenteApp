import 'package:flutter/material.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../../help/presentation/pages/help_hub_page.dart';

class AboutSupportSettingsPage extends StatelessWidget {
  const AboutSupportSettingsPage({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('À Propos & Assistance'),
      ),
      body: AppPageContainer(
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
                  Icon(Icons.info_outline, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARIKE POS & Commerce',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Version 1.0.0 (Build 2026.08) — Solution intégrée de gestion commerciale offline-first.',
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
                    leading: const Icon(Icons.help_center_outlined),
                    title: const Text('Centre d\'aide & Guides pas à pas'),
                    subtitle: const Text('Tutoriels d\'utilisation pour tous les modules ARIKE'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HelpHubPage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.chat_outlined, color: Colors.green),
                    title: Text('Support WhatsApp'),
                    subtitle: Text('+229 01 00 00 00 00 (Service Client ARIKE)'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text('Licences Open Source & CGU'),
                    subtitle: Text('Mentions légales et politique de confidentialité'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
