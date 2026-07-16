import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';
import 'receive_items_page.dart';
import 'invoice_form_page.dart';
import 'po_form_page.dart';

class PoDetailPage extends StatefulWidget {
  const PoDetailPage({super.key, required this.poId});
  final int poId;

  @override
  State<PoDetailPage> createState() => _PoDetailPageState();
}

class _PoDetailPageState extends State<PoDetailPage> {
  _PoDetailSuccess? _pendingSuccess;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    context.read<ProcurementBloc>().add(ProcurementOrderDetailLoadRequested(widget.poId));
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.read<ProcurementBloc>().session.user.permissions;
    final canReceive = PermissionGuard.can(permissions, Permission.procurementReceive);
    final canUpdate = PermissionGuard.can(permissions, Permission.procurementUpdate);
    final canCancel = PermissionGuard.can(permissions, Permission.procurementCancel);
    final canInvoice = PermissionGuard.can(permissions, Permission.procurementInvoicePay);

    final canCreate = PermissionGuard.can(permissions, Permission.procurementCreate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la commande'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BlocConsumer<ProcurementBloc, ProcurementState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status ||
            (curr.status == ProcurementStatus.failure &&
                curr.errorMessage != null),
        listener: (context, state) async {
          if (state.status == ProcurementStatus.failure &&
              state.errorMessage != null) {
            _pendingSuccess = null;
            ProcurementFeedback.showErrorMessage(context, state.errorMessage!);
            return;
          }

          if (_pendingSuccess != null &&
              state.status == ProcurementStatus.loaded &&
              state.selectedOrder?.id == widget.poId) {
            final success = _pendingSuccess!;
            _pendingSuccess = null;
            await ProcurementFeedback.showSuccess(
              context: context,
              title: success.title,
              message: success.message,
            );
          }
        },
        builder: (context, state) {
          if (state.status == ProcurementStatus.loading && state.selectedOrder == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final po = state.selectedOrder;
          if (po == null || po.id != widget.poId) {
            return const Center(child: Text('Impossible de charger les détails.'));
          }

          final history = state.orderHistory;
          final receipts = state.orderReceipts;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Order Metadata Card
              _PoHeaderCard(po: po),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              _PoActionButtons(
                po: po,
                canCreate: canCreate,
                canUpdate: canUpdate,
                canReceive: canReceive,
                canCancel: canCancel,
                canInvoice: canInvoice,
                receipts: receipts,
                onActionConfirmed: (success) {
                  setState(() => _pendingSuccess = success);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Items Table Card
              _PoItemsCard(items: po.items ?? []),
              const SizedBox(height: AppSpacing.lg),

              // Receipts list
              if (receipts.isNotEmpty) ...[
                const Text('Réceptions enregistrées', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
                ...receipts.map((r) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping_outlined, color: Colors.green),
                        title: Text('BR #${r.receiptNumber}'),
                        subtitle: Text('Reçu le: ${DateTime.fromMillisecondsSinceEpoch(r.receivedAt).toLocal().toString().substring(0, 10)} par ${r.receivedByName ?? "ID #${r.receivedBy}"}'),
                        trailing: Text('${(r.items ?? []).fold<int>(0, (sum, i) => sum + i.quantityReceived)} art.'),
                      ),
                    )),
                const SizedBox(height: AppSpacing.lg),
              ],

              // History logs timeline
              const Text('Historique de la commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              if (history.isEmpty)
                const Text('Aucun historique enregistré.', style: TextStyle(fontStyle: FontStyle.italic))
              else
                ...history.map((h) {
                  final actionLabel = switch (h.action.toLowerCase()) {
                    'created' || 'create' || 'commande créée' => 'Création',
                    'updated' || 'update' || 'commande modifiée' => 'Modification',
                    'validated' || 'validate' || 'validation' => 'Validation',
                    'sent' || 'send' || 'envoi' => 'Envoi fournisseur',
                    'received' || 'receive' || 'réception' => 'Réception',
                    'cancelled' || 'cancel' || 'annulation' => 'Annulation',
                    'paiement' => 'Paiement',
                    _ => h.action,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lens, size: 10, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$actionLabel - ${DateTime.fromMillisecondsSinceEpoch(h.performedAt).toLocal().toString().substring(0, 16)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (h.details != null && h.details!.isNotEmpty)
                                Text(
                                  h.details!,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header Card widget
// ---------------------------------------------------------------------------
class _PoHeaderCard extends StatelessWidget {
  const _PoHeaderCard({required this.po});
  final PurchaseOrder po;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Commande #${po.number}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusTag(status: po.status),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _InfoRow(label: 'Fournisseur', value: po.supplierName ?? "ID #${po.supplierId}"),
            _InfoRow(label: 'Créée par', value: po.createdByName ?? "ID #${po.createdBy}"),
            _InfoRow(
              label: 'Date de commande',
              value: DateTime.fromMillisecondsSinceEpoch(po.orderedAt).toLocal().toString().substring(0, 10),
            ),
            if (po.expectedAt != null)
              _InfoRow(
                label: 'Livraison prévue',
                value: DateTime.fromMillisecondsSinceEpoch(po.expectedAt!).toLocal().toString().substring(0, 10),
              ),
            if (po.notes != null && po.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${po.notes}',
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
            const Divider(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Montant Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  formatFcfa(po.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Buttons widget
// ---------------------------------------------------------------------------
class _PoDetailSuccess {
  const _PoDetailSuccess({required this.title, this.message});

  final String title;
  final String? message;
}

class _PoActionButtons extends StatelessWidget {
  const _PoActionButtons({
    required this.po,
    required this.canCreate,
    required this.canUpdate,
    required this.canReceive,
    required this.canCancel,
    required this.canInvoice,
    required this.receipts,
    required this.onActionConfirmed,
  });

  final PurchaseOrder po;
  final bool canCreate;
  final bool canUpdate;
  final bool canReceive;
  final bool canCancel;
  final bool canInvoice;
  final List<PurchaseReceipt> receipts;
  final ValueChanged<_PoDetailSuccess> onActionConfirmed;

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[];

    // Status: draft -> Edit + Validate PO
    if (po.status == PurchaseOrderStatus.draft && canCreate) {
      list.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier la commande'),
          onPressed: () async {
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ProcurementBloc>(),
                  child: PoFormPage(orderToEdit: po),
                ),
              ),
            );
            if (updated == true && context.mounted) {
              context
                  .read<ProcurementBloc>()
                  .add(ProcurementOrderDetailLoadRequested(po.id));
            }
          },
        ),
      );
    }

    if (po.status == PurchaseOrderStatus.draft && canUpdate) {
      list.add(
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Valider la commande'),
          onPressed: () => _confirmValidate(context),
        ),
      );
    }

    // Status: validated -> Send to Supplier
    if (po.status == PurchaseOrderStatus.validated && canUpdate) {
      list.add(
        FilledButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Envoyer au fournisseur'),
          onPressed: () => _confirmSend(context),
        ),
      );
    }

    // Status: sent or partially_received -> Receive delivery
    if ((po.status == PurchaseOrderStatus.sent || po.status == PurchaseOrderStatus.partiallyReceived) && canReceive) {
      list.add(
        FilledButton.icon(
          icon: const Icon(Icons.local_shipping),
          label: const Text('Réceptionner des articles'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ProcurementBloc>(),
                  child: ReceiveItemsPage(po: po),
                ),
              ),
            );
          },
        ),
      );
    }

    // Status: validated, sent, partially_received, received -> Generate Invoice
    if ((po.status == PurchaseOrderStatus.validated ||
            po.status == PurchaseOrderStatus.sent ||
            po.status == PurchaseOrderStatus.partiallyReceived ||
            po.status == PurchaseOrderStatus.received) &&
        canInvoice) {
      list.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.receipt),
          label: const Text('Facturer la commande'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ProcurementBloc>(),
                  child: InvoiceFormPage(po: po),
                ),
              ),
            );
          },
        ),
      );
    }

    // Cancel action
    if (po.status != PurchaseOrderStatus.cancelled && po.status != PurchaseOrderStatus.received && canCancel) {
      list.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          label: const Text('Annuler la commande', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          onPressed: () => _confirmCancel(context),
        ),
      );
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: list.map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: w)).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmValidate(BuildContext context) async {
    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: 'Valider la commande ?',
      message:
          'La commande #${po.number} (${formatFcfa(po.total)}) passera au statut '
          '« Validé ». Vous pourrez ensuite l\'envoyer au fournisseur.',
      confirmLabel: 'Valider',
    );
    if (confirmed != true || !context.mounted) return;

    onActionConfirmed(
      _PoDetailSuccess(
        title: 'Commande validée',
        message: 'La commande #${po.number} est prête à être envoyée.',
      ),
    );
    context.read<ProcurementBloc>().add(ProcurementOrderValidateRequested(po.id));
  }

  Future<void> _confirmSend(BuildContext context) async {
    final supplier = po.supplierName ?? 'le fournisseur #${po.supplierId}';
    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: 'Envoyer au fournisseur ?',
      message:
          'Marquer la commande #${po.number} (${formatFcfa(po.total)}) comme '
          'envoyée à $supplier ?',
      confirmLabel: 'Confirmer l\'envoi',
    );
    if (confirmed != true || !context.mounted) return;

    onActionConfirmed(
      _PoDetailSuccess(
        title: 'Commande envoyée',
        message: 'La commande #${po.number} est en attente de livraison.',
      ),
    );
    context.read<ProcurementBloc>().add(ProcurementOrderSendRequested(po.id));
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final reason = await ProcurementFeedback.confirmWithReason(
      context: context,
      title: 'Annuler la commande',
      hint: 'Motif de l\'annulation (obligatoire)',
      confirmLabel: 'Confirmer l\'annulation',
      minLength: 5,
    );
    if (reason == null || !context.mounted) return;

    onActionConfirmed(
      _PoDetailSuccess(
        title: 'Commande annulée',
        message: 'La commande #${po.number} a été annulée.',
      ),
    );
    context.read<ProcurementBloc>().add(
          ProcurementOrderCancelRequested(
            poId: po.id,
            reason: reason,
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Items Card widget
// ---------------------------------------------------------------------------
class _PoItemsCard extends StatelessWidget {
  const _PoItemsCard({required this.items});
  final List<PurchaseOrderItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Articles commandés',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final it = items[idx];
                final progress = it.quantityReceived / it.quantityOrdered;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              it.productName ?? "Produit #${it.productId}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            formatFcfa(it.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Prix d\'achat unitaire : ${formatFcfa(it.unitCost)}'),
                          Text(
                            'Reçu: ${it.quantityReceived} / ${it.quantityOrdered}',
                            style: TextStyle(
                              color: it.quantityReceived == it.quantityOrdered ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        color: it.quantityReceived == it.quantityOrdered ? Colors.green : Colors.orange,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});
  final PurchaseOrderStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case PurchaseOrderStatus.draft:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
      case PurchaseOrderStatus.validated:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
      case PurchaseOrderStatus.sent:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
      case PurchaseOrderStatus.partiallyReceived:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
      case PurchaseOrderStatus.received:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
      case PurchaseOrderStatus.cancelled:
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

