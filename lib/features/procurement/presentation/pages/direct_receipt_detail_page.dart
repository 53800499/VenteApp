import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';
import 'invoice_detail_page.dart';
import 'record_supplier_payment_page.dart';

class DirectReceiptDetailPage extends StatefulWidget {
  const DirectReceiptDetailPage({super.key, required this.receiptId});

  final int receiptId;

  @override
  State<DirectReceiptDetailPage> createState() =>
      _DirectReceiptDetailPageState();
}

class _DirectReceiptDetailPageState extends State<DirectReceiptDetailPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    context.read<ProcurementBloc>().add(
          ProcurementDirectReceiptDetailLoadRequested(widget.receiptId),
        );
  }

  int _receiptTotal(PurchaseReceipt receipt) {
    return (receipt.items ?? []).fold<int>(
      0,
      (sum, item) => sum + item.quantityReceived * item.unitCost,
    );
  }

  int _paidAmount(SupplierInvoice invoice) {
    return (invoice.payments ?? []).fold<int>(0, (sum, p) => sum + p.amount);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.read<ProcurementBloc>().session.user.permissions;
    final canPay =
        PermissionGuard.can(permissions, Permission.procurementInvoicePay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail approvisionnement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BlocConsumer<ProcurementBloc, ProcurementState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status &&
            curr.status == ProcurementStatus.failure &&
            curr.errorMessage != null,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ProcurementFeedback.showErrorMessage(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          final receipt = state.selectedDirectReceipt;
          if (receipt?.id == widget.receiptId) {
            return _buildReceiptContent(
              context,
              state,
              receipt!,
              canPay,
            );
          }

          if (state.status == ProcurementStatus.failure &&
              state.errorMessage != null) {
            return Center(child: Text(state.errorMessage!));
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildReceiptContent(
    BuildContext context,
    ProcurementState state,
    PurchaseReceipt receipt,
    bool canPay,
  ) {
          final invoice = state.selectedDirectReceiptInvoice;
          final total = _receiptTotal(receipt);
          final paid = invoice != null ? _paidAmount(invoice) : 0;
          final remaining = invoice != null ? invoice.total - paid : 0;
          final canRecordPayment = canPay &&
              invoice != null &&
              remaining > 0 &&
              invoice.status != SupplierInvoiceStatus.paid;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'BR #${receipt.receiptNumber}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.lg),
                      _InfoLine(
                        label: 'Fournisseur',
                        value: receipt.supplierName ??
                            'Fournisseur #${receipt.supplierId}',
                      ),
                      _InfoLine(
                        label: 'Date de réception',
                        value: _formatDate(receipt.receivedAt),
                      ),
                      _InfoLine(
                        label: 'Réceptionné par',
                        value: receipt.receivedByName ??
                            'Utilisateur #${receipt.receivedBy}',
                      ),
                      if (receipt.notes != null && receipt.notes!.isNotEmpty)
                        _InfoLine(label: 'Remarques', value: receipt.notes!),
                      const Divider(height: AppSpacing.lg),
                      _InfoLine(
                        label: 'Total',
                        value: formatFcfa(total),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Articles reçus',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Divider(),
              if ((receipt.items ?? []).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Aucun article enregistré.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...(receipt.items ?? []).map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? 'Produit #${item.productId}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Text(
                                '${item.quantityReceived} u · achat ${formatFcfa(item.unitCost)}/u',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              Text(
                                formatFcfa(
                                  item.quantityReceived * item.unitCost,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (item.batchNumber != null &&
                              item.batchNumber!.isNotEmpty)
                            Text(
                              'Lot : ${item.batchNumber}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (item.expiryDate != null)
                            Text(
                              'Expiration : ${_formatDate(item.expiryDate!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Facturation',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Divider(),
              if (invoice == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Aucune facture fournisseur liée à cet approvisionnement.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                )
              else ...[
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ProcurementBloc>(),
                            child: InvoiceDetailPage(invoiceId: invoice.id),
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
                                  'Facture #${invoice.invoiceNumber}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              _InvoiceStatusChip(status: invoice.status),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _InfoLine(
                            label: 'Montant facture',
                            value: formatFcfa(invoice.total),
                          ),
                          _InfoLine(
                            label: 'Payé',
                            value: formatFcfa(paid),
                            color: Colors.green.shade700,
                          ),
                          _InfoLine(
                            label: 'Solde restant',
                            value: formatFcfa(remaining),
                            bold: true,
                            color: remaining > 0
                                ? Theme.of(context).colorScheme.error
                                : Colors.green.shade700,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Appuyer pour voir le détail de la facture',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (canRecordPayment) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () async {
                      final recorded = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ProcurementBloc>(),
                            child: RecordSupplierPaymentPage(
                              invoice: invoice,
                              remainingBalance: remaining,
                            ),
                          ),
                        ),
                      );
                      if (recorded == true && mounted) _refresh();
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(
                      remaining == invoice.total
                          ? 'Payer maintenant'
                          : 'Enregistrer un paiement',
                    ),
                  ),
                ],
                if ((invoice.payments ?? []).isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Historique des paiements',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Divider(),
                  ...(invoice.payments ?? []).map(
                    (p) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: ListTile(
                        leading: Icon(
                          Icons.payments_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(formatFcfa(p.amount)),
                        subtitle: Text(
                          '${p.paymentMethod.label} · ${_formatDate(p.paymentDate)}'
                          '${p.reference != null && p.reference!.isNotEmpty ? ' · Réf. ${p.reference}' : ''}',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
  }

  String _formatDate(int ms) {
    return DateTime.fromMillisecondsSinceEpoch(ms)
        .toLocal()
        .toString()
        .substring(0, 10);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceStatusChip extends StatelessWidget {
  const _InvoiceStatusChip({required this.status});

  final SupplierInvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      SupplierInvoiceStatus.unpaid => (
          'Non payé',
          Colors.red.shade100,
          Colors.red.shade800,
        ),
      SupplierInvoiceStatus.partiallyPaid => (
          'Partiel',
          Colors.orange.shade100,
          Colors.orange.shade800,
        ),
      SupplierInvoiceStatus.paid => (
          'Payé',
          Colors.green.shade100,
          Colors.green.shade800,
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
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
