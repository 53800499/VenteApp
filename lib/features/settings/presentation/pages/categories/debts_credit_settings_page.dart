import 'package:flutter/material.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';

class DebtsCreditSettingsPage extends StatefulWidget {
  const DebtsCreditSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<DebtsCreditSettingsPage> createState() => _DebtsCreditSettingsPageState();
}

class _DebtsCreditSettingsPageState extends State<DebtsCreditSettingsPage> {
  int _defaultCreditLimit = 100000;
  bool _blockOverlimitClients = true;
  bool _warnBeforeDueDate = true;
  bool _requireReasonForForgiveness = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettes & Crédits'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                  Icon(Icons.handshake_outlined, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Politique de crédit client',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Plafonds de crédit autorisés, blocage automatique des impayés et rémissions de dettes.',
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
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plafond de crédit par défaut', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Montant maximal de créances autorisées pour un nouveau client : $_defaultCreditLimit FCFA',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: _defaultCreditLimit.toDouble(),
                      min: 10000,
                      max: 1000000,
                      divisions: 99,
                      label: '$_defaultCreditLimit FCFA',
                      onChanged: widget.canWrite
                          ? (v) => setState(() => _defaultCreditLimit = v.toInt())
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Bloquer les clients dépassant leur plafond'),
                    subtitle: const Text('Empêche la validation de nouvelles ventes à crédit'),
                    value: _blockOverlimitClients,
                    onChanged: widget.canWrite
                        ? (v) => setState(() => _blockOverlimitClients = v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Avertir 3 jours avant l\'échéance de la dette'),
                    subtitle: const Text('Envoie une notification dans l\'application et au gérant'),
                    value: _warnBeforeDueDate,
                    onChanged: widget.canWrite
                        ? (v) => setState(() => _warnBeforeDueDate = v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Exiger un motif et permission pour une remise de dette'),
                    subtitle: const Text('Permission requise : debts.forgive'),
                    value: _requireReasonForForgiveness,
                    onChanged: widget.canWrite
                        ? (v) => setState(() => _requireReasonForForgiveness = v)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
