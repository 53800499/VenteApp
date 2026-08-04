import 'package:flutter/material.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';

class ProcurementSettingsPage extends StatefulWidget {
  const ProcurementSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<ProcurementSettingsPage> createState() => _ProcurementSettingsPageState();
}

class _ProcurementSettingsPageState extends State<ProcurementSettingsPage> {
  bool _requireReceptionValidation = true;
  bool _updateWeightedAverageCost = true;
  bool _createSupplierDebtAutomatically = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats & Fournisseurs'),
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
                  Icon(Icons.local_shipping_outlined, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approvisionnements & Factures',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Validation des réceptions de commande, calcul du coût unitaire moyen pondéré (PUMP) et dettes fournisseurs.',
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
                  SwitchListTile(
                    title: const Text('Validation obligatoire des réceptions'),
                    subtitle: const Text('Exige une vérification physique avant de faire entrer le stock'),
                    value: _requireReceptionValidation,
                    onChanged: widget.canWrite
                        ? (v) => setState(() => _requireReceptionValidation = v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Mettre à jour le coût unitaire moyen (PUMP)'),
                    subtitle: const Text('Recalcule automatiquement la valeur du stock à chaque réception'),
                    value: _updateWeightedAverageCost,
                    onChanged: widget.canWrite
                        ? (v) => setState(() => _updateWeightedAverageCost = v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Créer automatiquement une dette fournisseur'),
                    subtitle: const Text('Génère un reste à payer si la facture n\'est pas réglée au comptant'),
                    value: _createSupplierDebtAutomatically,
                    onChanged: widget.canWrite
                        ? (v) => setState(() => _createSupplierDebtAutomatically = v)
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
