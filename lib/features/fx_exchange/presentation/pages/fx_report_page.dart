import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/usecases/fx_exchange_usecases.dart';
import '../bloc/fx_exchange_bloc.dart';
import '../widgets/fx_history_tiles.dart';

class FxReportPage extends StatelessWidget {
  const FxReportPage({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context) {
    ensureFxExchangeDependencies();
    final shopId = context.read<FxExchangeBloc>().shopId;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapport de session FX')),
      body: FutureBuilder<FxDailyReport>(
        future: sl<GetFxDailyReport>()(shopId: shopId, sessionId: sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final scheme = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 40),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Impossible de charger le rapport.',
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

          final report = snapshot.data!;
          final scheme = Theme.of(context).colorScheme;
          final session = report.session;
          final dateLabel = DateFormat('dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(session.openedAt),
          );
          final openedAt = DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(session.openedAt),
          );
          final closedAt = session.closedAt == null
              ? null
              : DateFormat('HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(session.closedAt!),
                );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Session du $dateLabel',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: session.status ==
                                    FxSessionStatus.closed
                                ? scheme.surfaceContainerHighest
                                : session.isPendingClose
                                    ? scheme.tertiaryContainer
                                    : scheme.primaryContainer,
                            label: Text(session.status.label),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        closedAt == null
                            ? 'Ouverte à $openedAt · ${report.operations.length} op.'
                            : 'Ouverte $openedAt → clôturée $closedAt · '
                                '${report.operations.length} op.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Marge totale',
                              value: formatFcfa(session.totalMarginFcfa),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatTile(
                              label: 'Opérations',
                              value: '${report.operations.length}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Soldes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (report.liveBalances.isEmpty)
                Text(
                  'Aucun solde disponible.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: report.liveBalances.entries
                      .map(
                        (e) => _MetricChip(
                          code: e.key,
                          value: formatAmount(e.value, e.key),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Volume par devise',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (report.volumeByCurrency.isEmpty)
                Text(
                  'Aucun volume enregistré.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: report.volumeByCurrency.entries
                      .map(
                        (e) => _MetricChip(
                          code: e.key,
                          value: formatAmount(e.value, e.key),
                        ),
                      )
                      .toList(),
                ),
              if (session.balances.any((b) => b.difference != null)) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Écarts de clôture',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...session.balances
                    .where((b) => b.difference != null)
                    .map((b) {
                  final expected = b.expectedBalance ?? 0;
                  final counted = b.countedBalance ?? 0;
                  final diff = b.difference ?? 0;
                  final ok = diff == 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: ok
                        ? null
                        : scheme.errorContainer.withValues(alpha: 0.45),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: ok
                            ? scheme.secondaryContainer
                            : scheme.errorContainer,
                        child: Text(
                          b.currencyCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ok
                                ? scheme.onSecondaryContainer
                                : scheme.onErrorContainer,
                          ),
                        ),
                      ),
                      title: Text(
                        ok
                            ? 'Écart OK'
                            : 'Écart ${diff > 0 ? '+' : ''}${formatAmount(diff, b.currencyCode)}',
                      ),
                      subtitle: Text(
                        'Attendu ${formatAmount(expected, b.currencyCode)} · '
                        'Compté ${formatAmount(counted, b.currencyCode)}',
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ventes et achats',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (report.operations.isEmpty)
                Text(
                  'Aucune opération sur cette session.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                )
              else
                ...report.operations.map(
                  (op) => FxOperationHistoryTile(
                    operation: op,
                    showFullDateTime: true,
                  ),
                ),
              if (report.movements.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Mouvements',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...report.movements.map(
                  (mv) => FxMovementHistoryTile(movement: mv),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.code, required this.value});

  final String code;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 148,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
