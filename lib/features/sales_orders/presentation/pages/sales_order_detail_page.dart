import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../sales/presentation/pages/sale_detail_page.dart';
import '../../domain/entities/sales_order.dart';
import '../bloc/sales_order_bloc.dart';
import 'sales_order_deliver_page.dart';

class SalesOrderDetailPage extends StatefulWidget {
  const SalesOrderDetailPage({
    super.key,
    required this.session,
    required this.orderId,
  });

  final AuthSession session;
  final int orderId;

  @override
  State<SalesOrderDetailPage> createState() => _SalesOrderDetailPageState();
}

class _SalesOrderDetailPageState extends State<SalesOrderDetailPage> {
  _SoDetailSuccess? _pendingSuccess;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    context
        .read<SalesOrderBloc>()
        .add(SalesOrderDetailRequested(widget.orderId));
  }

  bool get _canWrite => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesOrdersWrite,
      );

  bool get _canDeliver => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesOrdersDeliver,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la commande'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          const AppHeaderActions(),
        ],
      ),
      body: BlocConsumer<SalesOrderBloc, SalesOrderState>(
        listenWhen: (prev, curr) =>
            prev.errorMessage != curr.errorMessage ||
            prev.successMessage != curr.successMessage ||
            prev.saving != curr.saving,
        listener: (context, state) async {
          if (state.errorMessage != null) {
            _pendingSuccess = null;
            await ActionFeedback.showErrorDialog(
              context,
              title: 'Action impossible',
              message: state.errorMessage!,
            );
            if (context.mounted) {
              context
                  .read<SalesOrderBloc>()
                  .add(const SalesOrderFeedbackCleared());
            }
            return;
          }

          if (_pendingSuccess != null &&
              state.successMessage != null &&
              !state.saving) {
            final success = _pendingSuccess!;
            _pendingSuccess = null;
            await ActionFeedback.showSuccess(
              context: context,
              title: success.title,
              message: success.message,
            );
            if (context.mounted) {
              context
                  .read<SalesOrderBloc>()
                  .add(const SalesOrderFeedbackCleared());
            }
          } else if (state.successMessage != null && _pendingSuccess == null) {
            // Succès sans pending (ex. retour livraison) — snackbar légère.
            ActionFeedback.showInfo(context, state.successMessage!);
            context
                .read<SalesOrderBloc>()
                .add(const SalesOrderFeedbackCleared());
          }
        },
        builder: (context, state) {
          final order = state.selected;
          if (state.detailLoading &&
              (order == null || order.id != widget.orderId)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (order == null || order.id != widget.orderId) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Commande introuvable'),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _SoHeaderCard(order: order),
                  const SizedBox(height: AppSpacing.lg),
                  _SoFulfillmentSummary(order: order),
                  const SizedBox(height: AppSpacing.lg),
                  _SoActionButtons(
                    order: order,
                    canWrite: _canWrite,
                    canDeliver: _canDeliver,
                    saving: state.saving,
                    session: widget.session,
                    onActionConfirmed: (success) {
                      setState(() => _pendingSuccess = success);
                    },
                    onDelivered: _refresh,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SoItemsCard(items: order.items),
                  if (order.deliveries.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _SoDeliveriesSection(
                      deliveries: order.deliveries,
                      session: widget.session,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _SoHistorySection(history: order.history),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
              if (state.saving)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SoDetailSuccess {
  const _SoDetailSuccess({required this.title, this.message});

  final String title;
  final String? message;
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _SoHeaderCard extends StatelessWidget {
  const _SoHeaderCard({required this.order});

  final SalesOrder order;

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
                    order.number,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _SoStatusTag(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            _InfoRow(label: 'Client', value: order.customerName),
            _InfoRow(label: 'Total', value: formatFcfa(order.total)),
            _InfoRow(
              label: 'Commandée le',
              value: _formatDate(order.orderedAt),
            ),
            if (order.notes != null && order.notes!.trim().isNotEmpty)
              _InfoRow(label: 'Notes', value: order.notes!.trim()),
          ],
        ),
      ),
    );
  }
}

class _SoFulfillmentSummary extends StatelessWidget {
  const _SoFulfillmentSummary({required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context) {
    final ordered = order.totalOrdered;
    final delivered = order.totalDelivered;
    final refused = order.totalRefused;
    final remaining = order.totalRemaining;
    final progress = ordered <= 0 ? 0.0 : (delivered + refused) / ordered;
    final done = remaining <= 0 && ordered > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Avancement livraison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Commandé',
                    value: '$ordered',
                  ),
                ),
                Expanded(
                  child: _MetricChip(
                    label: 'Livré',
                    value: '$delivered',
                    emphasize: delivered > 0,
                  ),
                ),
                Expanded(
                  child: _MetricChip(
                    label: 'Refusé',
                    value: '$refused',
                  ),
                ),
                Expanded(
                  child: _MetricChip(
                    label: 'Reste',
                    value: '$remaining',
                    emphasize: remaining > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: done ? Colors.green : Colors.orange,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              done
                  ? 'Commande entièrement traitée'
                  : '${((progress * 100).clamp(0, 100)).toStringAsFixed(0)} % traité',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: emphasize
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Actions (confirmations)
// ---------------------------------------------------------------------------

class _SoActionButtons extends StatelessWidget {
  const _SoActionButtons({
    required this.order,
    required this.canWrite,
    required this.canDeliver,
    required this.saving,
    required this.session,
    required this.onActionConfirmed,
    required this.onDelivered,
  });

  final SalesOrder order;
  final bool canWrite;
  final bool canDeliver;
  final bool saving;
  final AuthSession session;
  final ValueChanged<_SoDetailSuccess> onActionConfirmed;
  final VoidCallback onDelivered;

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[];

    if (canWrite && order.canConfirm) {
      list.add(
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Confirmer la commande'),
          onPressed: saving ? null : () => _confirmConfirm(context),
        ),
      );
    }

    if (canWrite && order.status == SalesOrderStatus.confirmed) {
      list.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Mettre en préparation'),
          onPressed: saving ? null : () => _confirmPrepare(context),
        ),
      );
    }

    if (canDeliver && order.canDeliver) {
      list.add(
        FilledButton.icon(
          icon: const Icon(Icons.local_shipping),
          label: const Text('Nouvelle livraison'),
          onPressed: saving ? null : () => _confirmOpenDelivery(context),
        ),
      );
    }

    if (canWrite && order.canClose) {
      list.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.lock_outline),
          label: const Text('Clôturer la commande'),
          onPressed: saving ? null : () => _confirmClose(context),
        ),
      );
    }

    if (canWrite && order.canCancel) {
      list.add(
        OutlinedButton.icon(
          icon: Icon(
            Icons.cancel_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          label: Text(
            'Annuler la commande',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          onPressed: saving ? null : () => _confirmCancel(context),
        ),
      );
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            ...list.map(
              (w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: w,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmConfirm(BuildContext context) async {
    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Confirmer la commande ?',
      message:
          'La commande ${order.number} (${formatFcfa(order.total)}) pour '
          '${order.customerName} passera au statut « Confirmée ». '
          'Aucune sortie de stock pour l’instant.',
      confirmLabel: 'Confirmer',
    );
    if (confirmed != true || !context.mounted) return;

    onActionConfirmed(
      _SoDetailSuccess(
        title: 'Commande confirmée',
        message: '${order.number} est prête pour la préparation / livraison.',
      ),
    );
    context
        .read<SalesOrderBloc>()
        .add(SalesOrderConfirmRequested(order.id));
  }

  Future<void> _confirmPrepare(BuildContext context) async {
    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Mettre en préparation ?',
      message:
          'Marquer ${order.number} comme « Préparation » '
          '(${order.totalRemaining} article(s) restant(s)) ?',
      confirmLabel: 'Mettre en préparation',
    );
    if (confirmed != true || !context.mounted) return;

    onActionConfirmed(
      const _SoDetailSuccess(
        title: 'En préparation',
        message: 'La commande est en cours de préparation.',
      ),
    );
    context
        .read<SalesOrderBloc>()
        .add(SalesOrderPrepareRequested(order.id));
  }

  Future<void> _confirmOpenDelivery(BuildContext context) async {
    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Nouvelle livraison ?',
      message:
          'Vous allez enregistrer une livraison pour ${order.number}.\n'
          'Reste à livrer : ${order.totalRemaining} / ${order.totalOrdered}.\n\n'
          'Le stock ne diminuera qu’après validation de la livraison '
          '(quantités acceptées).',
      confirmLabel: 'Continuer',
    );
    if (confirmed != true || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SalesOrderBloc>(),
          child: SalesOrderDeliverPage(
            session: session,
            order: order,
          ),
        ),
      ),
    );
    if (context.mounted) onDelivered();
  }

  Future<void> _confirmClose(BuildContext context) async {
    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Clôturer la commande ?',
      message:
          '${order.number} est entièrement livrée. '
          'La clôture verrouille la commande (plus de modification).',
      confirmLabel: 'Clôturer',
    );
    if (confirmed != true || !context.mounted) return;

    onActionConfirmed(
      _SoDetailSuccess(
        title: 'Commande clôturée',
        message: '${order.number} est clôturée.',
      ),
    );
    context.read<SalesOrderBloc>().add(SalesOrderCloseRequested(order.id));
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final reason = await ActionFeedback.confirmWithReason(
      context: context,
      title: 'Annuler la commande',
      hint: 'Motif de l’annulation (obligatoire)',
      confirmLabel: 'Confirmer l’annulation',
      minLength: 5,
    );
    if (reason == null || !context.mounted) return;

    onActionConfirmed(
      _SoDetailSuccess(
        title: 'Commande annulée',
        message: '${order.number} a été annulée.',
      ),
    );
    context.read<SalesOrderBloc>().add(
          SalesOrderCancelRequested(order.id, reason: reason),
        );
  }
}

// ---------------------------------------------------------------------------
// Items
// ---------------------------------------------------------------------------

class _SoItemsCard extends StatelessWidget {
  const _SoItemsCard({required this.items});

  final List<SalesOrderItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Articles commandés',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            ...items.map((it) {
              final treated = it.quantityDelivered +
                  it.quantityRefused +
                  it.quantityReplaced;
              final progress = it.quantityOrdered <= 0
                  ? 0.0
                  : treated / it.quantityOrdered;
              final complete = it.quantityRemaining <= 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            it.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          formatFcfa(it.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prix unitaire : ${formatFcfa(it.unitPrice)}'
                      '${it.quantityInStock != null ? ' · stock ${it.quantityInStock}' : ''}',
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Livré ${it.quantityDelivered} · '
                            'Refusé ${it.quantityRefused} · '
                            'Remplacé ${it.quantityReplaced} · '
                            'Reste ${it.quantityRemaining}',
                            style: TextStyle(
                              color: complete ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text('${it.quantityOrdered} cmd'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      color: complete ? Colors.green : Colors.orange,
                      backgroundColor: Colors.grey.shade200,
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
// Deliveries & history
// ---------------------------------------------------------------------------

class _SoDeliveriesSection extends StatelessWidget {
  const _SoDeliveriesSection({
    required this.deliveries,
    required this.session,
  });

  final List<SalesOrderDelivery> deliveries;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Livraisons enregistrées',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Divider(),
        ...deliveries.map((d) {
          final accepted = d.items.fold<int>(
            0,
            (s, i) => s + i.quantityAccepted,
          );
          final refused = d.items.fold<int>(
            0,
            (s, i) => s + i.quantityRefused,
          );
          final replaced = d.items.fold<int>(
            0,
            (s, i) => s + i.quantityReplaced,
          );
          final lineHints = d.items
              .where(
                (i) =>
                    i.quantityRefused > 0 ||
                    i.quantityReplaced > 0,
              )
              .map((i) {
                final parts = <String>[];
                if (i.quantityRefused > 0) {
                  parts.add(
                    'refus ${i.quantityRefused}'
                    '${i.refusalDestination != null ? ' (${i.refusalDestination!.labelFr})' : ''}',
                  );
                }
                if (i.quantityReplaced > 0) {
                  parts.add(
                    '→ ${i.replacementProductName ?? 'produit'} ×${i.quantityReplaced}',
                  );
                }
                return '${i.productName}: ${parts.join(', ')}';
              })
              .toList();
          final meta = <String>[
            if (d.driverName != null && d.driverName!.trim().isNotEmpty)
              'Chauffeur : ${d.driverName!.trim()}',
            if (d.vehiclePlate != null && d.vehiclePlate!.trim().isNotEmpty)
              'Véhicule : ${d.vehiclePlate!.trim()}',
            if (d.remainingReason != null)
              'Reliquat : ${d.remainingReason!.labelFr}',
            if (d.notes != null && d.notes!.trim().isNotEmpty)
              'Notes : ${d.notes!.trim()}',
            ...lineHints,
          ];
          return Card(
            child: ListTile(
              leading: Icon(
                Icons.local_shipping_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                d.number,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${_formatDate(d.deliveredAt)}\n'
                'Accepté $accepted · Refusé $refused · Remplacé $replaced'
                '${d.saleId != null ? ' · Vente #${d.saleId}' : ''}'
                '${meta.isEmpty ? '' : '\n${meta.join(' · ')}'}',
              ),
              isThreeLine: true,
              trailing: d.saleId == null
                  ? null
                  : TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SaleDetailPage(
                              session: session,
                              saleId: d.saleId!,
                            ),
                          ),
                        );
                      },
                      child: const Text('Ouvrir la vente'),
                    ),
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return AppDateFormatter.formatDateTime(dt);
  }
}

class _SoHistorySection extends StatelessWidget {
  const _SoHistorySection({required this.history});

  final List<SalesOrderHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Historique de la commande',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Divider(),
        if (history.isEmpty)
          const Text(
            'Aucun historique enregistré.',
            style: TextStyle(fontStyle: FontStyle.italic),
          )
        else
          ...history.map((h) {
            final actionLabel =
                h.actionEnum?.labelFr ?? h.action;
            final payloadBits = <String>[];
            final p = h.payload;
            if (p != null) {
              final deliveryNumber = p['deliveryNumber'];
              if (deliveryNumber != null) {
                payloadBits.add('$deliveryNumber');
              }
              final remainingReason = p['remainingReason'];
              if (remainingReason != null) {
                payloadBits.add('reliquat: $remainingReason');
              }
              final reason = p['reason'];
              if (reason != null) {
                payloadBits.add('$reason');
              }
              final status = p['status'];
              if (status != null && deliveryNumber == null) {
                payloadBits.add('→ $status');
              }
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lens,
                    size: 10,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$actionLabel — ${_formatDate(h.performedAt)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (h.details != null && h.details!.isNotEmpty)
                          Text(
                            h.details!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (payloadBits.isNotEmpty)
                          Text(
                            payloadBits.join(' · '),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SoStatusTag extends StatelessWidget {
  const _SoStatusTag({required this.status});

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
      SalesOrderStatus.closed => (
          Colors.teal.shade100,
          Colors.teal.shade900
        ),
      SalesOrderStatus.cancelled => (
          Colors.red.shade100,
          Colors.red.shade800
        ),
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _formatDate(int ms) {
  if (ms <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal().toString();
  return d.length >= 16 ? d.substring(0, 16) : d;
}
