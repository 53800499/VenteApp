import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/services/fx_calculation_service.dart';
import '../../domain/usecases/fx_exchange_usecases.dart';
import '../bloc/fx_exchange_bloc.dart';

class FxRatesHistoryPage extends StatefulWidget {
  const FxRatesHistoryPage({super.key});

  @override
  State<FxRatesHistoryPage> createState() => _FxRatesHistoryPageState();
}

class _FxRatesHistoryPageState extends State<FxRatesHistoryPage> {
  static const _calc = FxCalculationService();
  String? _filterCurrency;
  Future<List<FxRateSnapshot>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= () {
      ensureFxExchangeDependencies();
      final shopId = context.read<FxExchangeBloc>().shopId;
      return sl<ListFxRateHistory>()(shopId: shopId);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final future = _future;
    if (future == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des taux')),
      body: FutureBuilder<List<FxRateSnapshot>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 40),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Impossible de charger l’historique.',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          final rates = snapshot.data ?? const <FxRateSnapshot>[];
          if (rates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: _HistoryEmpty(
                  icon: Icons.price_change_outlined,
                  title: 'Aucun taux enregistré',
                  message:
                      'Les taux saisis apparaîtront ici dès qu’ils seront créés.',
                ),
              ),
            );
          }

          final currencies = rates
              .map((r) => r.quoteCurrency)
              .toSet()
              .toList()
            ..sort();
          final filtered = _filterCurrency == null
              ? rates
              : rates
                  .where((r) => r.quoteCurrency == _filterCurrency)
                  .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Filtrer par devise',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: AppSizes.filterChipRowHeight,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: const Text('Toutes'),
                        selected: _filterCurrency == null,
                        onSelected: (_) =>
                            setState(() => _filterCurrency = null),
                      ),
                    ),
                    ...currencies.map(
                      (code) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(code),
                          selected: _filterCurrency == code,
                          onSelected: (_) =>
                              setState(() => _filterCurrency = code),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${filtered.length} taux',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (filtered.isEmpty)
                const _HistoryEmpty(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Aucun résultat',
                  message: 'Changez le filtre pour voir d’autres taux.',
                )
              else
                ...filtered.map((rate) {
                  final buy = _calc.formatRateLabel(
                    rate.quoteCurrency,
                    FxRateFraction(
                      numerator: rate.buyRateNumerator,
                      denominator: rate.buyRateDenominator,
                    ),
                  );
                  final sell = _calc.formatRateLabel(
                    rate.quoteCurrency,
                    FxRateFraction(
                      numerator: rate.sellRateNumerator,
                      denominator: rate.sellRateDenominator,
                    ),
                  );
                  final when = DateFormat('dd/MM/yyyy HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(rate.effectiveAt),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: scheme.secondaryContainer,
                            child: Text(
                              rate.quoteCurrency,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rate.quoteCurrency,
                                  style:
                                      Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text('Achat · $buy'),
                                Text('Vente · $sell'),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  when,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: scheme.outline),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: AppSizes.lineHeightBody,
              ),
        ),
      ],
    );
  }
}
