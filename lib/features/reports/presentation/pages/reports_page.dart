import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../sales_analysis/presentation/pages/sales_analysis_page.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/usecases/get_report.dart';
import '../../../../shared/components/action_feedback.dart';
import '../services/report_pdf_exporter.dart';
import '../bloc/report_bloc.dart';

bool _canUseConsolidatedView(AuthSession session) =>
    session.user.role == UserRole.owner &&
    PermissionGuard.can(
      session.user.permissions,
      Permission.shopsConsolidatedRead,
    );

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    ensureReportsDependencies();

    return BlocProvider(
      create: (_) => ReportBloc(
        getReport: sl<GetReport>(),
        session: session,
      )..add(const ReportLoadRequested()),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  Future<void> _exportPdf(BuildContext context) async {
    final bloc = context.read<ReportBloc>();
    final state = bloc.state;
    final report = state.report;
    if (report == null || state.status != ReportStatus.success) return;

    final canFinancial = PermissionGuard.can(
      bloc.session.user.permissions,
      Permission.reportsFinancial,
    );

    try {
      await sl<ReportPdfExporter>().sharePdf(
        shopName: bloc.session.shop.name,
        report: report,
        includeFinancial: canFinancial,
      );
      if (!context.mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: 'Rapport exporté',
        message: 'Le PDF est prêt à être partagé.',
      );
    } catch (e) {
      if (!context.mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Export impossible',
        message: 'Export PDF impossible : $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReportBloc, ReportState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message == null || message.isEmpty) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          BlocBuilder<ReportBloc, ReportState>(
            buildWhen: (prev, curr) => prev.status != curr.status,
            builder: (context, state) {
              if (state.status != ReportStatus.success || state.report == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Exporter PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => _exportPdf(context),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.hybridReadMessage,
          ),
          Expanded(
            child: BlocBuilder<ReportBloc, ReportState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<ReportBloc>().add(const ReportLoadRequested());
              await context.read<ReportBloc>().stream.firstWhere(
                    (s) => s.status != ReportStatus.loading,
                  );
            },
            child: switch (state.status) {
              ReportStatus.initial || ReportStatus.loading =>
                ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
              ReportStatus.failure => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.errorMessage ?? 'Impossible de charger le rapport.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => context
                            .read<ReportBloc>()
                            .add(const ReportLoadRequested()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ),
                  ],
                ),
              ReportStatus.success => Column(
                  children: [
                    if (state.isRefreshing)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: _ReportBody(state: state),
                    ),
                  ],
                ),
            },
          );
        },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.state});

  final ReportState state;

  @override
  Widget build(BuildContext context) {
    final report = state.report!;
    final session = context.read<ReportBloc>().session;
    final canFinancial = PermissionGuard.can(
      session.user.permissions,
      Permission.reportsFinancial,
    );
    final canConsolidated = _canUseConsolidatedView(session);

    return ResponsivePage(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            report.period.label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PeriodChips(query: state.query),
          if (canConsolidated) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vue consolidée (toutes boutiques)'),
              subtitle: Text(
                state.query.consolidated
                    ? '${report.shopIds.length} boutique(s) agrégée(s)'
                    : 'Patron uniquement — toutes vos boutiques',
              ),
              value: state.query.consolidated,
              onChanged: (v) => context
                  .read<ReportBloc>()
                  .add(ReportConsolidatedToggled(v)),
            ),
            if (state.query.consolidated)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.store_mall_directory_outlined),
                  title: Text(
                    '${report.shopIds.length} boutique(s) agrégée(s)',
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (report.empty)
            _EmptyPeriodCard(message: report.emptyMessage)
          else ...[
            _SalesSection(sales: report.sales),
            if (canFinancial && report.financial != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _FinancialSection(financial: report.financial!),
            ],
            const SizedBox(height: AppSpacing.lg),
            _TopProductsSection(
              products: report.topProducts,
              topBy: state.query.topBy,
              session: session,
            ),
            if (report.sellerPerformance != null &&
                report.sellerPerformance!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SellerSection(sellers: report.sellerPerformance!),
            ],
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.query});

  final ReportQuery query;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final preset in [
          ReportPeriodPreset.today,
          ReportPeriodPreset.week,
          ReportPeriodPreset.month,
        ])
          ChoiceChip(
            label: Text(reportPeriodPresetLabel(preset)),
            selected: query.period == preset,
            onSelected: (_) => context
                .read<ReportBloc>()
                .add(ReportPeriodChanged(preset)),
          ),
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: const Text('Personnalisé'),
          onPressed: () => _pickCustomRange(context),
        ),
      ],
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Choisir une période',
    );
    if (picked == null || !context.mounted) return;

    final fromMs = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
    ).millisecondsSinceEpoch;
    final toMs = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    context.read<ReportBloc>().add(
          ReportCustomRangeSelected(fromMs: fromMs, toMs: toMs),
        );
  }
}

class _EmptyPeriodCard extends StatelessWidget {
  const _EmptyPeriodCard({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? 'Aucune vente sur cette période.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesSection extends StatelessWidget {
  const _SalesSection({required this.sales});

  final ReportSalesKpis sales;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ventes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        ResponsiveKpiGrid(
          withSubtitle: true,
          children: [
            KpiCard(
              label: 'CA brut',
              value: formatFcfa(sales.grossRevenue),
              icon: Icons.payments_outlined,
            ),
            KpiCard(
              label: 'CA encaissé',
              value: formatFcfa(sales.collectedRevenue),
              icon: Icons.account_balance_wallet_outlined,
            ),
            KpiCard(
              label: 'Crédit accordé',
              value: formatFcfa(sales.creditGranted),
              icon: Icons.credit_card_outlined,
            ),
            KpiCard(
              label: 'Panier moyen',
              value: formatFcfa(sales.averageBasket),
              icon: Icons.shopping_basket_outlined,
            ),
            KpiCard(
              label: 'Nombre de ventes',
              value: '${sales.saleCount}',
              icon: Icons.receipt_long_outlined,
            ),
            KpiCard(
              label: 'Espèces / MoMo',
              value: formatFcfa(sales.totalCash + sales.totalMomo),
              subtitle:
                  'Espèces ${formatFcfa(sales.totalCash)} · MoMo ${formatFcfa(sales.totalMomo)}',
              icon: Icons.swap_horiz,
            ),
          ],
        ),
      ],
    );
  }
}

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({required this.financial});

  final ReportFinancialKpis financial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financier',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (financial.profitAvailable && financial.estimatedProfit != null)
          KpiCard(
            label: 'Bénéfice estimé',
            value: formatFcfa(financial.estimatedProfit!),
            icon: Icons.trending_up,
            accentColor: Theme.of(context).colorScheme.tertiary,
          )
        else if (financial.profitWarning != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(financial.profitWarning!),
            ),
          ),
        if (financial.totalExpenses > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          KpiCard(
            label: 'Dépenses',
            value: formatFcfa(financial.totalExpenses),
            icon: Icons.receipt_long_outlined,
            accentColor: Theme.of(context).colorScheme.error,
          ),
        ],
        if (financial.netProfit != null) ...[
          const SizedBox(height: AppSpacing.sm),
          KpiCard(
            label: 'Bénéfice net',
            value: formatFcfa(financial.netProfit!),
            icon: Icons.account_balance_wallet_outlined,
            accentColor: financial.netProfit! >= 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (financial.recoveryRateAvailable && financial.recoveryRate != null)
          KpiCard(
            label: 'Taux de recouvrement',
            value: '${financial.recoveryRate} %',
            subtitle:
                'Remboursé ${formatFcfa(financial.debtsRepaidAmount)} / ${formatFcfa(financial.debtsCreatedAmount)}',
            icon: Icons.percent,
          ),
      ],
    );
  }
}

class _TopProductsSection extends StatelessWidget {
  const _TopProductsSection({
    required this.products,
    required this.topBy,
    required this.session,
  });

  final List<ReportTopProduct> products;
  final ReportTopSort topBy;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Top produits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SegmentedButton<ReportTopSort>(
              segments: const [
                ButtonSegment(
                  value: ReportTopSort.quantity,
                  label: Text('Qté'),
                ),
                ButtonSegment(
                  value: ReportTopSort.revenue,
                  label: Text('CA'),
                ),
              ],
              selected: {topBy},
              onSelectionChanged: (s) => context
                  .read<ReportBloc>()
                  .add(ReportTopSortChanged(s.first)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (products.isEmpty)
          const Text('Aucun produit vendu sur la période.')
        else
          Card(
            child: Column(
              children: [
                for (final product in products)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text('${product.rank}'),
                    ),
                    title: Text(product.productName),
                    subtitle: Text(
                      topBy == ReportTopSort.revenue
                          ? formatFcfa(product.revenue)
                          : '${product.quantitySold.toStringAsFixed(product.quantitySold.truncateToDouble() == product.quantitySold ? 0 : 1)} vendus · ${formatFcfa(product.revenue)}',
                    ),
                    trailing: topBy == ReportTopSort.revenue
                        ? Text(formatFcfa(product.revenue))
                        : Text('${product.quantitySold.toStringAsFixed(0)}'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SalesAnalysisPage(session: session),
              ),
            ),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Analyse complète des prix'),
          ),
        ),
      ],
    );
  }
}

class _SellerSection extends StatelessWidget {
  const _SellerSection({required this.sellers});

  final List<ReportSellerPerformance> sellers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance vendeurs',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              for (final seller in sellers)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(seller.userName ?? 'Vendeur #${seller.userId}'),
                  subtitle: Text('${seller.saleCount} ventes'),
                  trailing: Text(formatFcfa(seller.totalRevenue)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
