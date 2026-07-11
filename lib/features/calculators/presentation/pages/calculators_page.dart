import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../sales/presentation/pages/new_sale_page.dart';
import '../bloc/calculators_bloc.dart';
import '../../domain/entities/calculator_entities.dart';
import '../../domain/calculator_registry.dart';
import '../models/calculation_intent.dart';
import 'tile_calculator_page.dart';
import 'paint_calculator_page.dart';
import 'concrete_calculator_page.dart';

class CalculatorsPage extends StatelessWidget {
  const CalculatorsPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CalculatorsBloc>()
        ..add(CalculatorsInitRequested(shopId: session.shop.id)),
      child: _CalculatorsView(session: session),
    );
  }
}

class _CalculatorsView extends StatelessWidget {
  const _CalculatorsView({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final isOwner = session.user.role == UserRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculateurs Métiers'),
        actions: [
          if (isOwner)
            BlocBuilder<CalculatorsBloc, CalculatorsState>(
              builder: (context, state) {
                return Switch(
                  value: state.isEnabled,
                  activeColor: AppColors.secondary,
                  onChanged: state.status == 'loading'
                      ? null
                      : (val) {
                          context.read<CalculatorsBloc>().add(
                                ToggleCalculatorsModuleRequested(
                                  shopId: session.shop.id,
                                  enabled: val,
                                ),
                              );
                        },
                );
              },
            ),
        ],
      ),
      body: BlocConsumer<CalculatorsBloc, CalculatorsState>(
        listenWhen: (prev, next) =>
            next.status == 'failure' &&
            next.errorMessage != null &&
            prev.errorMessage != next.errorMessage,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        builder: (context, state) {
          if (state.status == 'loading' && state.history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!state.isEnabled) {
            return _buildDisabledView(context, isOwner, state.errorMessage);
          }

          return _buildEnabledView(context, state);
        },
      ),
    );
  }

  Widget _buildDisabledView(
    BuildContext context,
    bool isOwner, [
    String? errorMessage,
  ]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calculate_outlined,
              size: 80,
              color: AppColors.onSurfaceMuted,
            ),
            const SizedBox(height: 24),
            const Text(
              'Module désactivé',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Les calculateurs métiers vous permettent d\'effectuer des estimations de chantiers (carrelage, peinture, béton) directement depuis vos fiches produits.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceMuted),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: errorMessage),
            ],
            if (isOwner) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<CalculatorsBloc>().add(
                        ToggleCalculatorsModuleRequested(
                          shopId: session.shop.id,
                          enabled: true,
                        ),
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.seed,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Activer le module'),
              ),
            ] else ...[
              const SizedBox(height: 24),
              const Text(
                'Veuillez contacter le responsable de la boutique pour activer ce module.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnabledView(BuildContext context, CalculatorsState state) {
    final list = CalculatorRegistry.instance.getAvailableCalculators();

    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<CalculatorsBloc>()
            .add(CalculatorsInitRequested(shopId: session.shop.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (state.errorMessage != null) ...[
            ErrorBanner(message: state.errorMessage!),
            const SizedBox(height: 12),
          ],
          const Text(
            'Choisissez un calculateur',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.seed,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return InkWell(
                onTap: () => _navigateToCalculator(context, item.type),
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIconData(item.icon),
                          size: 36,
                          color: AppColors.seed,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Historique des estimations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.seed,
            ),
          ),
          const SizedBox(height: 12),
          if (state.history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'Aucun calcul enregistré dans l\'historique.',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = state.history[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surface,
                      child: Icon(
                        _getIconDataForType(entry.calculatorType),
                        color: AppColors.seed,
                      ),
                    ),
                    title: Text(
                      entry.label ?? _getDefaultLabel(entry.calculatorType),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Créé le ${_formatTimestamp(entry.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _loadHistoryEntry(context, entry),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'grid_on':
        return Icons.grid_on;
      case 'format_paint':
        return Icons.format_paint;
      case 'layers':
        return Icons.layers;
      default:
        return Icons.calculate;
    }
  }

  IconData _getIconDataForType(String type) {
    switch (type) {
      case 'tile':
        return Icons.grid_on;
      case 'paint':
        return Icons.format_paint;
      case 'concrete':
        return Icons.layers;
      default:
        return Icons.calculate;
    }
  }

  String _getDefaultLabel(String type) {
    switch (type) {
      case 'tile':
        return 'Estimation Carrelage';
      case 'paint':
        return 'Estimation Peinture';
      case 'concrete':
        return 'Estimation Béton & Mortier';
      default:
        return 'Estimation';
    }
  }

  String _formatTimestamp(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _navigateToCalculator(BuildContext context, String type) async {
    final bloc = context.read<CalculatorsBloc>();
    final Widget? child = switch (type) {
      'tile' => TileCalculatorPage(session: session),
      'paint' => PaintCalculatorPage(session: session),
      'concrete' => ConcreteCalculatorPage(session: session),
      _ => null,
    };
    if (child == null) return;

    final intent = await Navigator.of(context).push<CalculationIntent>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: bloc, child: child),
      ),
    );
    if (!context.mounted || intent == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSalePage(
          session: session,
          calculationIntent: intent,
        ),
      ),
    );
  }

  Future<void> _loadHistoryEntry(
    BuildContext context,
    CalculatorHistoryEntry entry,
  ) async {
    final bloc = context.read<CalculatorsBloc>();
    final Widget? child = switch (entry.calculatorType) {
      'tile' => TileCalculatorPage(session: session, initialHistory: entry),
      'paint' => PaintCalculatorPage(session: session, initialHistory: entry),
      'concrete' =>
        ConcreteCalculatorPage(session: session, initialHistory: entry),
      _ => null,
    };
    if (child == null) return;

    final intent = await Navigator.of(context).push<CalculationIntent>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: bloc, child: child),
      ),
    );
    if (!context.mounted || intent == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSalePage(
          session: session,
          calculationIntent: intent,
        ),
      ),
    );
  }
}
