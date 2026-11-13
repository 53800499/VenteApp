import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../bloc/settings_bloc.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../widgets/settings_confirmation.dart';

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
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          final isDebtsActive = config?.commerce.isModuleActive('DEBTS') ?? true;
          if (config != null) {
            _defaultCreditLimit = config.commerce.defaultCreditLimit;
            _blockOverlimitClients = config.commerce.blockOverlimitClients;
            _warnBeforeDueDate = config.commerce.warnBeforeDueDate;
            _requireReasonForForgiveness = config.commerce.requireReasonForForgiveness;
          }

          return AppPageContainer(
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

                // Module Activity Card
                Card(
                  color: isDebtsActive
                      ? theme.colorScheme.surface
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  child: SettingsSwitchListTile(
                    secondary: Icon(
                      Icons.power_settings_new,
                      color: isDebtsActive ? Colors.green : theme.colorScheme.error,
                    ),
                    title: const Text(
                      'Activité du Module Dettes & Crédits',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isDebtsActive
                          ? 'Module actif : les ventes à crédit et suivis de rémission/remboursements sont ouverts'
                          : 'Module désactivé : les fonctions de crédit et carnets de dettes sont désactivés',
                    ),
                    value: isDebtsActive,
                    confirmationTitle: 'Activité Dettes & Crédits',
                    confirmationMessage: isDebtsActive
                        ? 'Désactiver le module Dettes & Crédits ? Le carnet de dettes et les ventes à crédit seront désactivés.'
                        : 'Activer le module Dettes & Crédits ?',
                    onChanged: widget.canWrite
                        ? (val) {
                            context.read<SettingsBloc>().add(
                                  SettingsModuleActivityToggled(
                                    moduleKey: 'DEBTS',
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
                          onChangeEnd: widget.canWrite
                              ? (v) {
                                  context.read<SettingsBloc>().add(
                                        SettingsOptionUpdated(
                                          input: UpdateShopSettingsInput(defaultCreditLimit: v.toInt()),
                                          successMessage: 'Plafond de crédit par défaut fixé à ${v.toInt()} FCFA.',
                                        ),
                                      );
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
                        title: const Text('Bloquer les clients dépassant leur plafond'),
                        subtitle: const Text('Empêche la validation de nouvelles ventes à crédit'),
                        value: _blockOverlimitClients,
                        confirmationTitle: 'Blocage de dépassement de plafond',
                        confirmationMessage: _blockOverlimitClients
                            ? 'Désactiver le blocage automatique pour les clients qui dépassent le plafond ?'
                            : 'Bloquer automatiquement les ventes à crédit si le client dépasse son plafond ?',
                        onChanged: widget.canWrite
                            ? (v) {
                                context.read<SettingsBloc>().add(
                                      SettingsOptionUpdated(
                                        input: UpdateShopSettingsInput(blockOverlimitClients: v),
                                        successMessage: v
                                            ? 'Blocage de dépassement de plafond activé.'
                                            : 'Blocage de dépassement de plafond désactivé.',
                                      ),
                                    );
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchListTile(
                        title: const Text('Avertir 3 jours avant l\'échéance de la dette'),
                        subtitle: const Text('Envoie une notification dans l\'application et au gérant'),
                        value: _warnBeforeDueDate,
                        confirmationTitle: 'Alerte d\'échéance',
                        confirmationMessage: _warnBeforeDueDate
                            ? 'Désactiver le rappel d\'échéance à 3 jours ?'
                            : 'Activer les rappels d\'échéance 3 jours à l\'avance ?',
                        onChanged: widget.canWrite
                            ? (v) {
                                context.read<SettingsBloc>().add(
                                      SettingsOptionUpdated(
                                        input: UpdateShopSettingsInput(warnBeforeDueDate: v),
                                        successMessage: v
                                            ? 'Alerte avant échéance activée.'
                                            : 'Alerte avant échéance désactivée.',
                                      ),
                                    );
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchListTile(
                        title: const Text('Exiger un motif et permission pour une remise de dette'),
                        subtitle: const Text('Permission requise : debts.forgive'),
                        value: _requireReasonForForgiveness,
                        confirmationTitle: 'Contrôle des remises',
                        confirmationMessage: _requireReasonForForgiveness
                            ? 'Permettre les remises de dette sans justification obligatoire ?'
                            : 'Exiger obligatoirement un motif et la permission appropriée pour toute remise de dette ?',
                        onChanged: widget.canWrite
                            ? (v) {
                                context.read<SettingsBloc>().add(
                                      SettingsOptionUpdated(
                                        input: UpdateShopSettingsInput(requireReasonForForgiveness: v),
                                        successMessage: v
                                            ? 'Justification obligatoire pour remise de dette activée.'
                                            : 'Justification de remise de dette assouplie.',
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
