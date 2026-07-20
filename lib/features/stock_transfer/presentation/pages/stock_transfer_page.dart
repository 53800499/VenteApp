import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/stock_transfer_repository.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../bloc/stock_transfer_bloc.dart';
import 'stock_transfer_detail_page.dart';
import 'stock_transfer_form_page.dart';
import 'stock_transfer_qr_scan_page.dart';

class StockTransferPage extends StatelessWidget {
  const StockTransferPage({super.key, this.session});

  /// Session figée (navigation legacy). Préférer [AuthBloc] quand disponible.
  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    ensureStockTransferDependencies();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final activeSession = authState is AuthAuthenticated
            ? authState.session
            : session;
        if (activeSession == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return BlocProvider(
          key: ValueKey('stock-transfer-${activeSession.shop.apiShopId}'),
          create: (_) => StockTransferBloc(
            repository: sl<StockTransferRepository>(),
            session: activeSession,
            syncPolicy: sl<SyncPolicy>(),
            syncService: sl<SyncService>(),
          )..add(const StockTransferListLoadRequested()),
          child: const _StockTransferView(),
        );
      },
    );
  }
}

class _StockTransferView extends StatefulWidget {
  const _StockTransferView();

  @override
  State<_StockTransferView> createState() => _StockTransferViewState();
}

class _StockTransferViewState extends State<_StockTransferView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<StockTransferBloc>().session;
    final canCreate = PermissionGuard.can(
      session.user.permissions,
      Permission.inventoryTransferCreate,
    );
    final canReceive = PermissionGuard.can(
      session.user.permissions,
      Permission.inventoryTransferReceive,
    );

    return BlocListener<StockTransferBloc, StockTransferState>(
      listenWhen: (prev, curr) =>
          prev.errorMessage != curr.errorMessage && curr.errorMessage != null,
      listener: (context, state) {
        if (state.errorMessage == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transferts inter-boutiques'),
          actions: const [
            ModuleHelpButton(
              articleId: 'stock_transfers',
              tooltip: 'Guide transferts inter-boutiques',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Sortants'),
              Tab(text: 'En transit'),
              Tab(text: 'Entrants'),
              Tab(text: 'Rapports'),
            ],
          ),
        ),
        floatingActionButton: _buildFab(context, canCreate, canReceive),
        body: BlocBuilder<StockTransferBloc, StockTransferState>(
          builder: (context, state) {
            if (state.status == StockTransferBlocStatus.loading &&
                state.outgoing.isEmpty &&
                state.incoming.isEmpty &&
                state.inTransit.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _TransferList(
                  transfers: state.outgoing,
                  emptyMessage: 'Aucun transfert sortant.',
                  emptySubtitle:
                      'Tirez vers le bas pour charger depuis le serveur.',
                  onRefresh: () => _refreshFromServer(context),
                  onTap: (t) => _openDetail(context, t.id),
                  shopLabelPrefix: 'Vers',
                  shopLabelFor: (t) => t.destinationShopLabel,
                ),
                _TransferList(
                  transfers: state.inTransit,
                  emptyMessage: 'Aucun transfert en transit.',
                  emptySubtitle:
                      'Expéditions partielles ou complètes en attente de réception.',
                  onRefresh: () => _refreshFromServer(context),
                  onTap: (t) => _openDetail(context, t.id),
                ),
                _TransferList(
                  transfers: state.incoming,
                  emptyMessage: 'Aucun transfert entrant.',
                  emptySubtitle:
                      'Les transferts à votre destination apparaissent ici '
                      '(validés, expédiés ou reçus). '
                      'Tirez vers le bas pour synchroniser.',
                  onRefresh: () => _refreshFromServer(context),
                  onTap: (t) => _openDetail(context, t.id),
                  shopLabelPrefix: 'De',
                  shopLabelFor: (t) => t.sourceShopLabel,
                ),
                _ReportTab(
                  report: state.reportSummary,
                  onRefresh: () => _refreshFromServer(context),
                  onOpenTransfer: (id) => _openDetail(context, id),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget? _buildFab(BuildContext context, bool canCreate, bool canReceive) {
    if (_tabController.index == 2 && canReceive) {
      return FloatingActionButton.extended(
        onPressed: () => _openQrScan(context),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scanner QR'),
      );
    }
    if (!canCreate) return null;
    return FloatingActionButton.extended(
      onPressed: () async {
        final created = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<StockTransferBloc>(),
              child: const StockTransferFormPage(),
            ),
          ),
        );
        if (created == true && context.mounted) {
          context
              .read<StockTransferBloc>()
              .add(const StockTransferListRefreshRequested(forceRemote: false));
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Nouveau transfert'),
    );
  }

  Future<void> _openQrScan(BuildContext context) async {
    ensureStockTransferDependencies();
    final bloc = context.read<StockTransferBloc>();
    final intent = await Navigator.of(context).push<StockTransferQrReceiveIntent>(
      MaterialPageRoute(
        builder: (_) => StockTransferQrScanPage(
          repository: sl<StockTransferRepository>(),
          shopId: bloc.shopId,
        ),
      ),
    );
    if (intent == null || !context.mounted) return;
    _openDetail(
      context,
      intent.transferId,
      initialReceiveQuantities: intent.quantitiesByItemId,
      initialShipmentId: intent.shipmentId,
    );
  }

  Future<void> _refreshFromServer(BuildContext context) async {
    final bloc = context.read<StockTransferBloc>();
    bloc.add(const StockTransferListRefreshRequested());
    await bloc.stream.firstWhere(
      (state) =>
          !state.isRefreshing &&
          (state.status == StockTransferBlocStatus.loaded ||
              state.status == StockTransferBlocStatus.failure),
    );
  }

  void _openDetail(
    BuildContext context,
    int transferId, {
    Map<int, int>? initialReceiveQuantities,
    int? initialShipmentId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<StockTransferBloc>(),
          child: StockTransferDetailPage(
            transferId: transferId,
            initialReceiveQuantities: initialReceiveQuantities,
            initialShipmentId: initialShipmentId,
          ),
        ),
      ),
    );
  }
}

class _TransferList extends StatelessWidget {
  const _TransferList({
    required this.transfers,
    required this.emptyMessage,
    required this.onRefresh,
    this.emptySubtitle,
    this.onTap,
    this.shopLabelPrefix,
    this.shopLabelFor,
  });

  final List<StockTransfer> transfers;
  final String emptyMessage;
  final String? emptySubtitle;
  final Future<void> Function() onRefresh;
  final void Function(StockTransfer)? onTap;
  final String? shopLabelPrefix;
  final String Function(StockTransfer)? shopLabelFor;

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: EmptyListPlaceholder(
                icon: Icons.swap_horiz_outlined,
                title: emptyMessage,
                subtitle: emptySubtitle,
                embedded: true,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: transfers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final t = transfers[index];
          return _TransferTile(
            transfer: t,
            onTap: onTap == null ? null : () => onTap!(t),
            shopLine: shopLabelPrefix != null && shopLabelFor != null
                ? '$shopLabelPrefix : ${shopLabelFor!(t)}'
                : null,
          );
        },
      ),
    );
  }
}

class _ReportTab extends StatelessWidget {
  const _ReportTab({
    required this.report,
    required this.onRefresh,
    required this.onOpenTransfer,
  });

  final StockTransferReportSummary? report;
  final Future<void> Function() onRefresh;
  final void Function(int transferId) onOpenTransfer;

  @override
  Widget build(BuildContext context) {
    final r = report;
    if (r == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _StatCard(
            title: 'Transferts',
            value: '${r.totalTransfers}',
            icon: Icons.swap_horiz,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatCard(
            title: 'En transit',
            value: '${r.inTransitCount}',
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatCard(
            title: 'Écarts détectés',
            value: '${r.discrepancyCount}',
            icon: Icons.warning_amber_outlined,
            highlight: r.discrepancyCount > 0,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatCard(
            title: 'Unités expédiées / reçues',
            value: '${r.totalUnitsShipped} / ${r.totalUnitsReceived}',
            icon: Icons.inventory_2_outlined,
          ),
          if (r.discrepancies.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Alertes écart',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...r.discrepancies.map(
              (d) => Card(
                child: ListTile(
                  onTap: () => onOpenTransfer(d.transferId),
                  title: Text(d.reference),
                  subtitle: Text('${d.productName} · manque ${d.gap} u'),
                  trailing: Text(
                    StockTransferStatus.label(d.status),
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? Colors.amber.shade50 : null,
      child: ListTile(
        leading: Icon(icon, color: highlight ? Colors.amber.shade800 : null),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({
    required this.transfer,
    this.onTap,
    this.shopLine,
  });

  final StockTransfer transfer;
  final VoidCallback? onTap;
  final String? shopLine;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateTime.fromMillisecondsSinceEpoch(transfer.createdAt)
        .toLocal()
        .toString()
        .substring(0, 16);
    final statusColor = switch (transfer.status) {
      StockTransferStatus.draft => Colors.grey,
      StockTransferStatus.validated => Colors.blue,
      StockTransferStatus.partiallyShipped => Colors.deepOrange,
      StockTransferStatus.shipped => Colors.orange,
      StockTransferStatus.partiallyReceived => Colors.amber,
      StockTransferStatus.received => Colors.green,
      StockTransferStatus.closed => Colors.blueGrey,
      StockTransferStatus.closedWithException => Colors.deepOrange,
      StockTransferStatus.cancelled => Colors.red,
      _ => Colors.grey,
    };

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          transfer.reference,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            '${StockTransferType.label(transfer.transferType)} · '
            '${transfer.sourceShopLabel} → ${transfer.destinationShopLabel}',
            if (shopLine != null) shopLine!,
            dateStr,
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                StockTransferStatus.label(transfer.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (transfer.hasDiscrepancy) ...[
                const SizedBox(height: 2),
                Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: Colors.amber.shade800,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
