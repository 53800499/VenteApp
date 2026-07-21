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
import '../../../help/presentation/widgets/module_help_button.dart';
import '../fx_exchange_navigation.dart';
import '../bloc/fx_exchange_bloc.dart';
import '../fx_workspace_mode_controller.dart';
import 'fx_close_session_page.dart';
import 'fx_movement_page.dart';
import 'fx_new_operation_page.dart';
import 'fx_rates_history_page.dart';
import 'fx_rates_page.dart';
import 'fx_period_reports_page.dart';
import 'fx_report_page.dart';
import 'fx_settings_page.dart';
import '../widgets/fx_history_tiles.dart';

class FxExchangePage extends StatelessWidget {
  const FxExchangePage({
    super.key,
    required this.session,
    this.embeddedInShell = false,
  });

  final AuthSession session;
  /// True quand l'écran est l'onglet racine (pas de push Navigator).
  final bool embeddedInShell;

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
        listSessionRates: sl<ListFxSessionRates>(),
        findOpenSession: sl<FindOpenFxSession>(),
        listSessions: sl<ListFxSessions>(),
        getLiveBalances: sl<GetFxLiveBalances>(),
        openSession: sl<OpenFxSession>(),
        closeSession: sl<CloseFxSession>(),
        confirmCloseSession: sl<ConfirmFxSessionClose>(),
        cancelPendingClose: sl<CancelFxPendingClose>(),
        createOperation: sl<CreateFxOperation>(),
        createMovement: sl<CreateFxMovement>(),
        listOperations: sl<ListFxOperations>(),
        listMovements: sl<ListFxMovements>(),
        getCustomerRequiredAboveFcfa: sl<GetFxCustomerRequiredAboveFcfa>(),
        setCustomerRequiredAboveFcfa: sl<SetFxCustomerRequiredAboveFcfa>(),
        getPrimaryWorkspace: sl<GetFxPrimaryWorkspace>(),
        setPrimaryWorkspace: sl<SetFxPrimaryWorkspace>(),
        workspaceMode: sl<FxWorkspaceModeController>(),
        syncFromRemote: sl<SyncFxExchangeFromRemote>(),
      )..add(const FxExchangeLoadRequested()),
      child: _FxExchangeView(embeddedInShell: embeddedInShell),
    );
  }
}

class _FxExchangeView extends StatelessWidget {
  const _FxExchangeView({required this.embeddedInShell});

  final bool embeddedInShell;

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
      appBar: embeddedInShell
          ? null
          : AppBar(
              title: const Text('Bureau de change'),
              actions: [
                const ModuleHelpButton(articleId: 'fx_exchange'),
                if (canReport)
                  IconButton(
                    tooltip: 'Rapports',
                    icon: const Icon(Icons.assessment_outlined),
                    onPressed: () =>
                        openFxSubPage(context, const FxPeriodReportsPage()),
                  ),
                if (canConfigure)
                  IconButton(
                    tooltip: 'Configuration',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () =>
                        openFxSubPage(context, const FxSettingsPage()),
                  ),
                IconButton(
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context
                      .read<FxExchangeBloc>()
                      .add(const FxExchangeRefreshRequested()),
                ),
              ],
            ),
      floatingActionButton: BlocBuilder<FxExchangeBloc, FxExchangeState>(
        buildWhen: (p, c) =>
            p.openSession != c.openSession ||
            p.moduleEnabled != c.moduleEnabled,
        builder: (context, state) {
          final session = state.openSession;
          if (!state.moduleEnabled ||
              session == null ||
              session.isPendingClose ||
              !canOperate) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () =>
                openFxSubPage(context, const FxNewOperationPage()),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Opération'),
          );
        },
      ),
      body: Column(
        children: [
          if (embeddedInShell)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bureau de change',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const ModuleHelpButton(articleId: 'fx_exchange'),
                    if (canReport)
                      IconButton(
                        tooltip: 'Rapports',
                        icon: const Icon(Icons.assessment_outlined),
                        onPressed: () => openFxSubPage(
                          context,
                          const FxPeriodReportsPage(),
                        ),
                      ),
                    if (canConfigure)
                      IconButton(
                        tooltip: 'Configuration',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => openFxSubPage(
                          context,
                          const FxSettingsPage(),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Actualiser',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => context
                          .read<FxExchangeBloc>()
                          .add(const FxExchangeRefreshRequested()),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: BlocConsumer<FxExchangeBloc, FxExchangeState>(
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                96,
              ),
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
                    canRates: canRates,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Historique',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (canReport)
                      TextButton.icon(
                        onPressed: () => openFxSubPage(
                          context,
                          const FxPeriodReportsPage(),
                        ),
                        icon: const Icon(Icons.assessment_outlined, size: 18),
                        label: const Text('Rapports'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (state.history.isEmpty)
                  const _EmptyHint(
                    icon: Icons.history,
                    message: 'Aucune session clôturée pour l’instant.',
                  )
                else
                  ...state.history.map(
                    (row) => _HistoryTile(
                      row: row,
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
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.currency_exchange,
                size: 36,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Bureau de change',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Activez le module pour gérer les taux, les caisses devises '
              'et les opérations d’achat / vente.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: AppSizes.lineHeightBody,
                  ),
            ),
            if (canConfigure) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () => context.read<FxExchangeBloc>().add(
                          const FxModuleToggleRequested(enabled: true),
                        ),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.power_settings_new),
                label: Text(
                  isSubmitting ? 'Activation…' : 'Activer le module',
                ),
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
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Taux du jour',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Modifier',
                    onPressed: () =>
                        openFxSubPage(context, const FxRatesPage()),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                IconButton(
                  tooltip: 'Historique',
                  onPressed: () =>
                      openFxSubPage(context, const FxRatesHistoryPage()),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
            if (rates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: _EmptyHint(
                  icon: Icons.price_change_outlined,
                  message:
                      'Aucun taux défini. Saisissez les taux avant d’ouvrir.',
                ),
              )
            else
              ...rates.map((rate) {
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
                return Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
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
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Achat · $buy',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Vente · $sell',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _OpenSessionCard extends StatelessWidget {
  const _OpenSessionCard({
    required this.canOpen,
    required this.canRates,
    required this.shopCurrencies,
    required this.latestRates,
  });

  final bool canOpen;
  final bool canRates;
  final List<FxShopCurrency> shopCurrencies;
  final List<FxRateSnapshot> latestRates;

  @override
  Widget build(BuildContext context) {
    final foreignEnabled = shopCurrencies
        .where((c) => c.enabled && c.currencyCode != fxBaseCurrency)
        .length;
    final ratesReady =
        latestRates.length >= foreignEnabled && foreignEnabled > 0;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Démarrer la journée',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChecklistRow(
              done: foreignEnabled > 0,
              label: foreignEnabled > 0
                  ? '$foreignEnabled devise(s) étrangère(s) active(s)'
                  : 'Activez au moins une devise étrangère',
            ),
            _ChecklistRow(
              done: ratesReady,
              label: ratesReady
                  ? 'Taux du jour prêts'
                  : 'Définir les taux pour chaque devise active',
            ),
            const SizedBox(height: AppSpacing.md),
            if (!ratesReady && canRates)
              OutlinedButton.icon(
                onPressed: () => openFxSubPage(context, const FxRatesPage()),
                icon: const Icon(Icons.price_change_outlined),
                label: const Text('Saisir les taux'),
              ),
            if (!ratesReady && canRates) const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed:
                  canOpen && ratesReady ? () => _showOpenDialog(context) : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Ouvrir la session FX'),
            ),
            if (!ratesReady)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'La session s’ouvre une fois les taux renseignés.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
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
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TextField(
                      controller: e.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Solde initial ${e.key}',
                        border: const OutlineInputBorder(),
                      ),
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
    final pending = session.isPendingClose;
    final bloc = context.watch<FxExchangeBloc>();
    final scheme = Theme.of(context).colorScheme;
    final openedAt = DateFormat('dd/MM HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pending ? 'Clôture à valider' : 'Session en cours',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: pending
                      ? scheme.tertiaryContainer
                      : scheme.primaryContainer,
                  label: Text(
                    pending ? 'À valider' : 'Ouverte',
                    style: TextStyle(
                      color: pending
                          ? scheme.onTertiaryContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Depuis $openedAt · ${session.operationCount} op. · '
              'Marge ${formatFcfa(session.totalMarginFcfa)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (pending) ...[
              Text(
                'Écarts de caisse',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: session.balances.map((b) {
                  final expected = b.expectedBalance ?? 0;
                  final counted = b.countedBalance ?? 0;
                  final diff = b.difference ?? (counted - expected);
                  final ok = diff == 0;
                  return _BalanceTile(
                    code: b.currencyCode,
                    amountLabel: formatAmount(counted, b.currencyCode),
                    subtitle: ok
                        ? 'Écart OK'
                        : 'Écart ${diff > 0 ? '+' : ''}${formatAmount(diff, b.currencyCode)}',
                    highlight: !ok,
                  );
                }).toList(),
              ),
              if (session.closingNote != null &&
                  session.closingNote!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Note : ${session.closingNote}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ] else ...[
              Text(
                'Soldes live',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: liveBalances.entries
                    .map(
                      (e) => _BalanceTile(
                        code: e.key,
                        amountLabel: formatAmount(e.value, e.key),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (!pending && canOperate)
                  OutlinedButton.icon(
                    onPressed: () =>
                        openFxSubPage(context, const FxMovementPage()),
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Mouvement'),
                  ),
                if (!pending && canClose)
                  OutlinedButton.icon(
                    onPressed: () =>
                        openFxSubPage(context, const FxCloseSessionPage()),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Clôturer'),
                  ),
                if (pending && canClose)
                  FilledButton.icon(
                    onPressed: bloc.state.isSubmitting
                        ? null
                        : () => context.read<FxExchangeBloc>().add(
                              const FxConfirmCloseSessionRequested(),
                            ),
                    icon: const Icon(Icons.check),
                    label: const Text('Valider la clôture'),
                  ),
                if (pending && canClose)
                  OutlinedButton.icon(
                    onPressed: bloc.state.isSubmitting
                        ? null
                        : () => context.read<FxExchangeBloc>().add(
                              const FxCancelPendingCloseRequested(),
                            ),
                    icon: const Icon(Icons.undo),
                    label: const Text('Reprendre'),
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
            if (!pending && operations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Dernières ventes et achats',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...operations.take(5).map(
                    (op) => FxOperationHistoryTile(
                      operation: op,
                      dense: true,
                      asCard: false,
                      contentPadding: EdgeInsets.zero,
                      showFullDateTime: true,
                    ),
                  ),
            ],
            if (!pending && movements.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Derniers mouvements',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...movements.take(3).map(
                    (mv) => FxMovementHistoryTile(
                      movement: mv,
                      dense: true,
                      asCard: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.code,
    required this.amountLabel,
    this.subtitle,
    this.highlight = false,
  });

  final String code;
  final String amountLabel;
  final String? subtitle;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 148,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.errorContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          Text(
            amountLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: highlight ? scheme.error : scheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: AppSizes.iconSm,
            color: done ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: done ? null : scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row, this.onTap});

  final FxSessionListRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: const Icon(Icons.receipt_long_outlined, size: 20),
        ),
        title: Text(
          DateFormat('dd/MM/yyyy HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(row.openedAt),
          ),
        ),
        subtitle: Text(
          '${row.operationCount} op. · Marge ${formatFcfa(row.totalMarginFcfa)}',
        ),
        trailing: Chip(
          visualDensity: VisualDensity.compact,
          label: Text(row.status.label),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconMd, color: scheme.outline),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: AppSizes.lineHeightBody,
                ),
          ),
        ),
      ],
    );
  }
}
