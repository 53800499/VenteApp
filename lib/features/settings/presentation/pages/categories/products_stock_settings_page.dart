import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../domain/entities/settings_entities.dart';
import '../../bloc/settings_bloc.dart';

class ProductsStockSettingsPage extends StatefulWidget {
  const ProductsStockSettingsPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<ProductsStockSettingsPage> createState() => _ProductsStockSettingsPageState();
}

class _ProductsStockSettingsPageState extends State<ProductsStockSettingsPage> {
  String _negativeStockMode = 'warning'; // forbidden, warning, allowed
  int _alertThreshold = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits & Stock'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final config = state.configuration;
          if (config == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _alertThreshold = config.inventory.defaultAlertThreshold;

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
                      Icon(Icons.inventory_2_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestion des inventaires & alertes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Configuration du stock négatif, seuils d\'alerte et valorisation FIFO.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Negative Stock Policy Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Politique de stock négatif', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Détermine si une vente peut être effectuée en cas de rupture théorique.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        RadioListTile<String>(
                          title: const Text('Interdit'),
                          subtitle: const Text('Bloque la vente si la quantité est insuffisante'),
                          value: 'forbidden',
                          groupValue: _negativeStockMode,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _negativeStockMode = v!)
                              : null,
                        ),
                        RadioListTile<String>(
                          title: const Text('Autorisé avec avertissement (Recommandé)'),
                          subtitle: const Text('Permet la vente mais alerte le caissier'),
                          value: 'warning',
                          groupValue: _negativeStockMode,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _negativeStockMode = v!)
                              : null,
                        ),
                        RadioListTile<String>(
                          title: const Text('Autorisé sans avertissement'),
                          subtitle: const Text('Ventes fluides même avant saisie des approvisionnements'),
                          value: 'allowed',
                          groupValue: _negativeStockMode,
                          onChanged: widget.canWrite
                              ? (v) => setState(() => _negativeStockMode = v!)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Alert Threshold Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seuil d\'alerte par défaut', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Les produits sous ce seuil déclencheront une alerte de réapprovisionnement.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Seuil: $_alertThreshold unités'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: (widget.canWrite && _alertThreshold > 1)
                                  ? () {
                                      final newThreshold = _alertThreshold - 1;
                                      context.read<SettingsBloc>().add(
                                            SettingsThresholdChanged(newThreshold),
                                          );
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: widget.canWrite
                                  ? () {
                                      final newThreshold = _alertThreshold + 1;
                                      context.read<SettingsBloc>().add(
                                            SettingsThresholdChanged(newThreshold),
                                          );
                                    }
                                  : null,
                            ),
                          ],
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
