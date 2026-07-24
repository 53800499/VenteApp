import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/repositories/procurement_repository.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';
import '../widgets/procurement_reports_tab.dart';
import '../../data/services/procurement_sync_status_service.dart';
import '../../domain/entities/procurement_sync_entities.dart';
import '../widgets/procurement_sync_banner.dart';
import '../widgets/procurement_sync_badge.dart';
import '../widgets/procurement_sync_scope.dart';
import 'procurement_sync_panel_page.dart';
import 'supplier_form_page.dart';
import 'invoice_detail_page.dart';
import 'po_detail_page.dart';
import 'po_form_page.dart';
import 'direct_procurement_page.dart';
import 'direct_receipt_detail_page.dart';
import '../models/po_form_prefill.dart';

class ProcurementPage extends StatelessWidget {
  const ProcurementPage({
    super.key,
    required this.session,
    this.initialTab = 0,
    this.voicePoPrefill,
  });

  final AuthSession session;
  final int initialTab;
  final PoFormPrefill? voicePoPrefill;

  @override
  Widget build(BuildContext context) {
    ensureProcurementDependencies();

    return BlocProvider(
      create: (_) => ProcurementBloc(
        repository: sl<ProcurementRepository>(),
        session: session,
      )
        ..add(const ProcurementSuppliersLoadRequested())
        ..add(const ProcurementOrdersLoadRequested())
        ..add(const ProcurementDirectReceiptsLoadRequested())
        ..add(const ProcurementInvoicesLoadRequested()),
      child: _ProcurementView(
        initialTab: initialTab,
        voicePoPrefill: voicePoPrefill,
      ),
    );
  }
}

class _ProcurementView extends StatefulWidget {
  const _ProcurementView({this.initialTab = 0, this.voicePoPrefill});

  final int initialTab;
  final PoFormPrefill? voicePoPrefill;

  @override
  State<_ProcurementView> createState() => _ProcurementViewState();
}

class _ProcurementViewState extends State<_ProcurementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ProcurementSyncOverview _syncOverview = const ProcurementSyncOverview();
  bool _syncLoading = false;

  int get _shopId => context.read<ProcurementBloc>().shopId;

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab.clamp(0, 4);
    _tabController = TabController(length: 5, vsync: this, initialIndex: tab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapSync();
      final prefill = widget.voicePoPrefill;
      if (prefill != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<ProcurementBloc>(),
              child: PoFormPage(prefill: prefill),
            ),
          ),
        );
      }
    });
  }

  Future<void> _bootstrapSync() async {
    sl<SyncService>().scheduleSync(shopId: _shopId);
    await _refreshSyncOverview();
  }

  Future<void> _refreshSyncOverview() async {
    if (!mounted) return;
    setState(() => _syncLoading = true);
    final overview = await sl<ProcurementSyncStatusService>()
        .loadOverview(shopId: _shopId);
    if (mounted) {
      setState(() {
        _syncOverview = overview;
        _syncLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh(BuildContext context, {bool includeReport = false}) {
    context.read<ProcurementBloc>()
      ..add(const ProcurementSuppliersLoadRequested())
      ..add(const ProcurementOrdersLoadRequested())
      ..add(const ProcurementDirectReceiptsLoadRequested())
      ..add(const ProcurementInvoicesLoadRequested());
    if (includeReport) {
      context.read<ProcurementBloc>().add(const ProcurementReportLoadRequested());
    }
    _refreshSyncOverview();
  }

  void _showNewProcurementSheet(
    BuildContext context, {
    required bool canCreate,
    required bool canReceive,
  }) {
    if (canCreate && !canReceive) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<ProcurementBloc>(),
            child: const PoFormPage(),
          ),
        ),
      );
      return;
    }
    if (canReceive && !canCreate) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<ProcurementBloc>(),
            child: const DirectProcurementPage(),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Approvisionnement direct'),
              subtitle: const Text(
                'Réception immédiate sans commande — stock + lots FIFO',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProcurementBloc>(),
                      child: const DirectProcurementPage(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Commande fournisseur'),
              subtitle: const Text('Créer une commande d\'achat classique'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProcurementBloc>(),
                      child: const PoFormPage(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions =
        context.read<ProcurementBloc>().session.user.permissions;
    final canCreate =
        PermissionGuard.can(permissions, Permission.procurementCreate);
    final canReceive =
        PermissionGuard.can(permissions, Permission.procurementReceive);

    return BlocConsumer<ProcurementBloc, ProcurementState>(
      listener: (context, state) {
        if (state.status == ProcurementStatus.failure &&
            state.errorMessage != null) {
          ProcurementFeedback.showErrorMessage(context, state.errorMessage!);
        }
      },
      builder: (context, state) {
        return ProcurementSyncScope(
          overview: _syncOverview,
          onRefresh: _refreshSyncOverview,
          child: Scaffold(
          appBar: AppBar(
            title: const Text('Approvisionnement'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  text: 'Commandes',
                  icon: Icon(Icons.shopping_bag_outlined),
                ),
                Tab(
                  text: 'Appro direct',
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                Tab(
                  text: 'Fournisseurs',
                  icon: Icon(Icons.people_alt_outlined),
                ),
                Tab(
                  text: 'Factures',
                  icon: Icon(Icons.receipt_long_outlined),
                ),
                Tab(
                  text: 'Rapports',
                  icon: Icon(Icons.analytics_outlined),
                ),
              ],
            ),
            actions: [
              if (_syncOverview.hasIssues)
                IconButton(
                  tooltip: 'Sync approvisionnement',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProcurementSyncPanelPage(shopId: _shopId),
                      ),
                    ).then((_) => _refreshSyncOverview());
                  },
                  icon: Badge(
                    label: Text('${_syncOverview.pendingCount + _syncOverview.errorCount}'),
                    child: const Icon(Icons.cloud_upload_outlined),
                  ),
                ),
              const ModuleHelpButton(
                articleId: 'procurement',
                tooltip: 'Guide approvisionnement',
              ),
              IconButton(
                icon: _syncLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Actualiser',
                onPressed: _syncLoading
                    ? null
                    : () => _refresh(
                          context,
                          includeReport: _tabController.index == 4,
                        ),
              ),
            ],
          ),
          body: Column(
            children: [
              ProcurementSyncBanner(shopId: _shopId),
              Expanded(
                child: Stack(
            children: [
              if (state.status == ProcurementStatus.loading &&
                  state.purchaseOrders.isEmpty &&
                  state.directReceipts.isEmpty &&
                  state.suppliers.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                TabBarView(
                  controller: _tabController,
                  children: [
                    _OrdersTab(
                      orders: state.purchaseOrders,
                      suppliers: state.suppliers,
                      canCreate: canCreate,
                      onRefresh: () async => _refresh(context),
                    ),
                    _DirectReceiptsTab(
                      receipts: state.directReceipts,
                      suppliers: state.suppliers,
                      canReceive: canReceive,
                      onRefresh: () async => _refresh(context),
                    ),
                    _SuppliersTab(
                      suppliers: state.suppliers,
                      canCreate: canCreate,
                      onRefresh: () async => _refresh(context),
                    ),
                    _InvoicesTab(
                      invoices: state.invoices,
                      onRefresh: () async => _refresh(context),
                    ),
                    ProcurementReportsTab(
                      onRefresh: () async => _refresh(context, includeReport: true),
                    ),
                  ],
                ),
              if (state.status == ProcurementStatus.loading &&
                  state.purchaseOrders.isNotEmpty)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
              ),
            ],
          ),
          floatingActionButton: _tabController.index == 0 && (canCreate || canReceive)
              ? FloatingActionButton.extended(
                  onPressed: () => _showNewProcurementSheet(
                    context,
                    canCreate: canCreate,
                    canReceive: canReceive,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvel achat'),
                )
              : _tabController.index == 1 && canReceive
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<ProcurementBloc>(),
                              child: const DirectProcurementPage(),
                            ),
                          ),
                        ).then((_) => _refresh(context));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvel appro direct'),
                    )
                  : _tabController.index == 2 && canCreate
                  ? FloatingActionButton.extended(
                      onPressed: () => openSupplierFormPage(context),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Ajouter Fournisseur'),
                    )
                  : null,
        ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// KPI Summary Banner
// ---------------------------------------------------------------------------
class _OrderSummaryBanner extends StatelessWidget {
  const _OrderSummaryBanner({required this.orders});
  final List<PurchaseOrder> orders;

  @override
  Widget build(BuildContext context) {
    final pending = orders
        .where((o) =>
            o.status == PurchaseOrderStatus.validated ||
            o.status == PurchaseOrderStatus.sent ||
            o.status == PurchaseOrderStatus.partiallyReceived)
        .length;
    final totalPending = orders
        .where((o) =>
            o.status == PurchaseOrderStatus.validated ||
            o.status == PurchaseOrderStatus.sent)
        .fold<int>(0, (sum, o) => sum + o.total);
    final received = orders
        .where((o) => o.status == PurchaseOrderStatus.received)
        .length;

    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: _KpiMini(
                label: 'En attente',
                value: '$pending',
                icon: Icons.hourglass_top_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _KpiMini(
                label: 'Réceptionnées',
                value: '$received',
                icon: Icons.inventory_2_outlined,
                color: Colors.green.shade600,
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _KpiMini(
                label: 'Montant attendu',
                value: formatFcfa(totalPending),
                icon: Icons.payments_outlined,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Orders Tab
// ---------------------------------------------------------------------------
class _OrdersTab extends StatefulWidget {
  const _OrdersTab({
    required this.orders,
    required this.suppliers,
    required this.canCreate,
    required this.onRefresh,
  });
  final List<PurchaseOrder> orders;
  final List<Supplier> suppliers;
  final bool canCreate;
  final Future<void> Function() onRefresh;

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  PurchaseOrderStatus? _statusFilter;
  int? _supplierFilter;

  void _applyFilters() {
    context.read<ProcurementBloc>().add(
          ProcurementOrdersLoadRequested(
            supplierId: _supplierFilter,
            status: _statusFilter,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<PurchaseOrderStatus?>(
                  isExpanded: true,
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous les statuts'),
                    ),
                    ...PurchaseOrderStatus.values.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  isExpanded: true,
                  value: _supplierFilter,
                  decoration: const InputDecoration(
                    labelText: 'Fournisseur',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous'),
                    ),
                    ...widget.suppliers.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _supplierFilter = v);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _OrdersList(
            orders: orders,
            canCreate: widget.canCreate,
            onRefresh: widget.onRefresh,
          ),
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.canCreate,
    required this.onRefresh,
  });

  final List<PurchaseOrder> orders;
  final bool canCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EmptyListPlaceholder(
                      title: 'Aucune commande d\'approvisionnement.',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (canCreate)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, AppSizes.controlHeight),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Créer une commande'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<ProcurementBloc>(),
                                child: const PoFormPage(),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: orders.length + 1, // +1 for summary banner
        itemBuilder: (context, index) {
          if (index == 0) {
            return _OrderSummaryBanner(orders: orders);
          }
          final po = orders[index - 1];
          return _OrderCard(po: po);
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.po});
  final PurchaseOrder po;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateTime.fromMillisecondsSinceEpoch(po.orderedAt)
        .toLocal()
        .toString()
        .substring(0, 10);

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ProcurementBloc>(),
                child: PoDetailPage(poId: po.id),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commande #${po.number}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ProcurementSyncBadge(
                    kind: ProcurementSyncEntityKind.purchaseOrder,
                    localId: po.id,
                    serverId: po.serverId,
                  ),
                  const SizedBox(width: 4),
                  _StatusBadge(status: po.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      po.supplierName ?? 'Fournisseur #${po.supplierId}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.calendar_today_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(dateStr, style: theme.textTheme.bodySmall),
                  if (po.expectedAt != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.event_outlined,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Prévu ${DateTime.fromMillisecondsSinceEpoch(po.expectedAt!).toLocal().toString().substring(0, 10)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formatFcfa(po.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Direct Receipts Tab
// ---------------------------------------------------------------------------
class _DirectReceiptsTab extends StatefulWidget {
  const _DirectReceiptsTab({
    required this.receipts,
    required this.suppliers,
    required this.canReceive,
    required this.onRefresh,
  });

  final List<PurchaseReceipt> receipts;
  final List<Supplier> suppliers;
  final bool canReceive;
  final Future<void> Function() onRefresh;

  @override
  State<_DirectReceiptsTab> createState() => _DirectReceiptsTabState();
}

class _DirectReceiptsTabState extends State<_DirectReceiptsTab> {
  int? _supplierFilter;

  void _applyFilters() {
    context.read<ProcurementBloc>().add(
          ProcurementDirectReceiptsLoadRequested(supplierId: _supplierFilter),
        );
  }

  int _receiptTotal(PurchaseReceipt receipt) {
    return (receipt.items ?? []).fold<int>(
      0,
      (sum, item) => sum + item.quantityReceived * item.unitCost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final receipts = widget.receipts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: DropdownButtonFormField<int?>(
            isExpanded: true,
            value: _supplierFilter,
            decoration: const InputDecoration(
              labelText: 'Fournisseur',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les fournisseurs'),
              ),
              ...widget.suppliers.map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() => _supplierFilter = v);
              _applyFilters();
            },
          ),
        ),
        Expanded(
          child: _DirectReceiptsList(
            receipts: receipts,
            canReceive: widget.canReceive,
            receiptTotal: _receiptTotal,
            onRefresh: widget.onRefresh,
          ),
        ),
      ],
    );
  }
}

class _DirectReceiptsList extends StatelessWidget {
  const _DirectReceiptsList({
    required this.receipts,
    required this.canReceive,
    required this.receiptTotal,
    required this.onRefresh,
  });

  final List<PurchaseReceipt> receipts;
  final bool canReceive;
  final int Function(PurchaseReceipt) receiptTotal;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EmptyListPlaceholder(
                      title: 'Aucun approvisionnement direct.',
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (canReceive)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, AppSizes.controlHeight),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Nouvel approvisionnement'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<ProcurementBloc>(),
                                child: const DirectProcurementPage(),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: 80,
        ),
        itemCount: receipts.length,
        itemBuilder: (context, index) {
          final receipt = receipts[index];
          return _DirectReceiptCard(
            receipt: receipt,
            total: receiptTotal(receipt),
          );
        },
      ),
    );
  }
}

class _DirectReceiptCard extends StatelessWidget {
  const _DirectReceiptCard({
    required this.receipt,
    required this.total,
  });

  final PurchaseReceipt receipt;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateTime.fromMillisecondsSinceEpoch(receipt.receivedAt)
        .toLocal()
        .toString()
        .substring(0, 10);
    final itemCount = (receipt.items ?? []).fold<int>(
      0,
      (sum, item) => sum + item.quantityReceived,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ProcurementBloc>(),
                child: DirectReceiptDetailPage(receiptId: receipt.id),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'BR #${receipt.receiptNumber}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Direct',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ProcurementSyncBadge(
                    kind: ProcurementSyncEntityKind.receipt,
                    localId: receipt.id,
                    serverId: receipt.serverId,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      receipt.supplierName ??
                          'Fournisseur #${receipt.supplierId}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(dateStr, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '$itemCount unité(s)',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (receipt.receivedByName != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.person_outline,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        receipt.receivedByName!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formatFcfa(total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Suppliers Tab
// ---------------------------------------------------------------------------
class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab({
    required this.suppliers,
    required this.canCreate,
    required this.onRefresh,
  });
  final List<Supplier> suppliers;
  final bool canCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EmptyListPlaceholder(
                      title: 'Aucun fournisseur.',
                      icon: Icons.people_alt_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (canCreate)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, AppSizes.controlHeight),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un fournisseur'),
                        onPressed: () => openSupplierFormPage(context),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: 80),
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          final s = suppliers[index];
          final theme = Theme.of(context);
          final initials = s.name.trim().isNotEmpty
              ? s.name.trim()[0].toUpperCase()
              : '?';
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primaryContainer,
                foregroundColor:
                    theme.colorScheme.onPrimaryContainer,
                child: Text(
                  initials,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(
                s.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.phone != null && s.phone!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(s.phone!,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  if (s.email != null && s.email!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.email_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(s.email!,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!s.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Inactif',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  if (canCreate)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Modifier',
                      onPressed: () =>
                          openSupplierFormPage(context, supplier: s),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invoices Tab
// ---------------------------------------------------------------------------
class _InvoicesTab extends StatelessWidget {
  const _InvoicesTab({required this.invoices, required this.onRefresh});
  final List<SupplierInvoice> invoices;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const Center(
                child: EmptyListPlaceholder(
                  title: 'Aucune facture fournisseur.',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final inv = invoices[index];
          final theme = Theme.of(context);
          final dateStr =
              DateTime.fromMillisecondsSinceEpoch(inv.invoiceDate)
                  .toLocal()
                  .toString()
                  .substring(0, 10);

          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProcurementBloc>(),
                      child: InvoiceDetailPage(invoiceId: inv.id),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Facture #${inv.invoiceNumber}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ProcurementInvoiceStatusChip(
                          invoiceId: inv.id,
                          status: inv.status,
                          serverId: inv.serverId,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            inv.supplierName ??
                                'Fournisseur #${inv.supplierId}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.calendar_today_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(dateStr, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          formatFcfa(inv.total),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badges
// ---------------------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PurchaseOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      PurchaseOrderStatus.draft => (
          'Brouillon',
          Colors.grey.shade200,
          Colors.grey.shade700
        ),
      PurchaseOrderStatus.validated => (
          'Validé',
          Colors.orange.shade100,
          Colors.orange.shade800
        ),
      PurchaseOrderStatus.sent => (
          'Envoyé',
          Colors.blue.shade100,
          Colors.blue.shade800
        ),
      PurchaseOrderStatus.partiallyReceived => (
          'Partiel',
          Colors.amber.shade100,
          Colors.amber.shade900
        ),
      PurchaseOrderStatus.received => (
          'Reçu',
          Colors.green.shade100,
          Colors.green.shade800
        ),
      PurchaseOrderStatus.cancelled => (
          'Annulé',
          Colors.red.shade100,
          Colors.red.shade800
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
