import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/database/app_database.dart' hide AuthSession;
import '../../../../core/security/production_message_policy.dart';
import '../../../../core/sync/sync_queue_datasource.dart';
import '../../../../core/sync/sync_queue_processor.dart';

import '../../../auth/domain/entities/auth_entities.dart';
import '../../../expenses/presentation/pages/expense_form_page.dart';
import '../../../inventory/presentation/pages/product_form_page.dart';
import '../../../customers/presentation/pages/customer_form_page.dart';
import '../../../sales/presentation/pages/quick_sale_page.dart';

class SyncResolutionCenterPage extends StatefulWidget {
  const SyncResolutionCenterPage({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<SyncResolutionCenterPage> createState() =>
      _SyncResolutionCenterPageState();
}

class _SyncResolutionCenterPageState
    extends State<SyncResolutionCenterPage> {
  late final SyncQueueDatasource _datasource;
  List<SyncQueueData> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _datasource = sl<SyncQueueDatasource>();
    _loadUnresolved();
  }

  Future<void> _loadUnresolved() async {
    setState(() => _loading = true);
    final items =
        await _datasource.listUnresolvedItems(widget.session.shop.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _retryItem(SyncQueueData item) async {
    await _datasource.retryQueueItem(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opération replacée en attente de sync.')),
    );
    await _loadUnresolved();
    unawaited(sl<SyncQueueProcessor>().process(
      shopId: widget.session.shop.id,
    ));
  }

  Future<void> _discardItem(SyncQueueData item) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner l\'opération ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'L\'opération sera enregistrée comme abandonnée pour l\'historique back-office.',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif d\'abandon (optionnel)',
                hintText: 'Ex: Produit introuvable, vente annulée...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer l\'abandon'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final reason = reasonController.text.trim().isEmpty
        ? 'Abandonné par l\'utilisateur'
        : reasonController.text.trim();

    await _datasource.markDiscarded(
      item.id,
      userId: widget.session.user.id,
      reason: reason,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opération abandonnée.')),
    );
    await _loadUnresolved();
  }

  Future<void> _editItem(SyncQueueData item) async {
    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;
      final table = item.entityTable.toLowerCase();

      bool? updated;

      if (table.contains('product')) {
        updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ProductFormPage(
              session: widget.session,
              initialPayload: payload,
            ),
          ),
        );
      } else if (table.contains('customer')) {
        updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CustomerFormPage(
              session: widget.session,
              initialPayload: payload,
            ),
          ),
        );
      } else if (table.contains('sale')) {
        updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => QuickSalePage(
              session: widget.session,
            ),
          ),
        );
      } else if (table.contains('expense')) {
        updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ExpenseFormPage(
              session: widget.session,
              categories: const [],
              initialPayload: payload,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Formulaire de modification non disponible pour ${item.entityTable}.',
            ),
          ),
        );
        return;
      }

      if (updated == true) {
        await _datasource.markDiscarded(
          item.id,
          userId: widget.session.user.id,
          reason: 'Remplacé par une nouvelle saisie corrigée',
        );
        await _loadUnresolved();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ProductionMessagePolicy.sanitize('Impossible d\'ouvrir la correction : $e'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opérations à résoudre'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUnresolved,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Toutes les opérations sont synchronisées !',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isActionReq = item.status == 'action_required';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isActionReq
                                      ? Icons.warning_amber_rounded
                                      : Icons.error_outline,
                                  color: isActionReq
                                      ? Colors.orange
                                      : Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    '${item.entityTable.toUpperCase()} #${item.recordId} (${item.operation})',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    isActionReq
                                        ? 'Action requise'
                                        : item.status,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: isActionReq
                                      ? Colors.orange.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                ),
                              ],
                            ),
                            if (item.lastError != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                ProductionMessagePolicy.sanitize(item.lastError!),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _discardItem(item),
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  label: const Text('Abandonner'),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                OutlinedButton.icon(
                                  onPressed: () => _retryItem(item),
                                  icon:
                                      const Icon(Icons.refresh, size: 18),
                                  label: const Text('Réessayer'),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                FilledButton.icon(
                                  onPressed: () => _editItem(item),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Modifier'),
                                ),
                              ],
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
