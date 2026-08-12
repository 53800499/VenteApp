import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../bloc/settings_bloc.dart';

class OrdersDeliveriesSettingsPage extends StatefulWidget {
  const OrdersDeliveriesSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<OrdersDeliveriesSettingsPage> createState() => _OrdersDeliveriesSettingsPageState();
}

class _OrdersDeliveriesSettingsPageState extends State<OrdersDeliveriesSettingsPage> {
  String _replacementPolicy = 'with_validation'; // with_validation, automatic, disabled
  bool _requirePreparationStep = true;
  bool _allowPartialDeliveries = true;
  bool _requireProofOfDelivery = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes & Livraisons'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          final isOrdersActive = config?.commerce.isModuleActive('ORDERS_DELIVERIES') ?? true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                      Icon(Icons.assignment_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Workflow des commandes clients',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Règles d\'acceptation, préparation, remplacements de produits et signatures à la livraison.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Module Activity Card
                Card(
                  color: isOrdersActive
                      ? theme.colorScheme.surface
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.power_settings_new,
                      color: isOrdersActive ? Colors.green : theme.colorScheme.error,
                    ),
                    title: const Text(
                      'Activité du Module Commandes & Livraisons',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isOrdersActive
                          ? 'Module actif : la prise de commande client et le suivi des livraisons sont ouverts'
                          : 'Module désactivé : la gestion des commandes différées et bons de livraison est masquée',
                    ),
                    value: isOrdersActive,
                    onChanged: widget.canWrite
                        ? (val) {
                            context.read<SettingsBloc>().add(
                                  SettingsModuleActivityToggled(
                                    moduleKey: 'ORDERS_DELIVERIES',
                                    enabled: val,
                                  ),
                                );
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Politique de remplacement', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Règle appliquée lorsqu\'un produit commandé est indisponible lors de la préparation.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        RadioListTile<String>(
                          title: const Text('Autorisé avec validation client / gérant'),
                          value: 'with_validation',
                          groupValue: _replacementPolicy,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _replacementPolicy = v!)
                              : null,
                        ),
                        RadioListTile<String>(
                          title: const Text('Autorisé automatiquement (Équivalent direct)'),
                          value: 'automatic',
                          groupValue: _replacementPolicy,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _replacementPolicy = v!)
                              : null,
                        ),
                        RadioListTile<String>(
                          title: const Text('Désactivé'),
                          value: 'disabled',
                          groupValue: _replacementPolicy,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _replacementPolicy = v!)
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
                        title: const Text('Étape « Préparation » obligatoire'),
                        subtitle: const Text('Sépare la validation de la livraison effective'),
                        value: _requirePreparationStep,
                        onChanged: widget.canWrite
                            ? (v) => setState(() => _requirePreparationStep = v)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Autoriser les livraisons partielles'),
                        subtitle: const Text('Génère un reliquat pour les produits manquants'),
                        value: _allowPartialDeliveries,
                        onChanged: widget.canWrite
                            ? (v) => setState(() => _allowPartialDeliveries = v)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Exiger une preuve de livraison (Photo / Signature)'),
                        subtitle: const Text('Demande une confirmation à la réception'),
                        value: _requireProofOfDelivery,
                        onChanged: widget.canWrite
                            ? (v) => setState(() => _requireProofOfDelivery = v)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
