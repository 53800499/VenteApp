import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/services/fx_calculation_service.dart';
import '../../domain/usecases/fx_exchange_usecases.dart';
import '../fx_exchange_navigation.dart';
import '../bloc/fx_exchange_bloc.dart';
import 'fx_close_session_page.dart';
import 'fx_movement_page.dart';
import 'fx_new_operation_page.dart';
import 'fx_rates_history_page.dart';
import 'fx_rates_page.dart';
import 'fx_report_page.dart';
import 'fx_settings_page.dart';

class FxExchangePage extends StatelessWidget {
  const FxExchangePage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    ensureFxExchangeDependencies();

    return BlocProvider(
      create: (_) => FxExchangeBloc(
        session: session,
        isModuleEnabled: sl<IsFxModuleEnabled>(),
        toggleModule: sl<ToggleFxModule>(),
        listCurrencies: sl<ListFxCurrencies>(),
        listShopCurrencies: sl<ListFxShopCurrencies>(),
        upsertShopCurrencies: sl<UpsertFxShopCurrencies>(),
        createRate: sl<CreateFxRate>(),
        listLatestRates: sl<ListFxLatestRates>(),
        findOpenSession: sl<FindOpenFxSession>(),
        listSessions: sl<ListFxSessions>(),
        getLiveBalances: sl<GetFxLiveBalances>(),
        openSession: sl<OpenFxSession>(),
        closeSession: sl<CloseFxSession>(),
        createOperation: sl<CreateFxOperation>(),
        createMovement: sl<CreateFxMovement>(),
        listOperations: sl<ListFxOperations>(),
        listMovements: sl<ListFxMovements>(),
        syncFromRemote: sl<SyncFxExchangeFromRemote>(),
      )..add(const FxExchangeLoadRequested()),
      child: const _FxExchangeView(),
    );
  }
}

class _FxExchangeView extends StatelessWidget {
  const _FxExchangeView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FxExchangeBloc>();
    final perms = bloc.session.user.permissions;
    final canConfigure =
        PermissionGuard.can(perms, Permission.fxExchangeConfigure);
    final canRates = PermissionGuard.can(perms, Permission.fxExchangeRates);
    final canOpen =
        PermissionGuard.can(perms, Permission.fxExchangeSessionOpen);
    final canClose =
        PermissionGuard.can(perms, Permission.fxExchangeSessionClose);
    final canOperate =
        PermissionGuard.can(perms, Permission.fxExchangeOperate);
    final canReport =
        PermissionGuard.can(perms, Permission.fxExchangeReport);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bureau de change'),
        actions: [
          if (canConfigure)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => openFxSubPage(context, const FxSettingsPage()),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<FxExchangeBloc>()
                .add(const FxExchangeRefreshRequested()),
          ),
        ],
      ),
      body: BlocConsumer<FxExchangeBloc, FxExchangeState>(
        listenWhen: (p, c) =>
            c.errorMessage != p.errorMessage ||
            c.successMessage != p.successMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.successMessage!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == FxExchangeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!state.moduleEnabled) {
            return Column(
              children: [
                if (state.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: _ModuleDisabledView(
                    canConfigure: canConfigure,
                    isSubmitting: state.isSubmitting,
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<FxExchangeBloc>()
                  .add(const FxExchangeRefreshRequested());
              await context.read<FxExchangeBloc>().stream.firstWhere(
                    (s) => !s.isRefreshing,
                  );
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (state.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),
                _RatesSummaryCard(
                  rates: state.latestRates,
                  canEdit: canRates,
                ),
                const SizedBox(height: AppSpacing.md),
                if (state.openSession == null)
                  _OpenSessionCard(
                    canOpen: canOpen,
                    shopCurrencies: state.shopCurrencies,
                    latestRates: state.latestRates,
                  )
                else
                  _ActiveSessionCard(
                    session: state.openSession!,
                    liveBalances: state.liveBalances,
                    operations: state.operations,
                    movements: state.movements,
                    canOperate: canOperate,
                    canClose: canClose,
                    canReport: canReport,
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Historique des sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (state.history.isEmpty)
                  const Text('Aucune session clôturée.')
                else
                  ...state.history.map(
                    (row) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(row.openedAt),
                        ),
                      ),
                      subtitle: Text(
                        '${row.operationCount} op. · Marge ${formatFcfa(row.totalMarginFcfa)}',
                      ),
                      trailing: Chip(
                        label: Text(row.status.label),
                      ),
                      onTap: canReport
                          ? () => openFxSubPage(
                                context,
                                FxReportPage(sessionId: row.id),
                              )
                          : null,
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

class _ModuleDisabledView extends StatelessWidget {
  const _ModuleDisabledView({
    required this.canConfigure,
    required this.isSubmitting,
  });

  final bool canConfigure;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.currency_exchange, size: 64),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Le module Bureau de change n\'est pas activé.',
              textAlign: TextAlign.center,
            ),
            if (canConfigure) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () => context.read<FxExchangeBloc>().add(
                          const FxModuleToggleRequested(enabled: true),
                        ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Activer le module'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatesSummaryCard extends StatelessWidget {
  const _RatesSummaryCard({
    required this.rates,
    required this.canEdit,
  });

  final List<FxRateSnapshot> rates;
  final bool canEdit;
  static const _calc = FxCalculationService();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Taux du jour',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (canEdit)
                  TextButton(
                    onPressed: () =>
                        openFxSubPage(context, const FxRatesPage()),
                    child: const Text('Modifier'),
                  ),
                TextButton(
                  onPressed: () =>
                      openFxSubPage(context, const FxRatesHistoryPage()),
                  child: const Text('Historique'),
                ),
              ],
            ),
            if (rates.isEmpty)
              const Text('Aucun taux défini. Saisissez les taux avant d\'ouvrir.')
            else
              ...rates.map(
                (rate) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '${rate.quoteCurrency} · Achat ${_calc.formatRateLabel(rate.quoteCurrency, FxRateFraction(numerator: rate.buyRateNumerator, denominator: rate.buyRateDenominator))} · Vente ${_calc.formatRateLabel(rate.quoteCurrency, FxRateFraction(numerator: rate.sellRateNumerator, denominator: rate.sellRateDenominator))}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OpenSessionCard extends StatelessWidget {
  const _OpenSessionCard({
    required this.canOpen,
    required this.shopCurrencies,
    required this.latestRates,
  });

  final bool canOpen;
  final List<FxShopCurrency> shopCurrencies;
  final List<FxRateSnapshot> latestRates;

  @override
  Widget build(BuildContext context) {
    final foreignEnabled = shopCurrencies
        .where((c) => c.enabled && c.currencyCode != fxBaseCurrency)
        .length;
    final ratesReady = latestRates.length >= foreignEnabled && foreignEnabled > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Démarrer la journée',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ratesReady
                  ? 'Saisissez les soldes initiaux par devise.'
                  : 'Définissez d\'abord les taux du jour pour toutes les devises actives.',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: canOpen && ratesReady
                  ? () => _showOpenDialog(context)
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Ouvrir la session FX'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOpenDialog(BuildContext context) async {
    final bloc = context.read<FxExchangeBloc>();
    final controllers = <String, TextEditingController>{};

    for (final sc in bloc.state.shopCurrencies.where((c) => c.enabled)) {
      controllers[sc.currencyCode] = TextEditingController(text: '0');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ouverture session FX'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries
                .map(
                  (e) => TextField(
                    controller: e.value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Solde initial ${e.key}',
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final balances = <String, int>{};
    for (final entry in controllers.entries) {
      balances[entry.key] =
          int.tryParse(entry.value.text.replaceAll(' ', '')) ?? 0;
    }

    bloc.add(FxOpenSessionRequested(openingBalances: balances));
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.session,
    required this.liveBalances,
    required this.operations,
    required this.movements,
    required this.canOperate,
    required this.canClose,
    required this.canReport,
  });

  final FxSession session;
  final Map<String, int> liveBalances;
  final List<FxOperation> operations;
  final List<FxMovement> movements;
  final bool canOperate;
  final bool canClose;
  final bool canReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session en cours',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Ouverte le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(session.openedAt))}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Marge cumulée : ${formatFcfa(session.totalMarginFcfa)}'),
            Text('Opérations : ${session.operationCount}'),
            const SizedBox(height: AppSpacing.md),
            Text('Soldes live', style: Theme.of(context).textTheme.titleSmall),
            ...liveBalances.entries.map(
              (e) => Text('${e.key} : ${formatAmount(e.value, e.key)}'),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (canOperate)
                  FilledButton.icon(
                    onPressed: () =>
                        openFxSubPage(context, const FxNewOperationPage()),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Opération'),
                  ),
                if (canOperate)
                  OutlinedButton.icon(
                    onPressed: () =>
                        openFxSubPage(context, const FxMovementPage()),
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Mouvement'),
                  ),
                if (canClose)
                  OutlinedButton.icon(
                    onPressed: () =>
                        openFxSubPage(context, const FxCloseSessionPage()),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Clôturer'),
                  ),
                if (canReport)
                  OutlinedButton.icon(
                    onPressed: () => openFxSubPage(
                      context,
                      FxReportPage(sessionId: session.id),
                    ),
                    icon: const Icon(Icons.summarize_outlined),
                    label: const Text('Rapport'),
                  ),
              ],
            ),
            if (operations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Dernières opérations',
                  style: Theme.of(context).textTheme.titleSmall),
              ...operations.take(5).map(
                    (op) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        '${op.operationType.label} · ${formatAmount(op.fromAmount, op.fromCurrency)} → ${formatAmount(op.toAmount, op.toCurrency)}',
                      ),
                      subtitle: Text(
                        'Marge ${formatFcfa(op.marginFcfa)} · ${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(op.createdAt))}',
                      ),
                    ),
                  ),
            ],
            if (movements.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Derniers mouvements',
                  style: Theme.of(context).textTheme.titleSmall),
              ...movements.take(3).map(
                    (mv) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        '${mv.movementType.label} ${formatAmount(mv.amount, mv.currencyCode)}',
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
