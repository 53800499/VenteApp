import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/presentation/pages/customer_detail_page.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/usecases/sales_analysis_usecases.dart';
import '../bloc/sales_analysis_bloc.dart';
import '../utils/sales_analysis_formatters.dart';
import 'product_sales_detail_page.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des ventes'),
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
                if (state.status == SalesAnalysisStatus.loading &&
                    state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == SalesAnalysisStatus.failure &&
                    state.products.isEmpty) {
                  return _ErrorBody(message: state.errorMessage ?? 'Erreur');
                }

                return TabBarView(
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
                    const _ComingSoonTab(label: 'Analyse par catégorie'),
                    const _ComingSoonTab(label: 'Marges estimées'),
                    const _ComingSoonTab(label: 'Prix pratiqués'),
                    const _ComingSoonTab(label: 'Tendances'),
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
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Aucune vente produit sur cette période.')),
        ],
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
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Aucune vente sur cette période.')),
        ],
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
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text('Aucun client identifié sur cette période.'),
          ),
        ],
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

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '$label — bientôt disponible.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
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
