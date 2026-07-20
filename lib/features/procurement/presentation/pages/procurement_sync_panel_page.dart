import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/sync/sync_service.dart';
import '../../data/services/procurement_sync_status_service.dart';
import '../../domain/entities/procurement_sync_entities.dart';

/// Panneau dédié : file sync contextualisée du module approvisionnement.
class ProcurementSyncPanelPage extends StatefulWidget {
  const ProcurementSyncPanelPage({super.key, required this.shopId});

  final int shopId;

  @override
  State<ProcurementSyncPanelPage> createState() =>
      _ProcurementSyncPanelPageState();
}

class _ProcurementSyncPanelPageState extends State<ProcurementSyncPanelPage> {
  ProcurementSyncOverview? _overview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final overview =
        await sl<ProcurementSyncStatusService>().loadOverview(shopId: widget.shopId);
    if (mounted) {
      setState(() {
        _overview = overview;
        _loading = false;
      });
    }
  }

  Future<void> _syncAll() async {
    sl<SyncService>().scheduleSync(shopId: widget.shopId);
    await Future<void>.delayed(const Duration(seconds: 2));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync approvisionnement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (overview == null || !overview.hasIssues)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          'Tous les documents approvisionnement sont synchronisés.',
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      overview.errorCount > 0
                          ? '${overview.errorCount} élément(s) à vérifier'
                          : '${overview.pendingCount} envoi(s) en cours',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Vos opérations sont enregistrées localement. '
                      'Aucune ressaisie n\'est nécessaire dans la plupart des cas.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ...overview.items.map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: Icon(
                            _iconFor(item),
                            color: _colorFor(context, item),
                          ),
                          title: Text(item.label),
                          subtitle: item.detail != null
                              ? Text(item.detail!)
                              : null,
                          trailing: _trailingFor(item),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: _syncAll,
                    icon: const Icon(Icons.sync),
                    label: const Text('Tout synchroniser'),
                  ),
                ],
              ),
            ),
    );
  }

  IconData _iconFor(ProcurementSyncQueueItem item) {
    return switch (item.entityKind) {
      ProcurementSyncEntityKind.receipt => Icons.inventory_2_outlined,
      ProcurementSyncEntityKind.invoice => Icons.receipt_long_outlined,
      ProcurementSyncEntityKind.payment => Icons.payments_outlined,
      ProcurementSyncEntityKind.purchaseOrder => Icons.shopping_bag_outlined,
      ProcurementSyncEntityKind.supplier => Icons.storefront_outlined,
    };
  }

  Color _colorFor(BuildContext context, ProcurementSyncQueueItem item) {
    return switch (item.state) {
      ProcurementCloudSyncState.synced => Colors.green.shade700,
      ProcurementCloudSyncState.pending => Colors.orange.shade800,
      ProcurementCloudSyncState.error => Theme.of(context).colorScheme.error,
    };
  }

  Widget? _trailingFor(ProcurementSyncQueueItem item) {
    return switch (item.state) {
      ProcurementCloudSyncState.pending => const Icon(Icons.cloud_upload_outlined),
      ProcurementCloudSyncState.error => const Icon(Icons.warning_amber_outlined),
      ProcurementCloudSyncState.synced => const Icon(Icons.check),
    };
  }
}
