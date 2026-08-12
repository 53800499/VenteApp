import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../bloc/settings_bloc.dart';

class CashRegisterSettingsPage extends StatefulWidget {
  const CashRegisterSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<CashRegisterSettingsPage> createState() => _CashRegisterSettingsPageState();
}

class _CashRegisterSettingsPageState extends State<CashRegisterSettingsPage> {
  bool _requireOpeningSession = true;
  int _allowedDiscrepancyFcfa = 500;
  String _discrepancyAction = 'reason'; // reason, admin_approval, block_closing

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Caisse'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          final isCashActive = config?.commerce.isModuleActive('CASH_SESSIONS') ?? true;

          return SingleChildScrollView(
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
                      Icon(Icons.point_of_sale_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contrôle de Caisse & Écarts',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Règles d\'ouverture/clôture de session, solde de départ et tolérances d\'écart de caisse.',
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
                  color: isCashActive
                      ? theme.colorScheme.surface
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.power_settings_new,
                      color: isCashActive ? Colors.green : theme.colorScheme.error,
                    ),
                    title: const Text(
                      'Activité du Module Sessions de Caisse',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isCashActive
                          ? 'Module actif : l\'ouverture et clôture de session de caisse avec comptage sont actives'
                          : 'Module désactivé : le suivi strict des entrées/sorties de fond de caisse est restreint',
                    ),
                    value: isCashActive,
                    onChanged: widget.canWrite
                        ? (val) {
                            context.read<SettingsBloc>().add(
                                  SettingsModuleActivityToggled(
                                    moduleKey: 'CASH_SESSIONS',
                                    enabled: val,
                                  ),
                                );
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Ouverture et clôture de caisse obligatoires'),
                        subtitle: const Text('Bloque les encaissements si aucune session n\'est ouverte'),
                        value: _requireOpeningSession,
                        onChanged: widget.canWrite
                            ? (v) => setState(() => _requireOpeningSession = v)
                            : null,
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
                        Text('Écart de caisse toléré', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tolérance maximale sur le solde de clôture : $_allowedDiscrepancyFcfa FCFA',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: _allowedDiscrepancyFcfa.toDouble(),
                          min: 0,
                          max: 5000,
                          divisions: 50,
                          label: '$_allowedDiscrepancyFcfa FCFA',
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _allowedDiscrepancyFcfa = v.toInt())
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('En cas de dépassement de l\'écart :', style: theme.textTheme.bodyMedium),
                        RadioListTile<String>(
                          title: const Text('Demander un motif détaillé au caissier'),
                          value: 'reason',
                          groupValue: _discrepancyAction,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _discrepancyAction = v!)
                              : null,
                        ),
                        RadioListTile<String>(
                          title: const Text('Demander la validation immédiate du patron/gérant'),
                          value: 'admin_approval',
                          groupValue: _discrepancyAction,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _discrepancyAction = v!)
                              : null,
                        ),
                        RadioListTile<String>(
                          title: const Text('Bloquer la clôture tant que l\'erreur persiste'),
                          value: 'block_closing',
                          groupValue: _discrepancyAction,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _discrepancyAction = v!)
                              : null,
                        ),
                      ],
                    ),
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
