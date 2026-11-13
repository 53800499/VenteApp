import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../bloc/settings_bloc.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../widgets/settings_confirmation.dart';

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
          if (config != null) {
            _replacementPolicy = config.commerce.replacementPolicy;
            _requirePreparationStep = config.commerce.requirePreparationStep;
            _allowPartialDeliveries = config.commerce.allowPartialDeliveries;
            _requireProofOfDelivery = config.commerce.requireProofOfDelivery;
          }

          return AppPageContainer(
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
                  child: SettingsSwitchListTile(
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
                    confirmationTitle: 'Activité Commandes & Livraisons',
                    confirmationMessage: isOrdersActive
                        ? 'Désactiver le module Commandes & Livraisons ? Les prises de commande différées seront bloquées.'
                        : 'Activer le module Commandes & Livraisons ?',
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
                        SettingsRadioListTile<String>(
                          title: const Text('Autorisé avec validation client / gérant'),
                          value: 'with_validation',
                          groupValue: _replacementPolicy,
                          confirmationTitle: 'Politique de remplacement',
                          confirmationMessage: 'Exiger la validation du client ou gérant avant tout remplacement d\'article ?',
                          onChanged: widget.canWrite
                              ? (v) {
                                  if (v != null) {
                                    context.read<SettingsBloc>().add(
                                          SettingsOptionUpdated(
                                            input: UpdateShopSettingsInput(replacementPolicy: v),
                                            successMessage: 'Remplacement d\'article : Validation requise.',
                                          ),
                                        );
                                  }
                                }
                              : null,
                        ),
                        SettingsRadioListTile<String>(
                          title: const Text('Autorisé automatiquement (Équivalent direct)'),
                          value: 'automatic',
                          groupValue: _replacementPolicy,
                          confirmationTitle: 'Politique de remplacement',
                          confirmationMessage: 'Autoriser automatiquement le remplacement par un produit équivalent direct ?',
                          onChanged: widget.canWrite
                              ? (v) {
                                  if (v != null) {
                                    context.read<SettingsBloc>().add(
                                          SettingsOptionUpdated(
                                            input: UpdateShopSettingsInput(replacementPolicy: v),
                                            successMessage: 'Remplacement d\'article : Automatique par équivalent.',
                                          ),
                                        );
                                  }
                                }
                              : null,
                        ),
                        SettingsRadioListTile<String>(
                          title: const Text('Désactivé'),
                          value: 'disabled',
                          groupValue: _replacementPolicy,
                          confirmationTitle: 'Politique de remplacement',
                          confirmationMessage: 'Désactiver tout remplacement d\'article dans les commandes ?',
                          onChanged: widget.canWrite
                              ? (v) {
                                  if (v != null) {
                                    context.read<SettingsBloc>().add(
                                          SettingsOptionUpdated(
                                            input: UpdateShopSettingsInput(replacementPolicy: v),
                                            successMessage: 'Remplacement d\'article : Désactivé.',
                                          ),
                                        );
                                  }
                                }
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
                      SettingsSwitchListTile(
                        title: const Text('Étape « Préparation » obligatoire'),
                        subtitle: const Text('Sépare la validation de la livraison effective'),
                        value: _requirePreparationStep,
                        confirmationTitle: 'Étape préparation',
                        confirmationMessage: _requirePreparationStep
                            ? 'Rendre l\'étape de préparation facultative ?'
                            : 'Exiger l\'étape de préparation avant validation de la livraison ?',
                        onChanged: widget.canWrite
                            ? (v) {
                                context.read<SettingsBloc>().add(
                                      SettingsOptionUpdated(
                                        input: UpdateShopSettingsInput(requirePreparationStep: v),
                                        successMessage: v
                                            ? 'Étape de préparation obligatoire activée.'
                                            : 'Étape de préparation rendue facultative.',
                                      ),
                                    );
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchListTile(
                        title: const Text('Autoriser les livraisons partielles'),
                        subtitle: const Text('Génère un reliquat pour les produits manquants'),
                        value: _allowPartialDeliveries,
                        confirmationTitle: 'Livraisons partielles',
                        confirmationMessage: _allowPartialDeliveries
                            ? 'Interdire les livraisons partielles (livraison intégrale requise) ?'
                            : 'Autoriser la livraison partielle avec reliquat pour les articles manquants ?',
                        onChanged: widget.canWrite
                            ? (v) {
                                context.read<SettingsBloc>().add(
                                      SettingsOptionUpdated(
                                        input: UpdateShopSettingsInput(allowPartialDeliveries: v),
                                        successMessage: v
                                            ? 'Livraisons partielles autorisées.'
                                            : 'Livraisons intégrales obligatoires.',
                                      ),
                                    );
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchListTile(
                        title: const Text('Exiger une preuve de livraison (Photo / Signature)'),
                        subtitle: const Text('Demande une confirmation à la réception'),
                        value: _requireProofOfDelivery,
                        confirmationTitle: 'Preuve de livraison',
                        confirmationMessage: _requireProofOfDelivery
                            ? 'Rendre la preuve de livraison facultative ?'
                            : 'Exiger une signature ou photo pour clore la livraison ?',
                        onChanged: widget.canWrite
                            ? (v) {
                                context.read<SettingsBloc>().add(
                                      SettingsOptionUpdated(
                                        input: UpdateShopSettingsInput(requireProofOfDelivery: v),
                                        successMessage: v
                                            ? 'Preuve de livraison obligatoire activée.'
                                            : 'Preuve de livraison rendue facultative.',
                                      ),
                                    );
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}
