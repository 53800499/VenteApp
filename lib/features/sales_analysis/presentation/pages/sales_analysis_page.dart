import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/feature_ui.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/presentation/pages/customer_detail_page.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/usecases/sales_analysis_usecases.dart';
import '../bloc/sales_analysis_bloc.dart';
import '../utils/sales_analysis_formatters.dart';
import 'product_sales_detail_page.dart';

Future<void> _refreshSalesAnalysis(BuildContext context) async {
  final bloc = context.read<SalesAnalysisBloc>();
  bloc.add(const SalesAnalysisLoadRequested());
  await bloc.stream.firstWhere(
    (s) =>
        s.status == SalesAnalysisStatus.loaded ||
        s.status == SalesAnalysisStatus.failure,
  );
}

/// État vide d'un onglet (sans RefreshIndicator — compatible TabBarView).
Widget _analysisTabEmpty(
  BuildContext context, {
  required bool isLoading,
  required IconData icon,
  required String title,
}) {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator());
  }
  final theme = Theme.of(context);
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: AppSizes.emptyStatePadding),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FeatureIllustrationIcon(icon: icon),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSizes.emptyStatePadding),
    ],
  );
}

class SalesAnalysisPage extends StatelessWidget {
  const SalesAnalysisPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    ensureSalesAnalysisDependencies();

    return BlocProvider(
      create: (_) => SalesAnalysisBloc(
        listProducts: sl<ListProductSalesAnalysis>(),
        listEmployees: sl<ListEmployeePriceAnalysis>(),
        listCustomers: sl<ListCustomerSalesInsights>(),
        listCategories: sl<ListCategorySalesAnalysis>(),
        getMargins: sl<GetMarginAnalysis>(),
        listPriceDeviations: sl<ListPriceDeviationAnalysis>(),
        getTrends: sl<GetSalesTrendAnalysis>(),
        clearRemoteCache: sl<ClearSalesAnalysisRemoteCache>(),
        session: session,
      )..add(const SalesAnalysisLoadRequested()),
      child: const _SalesAnalysisView(),
    );
  }
}

class _SalesAnalysisView extends StatefulWidget {
  const _SalesAnalysisView();

  @override
  State<_SalesAnalysisView> createState() => _SalesAnalysisViewState();
}

class _SalesAnalysisViewState extends State<_SalesAnalysisView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    'Produits',
    'Employés',
    'Clients',
    'Catégories',
    'Marges',
    'Prix',
    'Tendances',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      context.read<SalesAnalysisBloc>().add(
            SalesAnalysisTabChanged(_tabController.index),
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesAnalysisBloc, SalesAnalysisState>(
      listenWhen: (prev, curr) => prev.tabIndex != curr.tabIndex,
      listener: (context, state) {
        if (_tabController.index != state.tabIndex) {
          _tabController.animateTo(state.tabIndex);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des ventes'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshSalesAnalysis(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.hybridReadMessage,
          ),
          BlocBuilder<SalesAnalysisBloc, SalesAnalysisState>(
            buildWhen: (prev, curr) =>
                prev.query != curr.query || prev.periodLabel != curr.periodLabel,
            builder: (context, state) {
              return _PeriodBar(
                query: state.query,
                periodLabel: state.periodLabel,
              );
            },
          ),
          Expanded(
            child: BlocBuilder<SalesAnalysisBloc, SalesAnalysisState>(
              builder: (context, state) {
                final bootstrapping =
                    (state.status == SalesAnalysisStatus.initial ||
                            state.status == SalesAnalysisStatus.loading) &&
                        state.products.isEmpty;
                if (bootstrapping) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == SalesAnalysisStatus.failure &&
                    state.products.isEmpty) {
                  return _ErrorBody(message: state.errorMessage ?? 'Erreur');
                }

                return Column(
                  children: [
                    if (state.status == SalesAnalysisStatus.loading)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProductsTab(
                      products: state.products,
                      query: state.query,
                      isLoading: state.status == SalesAnalysisStatus.loading,
                    ),
                    _EmployeesTab(
                      employees: state.employees,
                      isLoading: state.status == SalesAnalysisStatus.loading,
                    ),
                    _ClientsTab(
                      customers: state.customers,
                      session: context.read<SalesAnalysisBloc>().session,
                      isLoading: state.status == SalesAnalysisStatus.loading,
                    ),
                    _CategoriesTab(
                      categories: state.categories,
                      isLoading: state.status == SalesAnalysisStatus.loading,
                    ),
                    _MarginsTab(
                      margins: state.margins,
                      isLoading: state.status == SalesAnalysisStatus.loading,
                    ),
                    _PricesTab(
                      deviations: state.priceDeviations,
                      isLoading: state.status == SalesAnalysisStatus.loading,
                    ),
                    _TrendsTab(
                      trends: state.trends,
                      isLoading: state.status == SalesAnalysisStatus.loading,
                    ),
                  ],
                      ),
                    ),
                  ],
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

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.query, this.periodLabel});

  final SalesAnalysisQuery query;
  final String? periodLabel;

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Choisir une période',
    );
    if (picked == null || !context.mounted) return;

    const beninOffsetMs = 60 * 60 * 1000;
    final fromMs = DateTime.utc(
      picked.start.year,
      picked.start.month,
      picked.start.day,
    ).millisecondsSinceEpoch -
        beninOffsetMs;
    final toMs = DateTime.utc(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch -
        beninOffsetMs;

    context.read<SalesAnalysisBloc>().add(
          SalesAnalysisPeriodChanged(
            period: ReportPeriodPreset.custom,
            customFrom: fromMs,
            customTo: toMs,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (periodLabel != null)
              Text(
                periodLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in [
                    ReportPeriodPreset.today,
                    ReportPeriodPreset.week,
                    ReportPeriodPreset.month,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        label: Text(reportPeriodPresetLabel(preset)),
                        selected: query.period == preset,
                        onSelected: (_) {
                          context.read<SalesAnalysisBloc>().add(
                                SalesAnalysisPeriodChanged(period: preset),
                              );
                        },
                      ),
                    ),
                  FilterChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(reportPeriodPresetLabel(ReportPeriodPreset.custom)),
                    selected: query.period == ReportPeriodPreset.custom,
                    onSelected: (_) => _pickCustomRange(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({
    required this.products,
    required this.query,
    required this.isLoading,
  });

  final List<ProductSalesSummary> products;
  final SalesAnalysisQuery query;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return _analysisTabEmpty(
        context,
        isLoading: isLoading,
        icon: Icons.inventory_2_outlined,
        title: 'Aucune vente produit sur cette période',
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Produit',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Qté',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'CA',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Prix moy.',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...products.map(
              (product) => _ProductSummaryTile(
                product: product,
                onTap: () {
                  final session = context.read<SalesAnalysisBloc>().session;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductSalesDetailPage(
                        session: session,
                        query: query,
                        productId: product.productId,
                        productName: product.productName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _ProductSummaryTile extends StatelessWidget {
  const _ProductSummaryTile({
    required this.product,
    required this.onTap,
  });

  final ProductSalesSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lastSale = product.lastSaleAt != null
        ? formatRelativeSaleDate(product.lastSaleAt!)
        : '—';
    final isHeadless =
        SalesAnalysisHeadlessLabels.isHeadlessProductName(product.productName);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      product.productName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatQuantitySold(product.quantitySold),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatFcfa(product.revenue),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatFcfa(product.averageUnitPrice),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (isHeadless)
                Text(
                  'Ventes sans lignes produit — montant total par vente',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Text(
                  'Dernière vente : $lastSale',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeesTab extends StatelessWidget {
  const _EmployeesTab({
    required this.employees,
    required this.isLoading,
  });

  final List<EmployeePricePerformance> employees;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return _analysisTabEmpty(
        context,
        isLoading: isLoading,
        icon: Icons.badge_outlined,
        title: 'Aucune vente sur cette période',
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: employees.length,
          separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final employee = employees[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (employee.userName ?? 'V').characters.first.toUpperCase(),
                  ),
                ),
                title: Text(employee.userName ?? 'Vendeur #${employee.userId}'),
                subtitle: Text(
                  '${employee.saleLineCount} lignes vendues · '
                  '${employee.discountLineCount} écart(s) de prix',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Prix moyen',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      formatFcfa(employee.averageUnitPrice),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab({
    required this.customers,
    required this.session,
    required this.isLoading,
  });

  final List<CustomerSalesInsight> customers;
  final AuthSession session;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return _analysisTabEmpty(
        context,
        isLoading: isLoading,
        icon: Icons.people_outline,
        title: 'Aucun client identifié sur cette période',
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: customers.length,
          separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final customer = customers[index];
            return Card(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailPage(
                      session: session,
                      customerId: customer.customerId,
                    ),
                  ),
                ),
                title: Text(customer.customerName),
                subtitle: Text(
                  '${customer.saleCount} vente(s) · '
                  '${customer.lineCount} ligne(s) · '
                  '${formatFcfa(customer.totalRevenue)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Prix moyen',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      formatFcfa(customer.averageUnitPrice),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({
    required this.categories,
    required this.isLoading,
  });

  final List<CategorySalesSummary> categories;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return _analysisTabEmpty(
        context,
        isLoading: isLoading,
        icon: Icons.category_outlined,
        title: 'Aucune vente par catégorie sur cette période',
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: categories.length,
          separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final category = categories[index];
            return Card(
              child: ListTile(
                title: Text(category.categoryName),
                subtitle: Text(
                  '${category.productCount} produit(s) · '
                  '${formatQuantitySold(category.quantitySold)} vendu(s)',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CA',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      formatFcfa(category.revenue),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _MarginsTab extends StatelessWidget {
  const _MarginsTab({
    required this.margins,
    required this.isLoading,
  });

  final MarginSummary margins;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (margins.totalRevenue == 0) {
      return _analysisTabEmpty(
        context,
        isLoading: isLoading,
        icon: Icons.trending_up_outlined,
        title: 'Aucune vente sur cette période',
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Synthèse des marges',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _KpiRow(
                      label: 'Chiffre d\'affaires',
                      value: formatFcfa(margins.totalRevenue),
                    ),
                    _KpiRow(
                      label: 'Coût estimé',
                      value: margins.hasCostData
                          ? formatFcfa(margins.totalCost)
                          : '—',
                    ),
                    _KpiRow(
                      label: 'Marge estimée',
                      value: margins.hasCostData
                          ? formatFcfa(margins.estimatedProfit)
                          : '—',
                      highlight: true,
                    ),
                    if (margins.hasCostData)
                      _KpiRow(
                        label: 'Taux de marge',
                        value: '${margins.marginPercent.toStringAsFixed(1)} %',
                      ),
                    if (!margins.hasCostData)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'Renseignez le prix d\'achat ou le coût unitaire '
                          'sur les lignes pour estimer les marges.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (margins.linesWithCost < margins.totalLines &&
                        margins.hasCostData)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Coût connu sur ${margins.linesWithCost} / '
                          '${margins.totalLines} lignes.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (margins.topProducts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Produits les plus rentables',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...margins.topProducts.map(
                (line) => Card(
                  child: ListTile(
                    title: Text(line.productName),
                    subtitle: Text(
                      '${formatQuantitySold(line.quantitySold)} vendu(s) · '
                      'marge ${line.marginPercent.toStringAsFixed(1)} %',
                    ),
                    trailing: Text(
                      formatFcfa(line.estimatedProfit),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: highlight
                ? Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    )
                : Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _PricesTab extends StatelessWidget {
  const _PricesTab({
    required this.deviations,
    required this.isLoading,
  });

  final List<PriceDeviationLine> deviations;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (deviations.isEmpty) {
      return _analysisTabEmpty(
        context,
        isLoading: isLoading,
        icon: Icons.price_change_outlined,
        title: 'Aucun écart de prix par rapport au catalogue sur cette période',
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: deviations.length,
          separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final line = deviations[index];
            final delta = line.priceDelta;
            final deltaLabel = delta == null
                ? 'Prix catalogue inconnu'
                : delta == 0
                    ? 'Remise appliquée'
                    : delta < 0
                        ? '${formatFcfa(delta.abs())} sous catalogue'
                        : '${formatFcfa(delta)} au-dessus du catalogue';

            return Card(
              child: ListTile(
                title: Text(line.productName),
                subtitle: Text(
                  '${formatRelativeSaleDate(line.soldAt)} · '
                  '${line.sellerName ?? 'Vendeur'} · $deltaLabel',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (line.catalogPrice != null)
                      Text(
                        'Cat. ${formatFcfa(line.catalogPrice!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      formatFcfa(line.unitPrice),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: delta != null && delta < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _TrendsTab extends StatelessWidget {
  const _TrendsTab({
    required this.trends,
    required this.isLoading,
  });

  final SalesTrendSummary trends;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (trends.points.isEmpty) {
      return _analysisTabEmpty(
        context,
        isLoading: isLoading,
        icon: Icons.show_chart_outlined,
        title: 'Aucune tendance sur cette période',
      );
    }

    final maxRevenue = trends.points
        .map((p) => p.revenue)
        .reduce((a, b) => a > b ? a : b);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CA total',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            formatFcfa(trends.totalRevenue),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ventes',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${trends.totalSaleCount}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...trends.points.map((point) {
              final barFraction =
                  maxRevenue > 0 ? point.revenue / maxRevenue : 0.0;
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
                              point.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(formatFcfa(point.revenue)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barFraction,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${point.saleCount} vente(s) · '
                        '${formatQuantitySold(point.quantitySold)} article(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context
                  .read<SalesAnalysisBloc>()
                  .add(const SalesAnalysisLoadRequested()),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
