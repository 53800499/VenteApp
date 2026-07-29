import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/components/skeleton_loaders.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../domain/entities/sales_order.dart';
import '../bloc/sales_order_bloc.dart';
import 'sales_order_detail_page.dart';
import 'sales_order_form_page.dart';

class SalesOrdersPage extends StatelessWidget {
  const SalesOrdersPage({super.key, required this.session});

  final AuthSession session;

  bool get _canWrite => PermissionGuard.can(
        session.user.permissions,
        Permission.salesOrdersWrite,
      );

  @override
  Widget build(BuildContext context) {
    ensureSalesOrderDependencies();
    return BlocProvider(
      create: (_) => SalesOrderBloc(
        repository: sl(),
        session: session,
      )..add(const SalesOrderListRequested()),
      child: _SalesOrdersView(session: session, canWrite: _canWrite),
    );
  }
}

class _SalesOrdersView extends StatefulWidget {
  const _SalesOrdersView({
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<_SalesOrdersView> createState() => _SalesOrdersViewState();
}

class _SalesOrdersViewState extends State<_SalesOrdersView>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  SalesOrderStatus? _statusFilter;
  late final TabController _tabs;
  _ReportPeriod _reportPeriod = _ReportPeriod.days30;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {});
        if (_tabs.index == 1) {
          _loadReport();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    context.read<SalesOrderBloc>().add(
          SalesOrderListRequested(
            status: _statusFilter,
            search: _searchController.text.trim(),
          ),
        );
  }

  void _loadReport() {
    final now = DateTime.now();
    final toMs = now.millisecondsSinceEpoch;
    final from = switch (_reportPeriod) {
      _ReportPeriod.days7 => now.subtract(const Duration(days: 7)),
      _ReportPeriod.days30 => now.subtract(const Duration(days: 30)),
      _ReportPeriod.month => DateTime(now.year, now.month, 1),
    };
    context.read<SalesOrderBloc>().add(
          SalesOrderReportRequested(
            fromMs: from.millisecondsSinceEpoch,
            toMs: toMs,
          ),
        );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SalesOrderBloc>(),
          child: SalesOrderFormPage(session: widget.session),
        ),
      ),
    );
    if (created == true && mounted) _reload();
  }

  Future<void> _openDetail(SalesOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SalesOrderBloc>(),
          child: SalesOrderDetailPage(
            session: widget.session,
            orderId: order.id,
          ),
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes clients'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Commandes'),
            Tab(text: 'Rapports'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabs.index == 0) {
                _reload();
              } else {
                _loadReport();
              }
            },
          ),
          const ModuleHelpButton(articleId: 'sales_orders'),
          const AppHeaderActions(),
        ],
      ),
      floatingActionButton: widget.canWrite && _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Commande'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildOrdersTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'N° ou client…',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _reload();
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<SalesOrderStatus?>(
                  isExpanded: true,
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous'),
                    ),
                    ...SalesOrderStatus.values.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.labelFr,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v);
                    _reload();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocConsumer<SalesOrderBloc, SalesOrderState>(
            listenWhen: (p, c) =>
                p.errorMessage != c.errorMessage ||
                p.successMessage != c.successMessage,
            listener: (context, state) {
              if (state.errorMessage != null) {
                ActionFeedback.showErrorMessage(
                  context,
                  state.errorMessage!,
                );
                context
                    .read<SalesOrderBloc>()
                    .add(const SalesOrderFeedbackCleared());
              } else if (state.successMessage != null) {
                ActionFeedback.showInfo(context, state.successMessage!);
                context
                    .read<SalesOrderBloc>()
                    .add(const SalesOrderFeedbackCleared());
              }
            },
            builder: (context, state) {
              if (state.status == SalesOrderViewStatus.loading &&
                  state.orders.isEmpty) {
                return const SaleListSkeleton();
              }
              if (state.orders.isEmpty) {
                return EmptyListPlaceholder(
                  icon: Icons.assignment_outlined,
                  title: 'Aucune commande',
                  subtitle: widget.canWrite
                      ? 'Créez une commande client quand le stock ne suffit '
                          'pas ou pour une livraison échelonnée.'
                      : null,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: state.orders.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _OrderSummaryBanner(orders: state.orders);
                    }
                    final order = state.orders[index - 1];
                    return _SalesOrderCard(
                      order: order,
                      onTap: () => _openDetail(order),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SegmentedButton<_ReportPeriod>(
            segments: const [
              ButtonSegment(
                value: _ReportPeriod.days7,
                label: Text('7 j'),
              ),
              ButtonSegment(
                value: _ReportPeriod.days30,
                label: Text('30 j'),
              ),
              ButtonSegment(
                value: _ReportPeriod.month,
                label: Text('Mois'),
              ),
            ],
            selected: {_reportPeriod},
            onSelectionChanged: (s) {
              setState(() => _reportPeriod = s.first);
              _loadReport();
            },
          ),
        ),
        Expanded(
          child: BlocBuilder<SalesOrderBloc, SalesOrderState>(
            builder: (context, state) {
              if (state.reportLoading && state.report == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final report = state.report;
              if (report == null) {
                return const Center(
                  child: Text('Sélectionnez une période.'),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                children: [
                  _ReportSection(
                    title: 'Motifs de refus',
                    subtitle: 'Quantités refusées',
                    buckets: report.byRefusalReason,
                    total: report.totalRefusedQty,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ReportSection(
                    title: 'Destinations du refus',
                    subtitle: 'Retour stock vs perte',
                    buckets: report.byDestination,
                    total: report.totalDestinationQty,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ReportSection(
                    title: 'Raisons de reliquat',
                    subtitle: 'Livraisons partielles',
                    buckets: report.byRemainingReason,
                    total: report.totalPartialDeliveries,
                    valueSuffix: ' liv.',
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _ReportPeriod { days7, days30, month }

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.subtitle,
    required this.buckets,
    required this.total,
    this.valueSuffix = '',
  });

  final String title;
  final String subtitle;
  final List<SalesOrderReportBucket> buckets;
  final int total;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              '$subtitle · total $total$valueSuffix',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(),
            if (buckets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('Aucune donnée sur la période.'),
              )
            else
              ...buckets.map((b) {
                final pct = (b.shareOf(total) * 100).toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(b.labelFr)),
                          Text('${b.value}$valueSuffix · $pct %'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: b.shareOf(total).clamp(0.0, 1.0),
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

// ---------------------------------------------------------------------------
// KPI banner
// ---------------------------------------------------------------------------

class _OrderSummaryBanner extends StatelessWidget {
  const _OrderSummaryBanner({required this.orders});

  final List<SalesOrder> orders;

  @override
  Widget build(BuildContext context) {
    final open = orders
        .where(
          (o) =>
              o.status == SalesOrderStatus.confirmed ||
              o.status == SalesOrderStatus.preparing ||
              o.status == SalesOrderStatus.partiallyDelivered,
        )
        .length;
    final toDeliver = orders.fold<int>(0, (s, o) => s + o.totalRemaining);
    final amountOpen = orders
        .where(
          (o) =>
              o.status != SalesOrderStatus.cancelled &&
              o.status != SalesOrderStatus.closed,
        )
        .fold<int>(0, (s, o) => s + o.total);

    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: _KpiMini(
                label: 'En cours',
                value: '$open',
                icon: Icons.hourglass_top_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _KpiMini(
                label: 'Reste à livrer',
                value: '$toDeliver',
                icon: Icons.local_shipping_outlined,
                color: Colors.orange.shade700,
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _KpiMini(
                label: 'Montant ouvert',
                value: formatFcfa(amountOpen),
                icon: Icons.payments_outlined,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiMini extends StatelessWidget {
  const _KpiMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: Theme.of(context).dividerColor,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _SalesOrderCard extends StatelessWidget {
  const _SalesOrderCard({
    required this.order,
    required this.onTap,
  });

  final SalesOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = order.orderedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(order.orderedAt)
            .toLocal()
            .toString()
            .substring(0, 10)
        : '—';
    final ordered = order.totalOrdered;
    final treated = order.totalDelivered + order.totalRefused;
    final progress = ordered <= 0 ? 0.0 : treated / ordered;
    final complete = order.totalRemaining <= 0 && ordered > 0;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.number,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(dateStr, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Livré ${order.totalDelivered} · '
                      'Refusé ${order.totalRefused} · '
                      'Reste ${order.totalRemaining} / $ordered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: complete ? Colors.green : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  Text(
                    formatFcfa(order.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
                color: complete ? Colors.green : Colors.orange,
                backgroundColor: Colors.grey.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SalesOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      SalesOrderStatus.draft => (Colors.grey.shade200, Colors.grey.shade800),
      SalesOrderStatus.confirmed => (
          Colors.blue.shade100,
          Colors.blue.shade800
        ),
      SalesOrderStatus.preparing => (
          Colors.orange.shade100,
          Colors.orange.shade800
        ),
      SalesOrderStatus.partiallyDelivered => (
          Colors.amber.shade100,
          Colors.amber.shade900
        ),
      SalesOrderStatus.delivered => (
          Colors.green.shade100,
          Colors.green.shade800
        ),
      SalesOrderStatus.closed => (Colors.teal.shade100, Colors.teal.shade900),
      SalesOrderStatus.cancelled => (Colors.red.shade100, Colors.red.shade800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.labelFr,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
