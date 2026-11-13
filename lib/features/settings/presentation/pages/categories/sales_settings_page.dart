import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/components/app_page_container.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../bloc/settings_bloc.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../widgets/settings_confirmation.dart';

class SalesSettingsPage extends StatefulWidget {
  const SalesSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<SalesSettingsPage> createState() => _SalesSettingsPageState();
}

class _SalesSettingsPageState extends State<SalesSettingsPage> {
  bool _confirmBeforeValidation = true;
  bool _allowCreditSales = true;
  bool _autoPrintReceipt = false;
  bool _allowPriceModification = false;
  int _maxCancelDelayHours = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres des Ventes'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          final isSalesActive = config?.commerce.isModuleActive('SALES') ?? true;
          if (config != null) {
            _confirmBeforeValidation = config.commerce.confirmBeforeValidation;
            _allowCreditSales = config.commerce.allowCreditSales;
            _autoPrintReceipt = config.commerce.autoPrintReceipt;
            _allowPriceModification = config.commerce.allowPriceModification;
            _maxCancelDelayHours = config.commerce.maxCancelDelayHours;
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
                      Icon(Icons.shopping_cart_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comportement de la caisse',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Règles de validation des ventes, modification des prix, crédit et tickets.',
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
                  color: isSalesActive
                      ? theme.colorScheme.surface
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  child: SettingsSwitchListTile(
                    secondary: Icon(
                      Icons.power_settings_new,
                      color: isSalesActive ? Colors.green : theme.colorScheme.error,
                    ),
                    title: const Text(
                      'Activité du Module Ventes & Caisse',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isSalesActive
                          ? 'Module actif : la prise de commande et la caisse sont activées'
                          : 'Module désactivé : l\'enregistrement des nouvelles ventes est bloqué',
                    ),
                    value: isSalesActive,
                    confirmationTitle: 'Modifier l\'activité du module Ventes & Caisse',
                    confirmationMessage: isSalesActive
                        ? 'Êtes-vous sûr de vouloir désactiver le module Ventes & Caisse ? Les encaissements seront bloqués.'
                        : 'Êtes-vous sûr de vouloir activer le module Ventes & Caisse ?',
                    onChanged: widget.canWrite
                        ? (val) {
                            context.read<SettingsBloc>().add(
                                  SettingsModuleActivityToggled(
                                    moduleKey: 'SALES',
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
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    SettingsSwitchListTile(
                      title: const Text('Demander confirmation avant validation'),
                      subtitle: const Text('Affiche une boite de dialogue de récapitulatif'),
                      value: _confirmBeforeValidation,
                      confirmationTitle: 'Confirmation de vente',
                      confirmationMessage: _confirmBeforeValidation
                          ? 'Désactiver la boîte de récapitulatif avant validation de vente ?'
                          : 'Activer la boîte de récapitulatif avant validation de vente ?',
                      onChanged: widget.canWrite
                          ? (val) {
                              context.read<SettingsBloc>().add(
                                    SettingsOptionUpdated(
                                      input: UpdateShopSettingsInput(confirmBeforeValidation: val),
                                      successMessage: val
                                          ? 'Récapitulatif avant vente activé.'
                                          : 'Récapitulatif avant vente désactivé.',
                                    ),
                                  );
                            }
                          : null,
                    ),
                    const Divider(height: 1),
                    SettingsSwitchListTile(
                      title: const Text('Autoriser les ventes à crédit'),
                      subtitle: const Text('Permet de valider une vente avec un reste à payer'),
                      value: _allowCreditSales,
                      confirmationTitle: 'Ventes à crédit',
                      confirmationMessage: _allowCreditSales
                          ? 'Interdire les ventes à crédit ? Toutes les ventes devront être soldées au comptant.'
                          : 'Autoriser les ventes à crédit avec reste à payer ?',
                      onChanged: widget.canWrite
                          ? (val) {
                              context.read<SettingsBloc>().add(
                                    SettingsOptionUpdated(
                                      input: UpdateShopSettingsInput(allowCreditSales: val),
                                      successMessage: val
                                          ? 'Ventes à crédit autorisées.'
                                          : 'Ventes à crédit interdites.',
                                    ),
                                  );
                            }
                          : null,
                    ),
                    const Divider(height: 1),
                    SettingsSwitchListTile(
                      title: const Text('Imprimer automatiquement le reçu'),
                      subtitle: const Text('Lance l\'impression immédiatement après encaissement'),
                      value: _autoPrintReceipt,
                      confirmationTitle: 'Impression automatique',
                      confirmationMessage: _autoPrintReceipt
                          ? 'Désactiver l\'impression automatique des reçus après encaissement ?'
                          : 'Activer l\'impression automatique des reçus après encaissement ?',
                      onChanged: widget.canWrite
                          ? (val) {
                              context.read<SettingsBloc>().add(
                                    SettingsOptionUpdated(
                                      input: UpdateShopSettingsInput(autoPrintReceipt: val),
                                      successMessage: val
                                          ? 'Impression automatique activée.'
                                          : 'Impression automatique désactivée.',
                                    ),
                                  );
                            }
                          : null,
                    ),
                    const Divider(height: 1),
                    SettingsSwitchListTile(
                      title: const Text('Autoriser les vendeurs à modifier les prix'),
                      subtitle: const Text('Lier à la permission sales.price_override'),
                      value: _allowPriceModification,
                      confirmationTitle: 'Modification des prix',
                      confirmationMessage: _allowPriceModification
                          ? 'Interdire aux vendeurs la modification libre des prix de vente ?'
                          : 'Autoriser les vendeurs autorisés à ajuster les prix de vente ?',
                      onChanged: widget.canWrite
                          ? (val) {
                              context.read<SettingsBloc>().add(
                                    SettingsOptionUpdated(
                                      input: UpdateShopSettingsInput(allowPriceModification: val),
                                      successMessage: val
                                          ? 'Modification de prix autorisée.'
                                          : 'Modification de prix restreinte.',
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
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Annulations de vente', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Délai maximal d\'annulation d\'une vente validée : $_maxCancelDelayHours heures',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: _maxCancelDelayHours.toDouble(),
                      min: 1,
                      max: 72,
                      divisions: 71,
                      label: '$_maxCancelDelayHours h',
                      onChanged: widget.canWrite
                          ? (val) => setState(() => _maxCancelDelayHours = val.toInt())
                          : null,
                      onChangeEnd: widget.canWrite
                          ? (val) {
                              context.read<SettingsBloc>().add(
                                    SettingsOptionUpdated(
                                      input: UpdateShopSettingsInput(maxCancelDelayHours: val.toInt()),
                                      successMessage: 'Délai maximal d\'annulation fixé à ${val.toInt()}h.',
                                    ),
                                  );
                            }
                          : null,
                    ),
                  ],
                ),
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
