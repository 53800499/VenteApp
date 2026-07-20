import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/usecases/fx_exchange_usecases.dart';
import '../bloc/fx_exchange_bloc.dart';

class FxReportPage extends StatelessWidget {
  const FxReportPage({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context) {
    ensureFxExchangeDependencies();
    final shopId = context.read<FxExchangeBloc>().shopId;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapport journalier FX')),
      body: FutureBuilder(
        future: sl<GetFxDailyReport>()(shopId: shopId, sessionId: sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final report = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Session du ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(report.session.openedAt))}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Statut : ${report.session.status.label}'),
              Text(
                'Marge totale : ${formatFcfa(report.session.totalMarginFcfa)}',
              ),
              Text('Opérations : ${report.operations.length}'),
              const SizedBox(height: AppSpacing.md),
              Text('Soldes', style: Theme.of(context).textTheme.titleMedium),
              ...report.liveBalances.entries.map(
                (e) => Text('${e.key} : ${formatAmount(e.value, e.key)}'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Volume par devise',
                  style: Theme.of(context).textTheme.titleMedium),
              ...report.volumeByCurrency.entries.map(
                (e) => Text('${e.key} : ${formatAmount(e.value, e.key)}'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Opérations',
                  style: Theme.of(context).textTheme.titleMedium),
              ...report.operations.map(
                (op) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${op.operationType.label} · ${formatAmount(op.fromAmount, op.fromCurrency)} → ${formatAmount(op.toAmount, op.toCurrency)}',
                  ),
                  subtitle: Text('Marge ${formatFcfa(op.marginFcfa)}'),
                ),
              ),
              if (report.session.balances.any((b) => b.difference != null)) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Écarts de clôture',
                    style: Theme.of(context).textTheme.titleMedium),
                ...report.session.balances.where((b) => b.difference != null).map(
                      (b) => Text(
                        '${b.currencyCode} : attendu ${formatAmount(b.expectedBalance ?? 0, b.currencyCode)} · compté ${formatAmount(b.countedBalance ?? 0, b.currencyCode)} · écart ${formatAmount(b.difference ?? 0, b.currencyCode)}',
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}
