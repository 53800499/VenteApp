import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
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

  @override
  Widget build(BuildContext context) {
    ensureFxExchangeDependencies();
    final shopId = context.read<FxExchangeBloc>().shopId;

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des taux')),
      body: FutureBuilder(
        future: sl<ListFxRateHistory>()(shopId: shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rates = snapshot.data ?? [];
          if (rates.isEmpty) {
            return const Center(child: Text('Aucun taux enregistré.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: rates.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final rate = rates[index];
              return ListTile(
                title: Text(rate.quoteCurrency),
                subtitle: Text(
                  'Achat ${_calc.formatRateLabel(rate.quoteCurrency, FxRateFraction(numerator: rate.buyRateNumerator, denominator: rate.buyRateDenominator))}\n'
                  'Vente ${_calc.formatRateLabel(rate.quoteCurrency, FxRateFraction(numerator: rate.sellRateNumerator, denominator: rate.sellRateDenominator))}',
                ),
                trailing: Text(
                  DateFormat('dd/MM HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(rate.effectiveAt),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
