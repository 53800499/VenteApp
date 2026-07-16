import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';
import 'record_supplier_payment_page.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    context
        .read<ProcurementBloc>()
        .add(ProcurementInvoiceDetailLoadRequested(widget.invoiceId));
  }

  int _paidAmount(SupplierInvoice invoice) {
    return (invoice.payments ?? [])
        .fold<int>(0, (sum, p) => sum + p.amount);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.read<ProcurementBloc>().session.user.permissions;
    final canPay =
        PermissionGuard.can(permissions, Permission.procurementInvoicePay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail facture'),
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
          if (state.status == ProcurementStatus.loading &&
              state.selectedInvoice == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoice = state.selectedInvoice;
          if (invoice == null || invoice.id != widget.invoiceId) {
            return const Center(child: Text('Facture introuvable.'));
          }

          final paid = _paidAmount(invoice);
          final remaining = invoice.total - paid;
          final canRecordPayment =
              canPay && remaining > 0 && invoice.status != SupplierInvoiceStatus.paid;

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
                          Expanded(
                            child: Text(
                              'Facture #${invoice.invoiceNumber}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          _InvoiceStatusChip(status: invoice.status),
                        ],
                      ),
                      const Divider(height: AppSpacing.lg),
                      _InfoLine(
                        label: 'Fournisseur',
                        value: invoice.supplierName ??
                            'Fournisseur #${invoice.supplierId}',
                      ),
                      if (invoice.purchaseOrderId != null)
                        _InfoLine(
                          label: 'Commande liée',
                          value: '#${invoice.purchaseOrderId}',
                        ),
                      _InfoLine(
                        label: 'Date facture',
                        value: _formatDate(invoice.invoiceDate),
                      ),
                      if (invoice.dueDate != null)
                        _InfoLine(
                          label: 'Échéance',
                          value: _formatDate(invoice.dueDate!),
                        ),
                      const Divider(height: AppSpacing.lg),
                      _InfoLine(
                        label: 'Sous-total',
                        value: formatFcfa(invoice.subtotal),
                      ),
                      _InfoLine(label: 'Taxes', value: formatFcfa(invoice.tax)),
                      _InfoLine(
                        label: 'Total',
                        value: formatFcfa(invoice.total),
                        bold: true,
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
                    ],
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
                        ? 'Enregistrer le paiement total'
                        : 'Enregistrer un paiement',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Historique des paiements',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Divider(),
              if ((invoice.payments ?? []).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Aucun paiement enregistré.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...(invoice.payments ?? []).map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: ListTile(
                      leading: Icon(
                        _methodIcon(p.paymentMethod),
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
          );
        },
      ),
    );
  }

  String _formatDate(int ms) {
    return DateTime.fromMillisecondsSinceEpoch(ms)
        .toLocal()
        .toString()
        .substring(0, 10);
  }

  IconData _methodIcon(PurchasePaymentMethod method) {
    return switch (method) {
      PurchasePaymentMethod.cash => Icons.payments_outlined,
      PurchasePaymentMethod.mtnMomo => Icons.phone_android,
      PurchasePaymentMethod.moovMoney => Icons.phone_android,
      PurchasePaymentMethod.card => Icons.credit_card,
      PurchasePaymentMethod.transfer => Icons.account_balance,
      PurchasePaymentMethod.check => Icons.receipt_long,
    };
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
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: color,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: style),
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
    final (bg, fg) = switch (status) {
      SupplierInvoiceStatus.unpaid => (Colors.red.shade100, Colors.red.shade800),
      SupplierInvoiceStatus.partiallyPaid =>
        (Colors.orange.shade100, Colors.orange.shade800),
      SupplierInvoiceStatus.paid => (Colors.green.shade100, Colors.green.shade800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
