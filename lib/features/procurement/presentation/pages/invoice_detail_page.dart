import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../data/services/procurement_sync_status_service.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_sync_entities.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';
import '../widgets/procurement_sync_badge.dart';
import '../widgets/procurement_sync_scope.dart';
import 'record_supplier_payment_page.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  ProcurementSyncOverview _syncOverview = const ProcurementSyncOverview();

  @override
  void initState() {
    super.initState();
    ensureProcurementDependencies();
    _refresh();
  }

  Future<void> _loadSyncOverview() async {
    try {
      final shopId = context.read<ProcurementBloc>().shopId;
      final overview =
          await sl<ProcurementSyncStatusService>().loadOverview(shopId: shopId);
      if (mounted) setState(() => _syncOverview = overview);
    } catch (_) {}
  }

  void _refresh() {
    context
        .read<ProcurementBloc>()
        .add(ProcurementInvoiceDetailLoadRequested(widget.invoiceId));
    _loadSyncOverview();
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

    return ProcurementSyncScope(
      overview: _syncOverview,
      onRefresh: _loadSyncOverview,
      child: Scaffold(
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
          final invoice = state.selectedInvoice;
          if (invoice?.id == widget.invoiceId) {
            return _buildInvoiceContent(
              context,
              invoice!,
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
    ),
    );
  }

  Widget _buildInvoiceContent(
    BuildContext context,
    SupplierInvoice invoice,
    bool canPay,
  ) {
          final paid = _paidAmount(invoice);
          final remaining = invoice.total - paid;
          final invoicePending = _syncOverview.stateFor(
                kind: ProcurementSyncEntityKind.invoice,
                localId: invoice.id,
                serverId: invoice.serverId,
              ) !=
              ProcurementCloudSyncState.synced;
          final paidLocally = invoice.status == SupplierInvoiceStatus.paid;
          final canRecordPayment = canPay &&
              remaining > 0 &&
              !paidLocally &&
              !invoicePending;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (paidLocally && invoicePending)
                Card(
                  color: Theme.of(context)
                      .colorScheme
                      .tertiaryContainer
                      .withValues(alpha: 0.65),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Facture payée sur cet appareil. '
                      'Synchronisation cloud en cours — aucun paiement à refaire.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
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
                          ProcurementInvoiceStatusChip(
                            invoiceId: invoice.id,
                            status: invoice.status,
                            serverId: invoice.serverId,
                          ),
                          const SizedBox(width: 4),
                          ProcurementSyncBadge(
                            kind: ProcurementSyncEntityKind.invoice,
                            localId: invoice.id,
                            serverId: invoice.serverId,
                          ),
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
