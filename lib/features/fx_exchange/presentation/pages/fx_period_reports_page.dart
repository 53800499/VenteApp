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

enum _FxPeriodMode { daily, monthly, custom }

class FxPeriodReportsPage extends StatefulWidget {
  const FxPeriodReportsPage({super.key});

  @override
  State<FxPeriodReportsPage> createState() => _FxPeriodReportsPageState();
}

class _FxPeriodReportsPageState extends State<FxPeriodReportsPage> {
  _FxPeriodMode _mode = _FxPeriodMode.daily;
  DateTime _day = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTimeRange _custom = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  Future<FxPeriodReport>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  (int fromMs, int toMs) _range() {
    switch (_mode) {
      case _FxPeriodMode.daily:
        final start = DateTime(_day.year, _day.month, _day.day);
        final end = start.add(const Duration(days: 1));
        return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
      case _FxPeriodMode.monthly:
        final start = DateTime(_month.year, _month.month);
        final end = DateTime(_month.year, _month.month + 1);
        return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
      case _FxPeriodMode.custom:
        final start = DateTime(
          _custom.start.year,
          _custom.start.month,
          _custom.start.day,
        );
        final end = DateTime(
          _custom.end.year,
          _custom.end.month,
          _custom.end.day,
        ).add(const Duration(days: 1));
        return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    }
  }

  String _titleForRange() {
    switch (_mode) {
      case _FxPeriodMode.daily:
        return DateFormat('dd/MM/yyyy').format(_day);
      case _FxPeriodMode.monthly:
        return DateFormat('MMMM yyyy').format(_month);
      case _FxPeriodMode.custom:
        return '${DateFormat('dd/MM/yyyy').format(_custom.start)}'
            ' → ${DateFormat('dd/MM/yyyy').format(_custom.end)}';
    }
  }

  void _reload() {
    final shopId = context.read<FxExchangeBloc>().shopId;
    final (fromMs, toMs) = _range();
    setState(() {
      _future = sl<GetFxPeriodReport>()(
        shopId: shopId,
        fromMs: fromMs,
        toMs: toMs,
      );
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _day = picked);
    _reload();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Choisir un mois',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month));
    _reload();
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _custom,
    );
    if (picked == null) return;
    setState(() => _custom = picked);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    ensureFxExchangeDependencies();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapports FX')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_FxPeriodMode>(
                  segments: const [
                    ButtonSegment(
                      value: _FxPeriodMode.daily,
                      label: Text('Journalier'),
                      icon: Icon(Icons.today_outlined),
                    ),
                    ButtonSegment(
                      value: _FxPeriodMode.monthly,
                      label: Text('Mensuel'),
                      icon: Icon(Icons.calendar_month_outlined),
                    ),
                    ButtonSegment(
                      value: _FxPeriodMode.custom,
                      label: Text('Perso.'),
                      icon: Icon(Icons.date_range_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) {
                    setState(() => _mode = value.first);
                    _reload();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: switch (_mode) {
                    _FxPeriodMode.daily => _pickDay,
                    _FxPeriodMode.monthly => _pickMonth,
                    _FxPeriodMode.custom => _pickCustom,
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(_titleForRange()),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<FxPeriodReport>(
              future: _future,
              builder: (context, snapshot) {
                if (_future == null ||
                    snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('${snapshot.error}'),
                    ),
                  );
                }
                final report = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Période · ${_titleForRange()}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${report.sessionCount} session(s) · '
                              '${report.operations.length} op. · '
                              '${report.movements.length} mouvement(s)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatTile(
                                    label: 'Marge totale',
                                    value: formatFcfa(report.totalMarginFcfa),
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
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Volume par devise',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (report.volumeByCurrency.isEmpty)
                      Text(
                        'Aucun volume sur cette période.',
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
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Ventes et achats',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (report.operations.isEmpty)
                      Text(
                        'Aucune opération.',
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
          ),
        ],
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
