import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';

class RecordSupplierPaymentPage extends StatefulWidget {
  const RecordSupplierPaymentPage({
    super.key,
    required this.invoice,
    required this.remainingBalance,
  });

  final SupplierInvoice invoice;
  final int remainingBalance;

  @override
  State<RecordSupplierPaymentPage> createState() =>
      _RecordSupplierPaymentPageState();
}

class _RecordSupplierPaymentPageState extends State<RecordSupplierPaymentPage> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();

  PurchasePaymentMethod _method = PurchasePaymentMethod.cash;
  int _paymentDateMs = DateTime.now().millisecondsSinceEpoch;
  bool _submitPending = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = '${widget.remainingBalance}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_amountController.text.trim());

  bool get _needsReference =>
      _method == PurchasePaymentMethod.mtnMomo ||
      _method == PurchasePaymentMethod.moovMoney ||
      _method == PurchasePaymentMethod.transfer ||
      _method == PurchasePaymentMethod.check;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProcurementBloc, ProcurementState>(
      listenWhen: (prev, curr) => _submitPending && prev.status != curr.status,
      listener: (context, state) async {
        if (!_submitPending) return;

        if (state.status == ProcurementStatus.failure &&
            state.errorMessage != null) {
          _submitPending = false;
          await ProcurementFeedback.showErrorDialog(
            context,
            title: 'Paiement impossible',
            message: state.errorMessage!,
          );
          return;
        }

        if (state.status == ProcurementStatus.loaded &&
            state.selectedInvoice?.id == widget.invoice.id) {
          _submitPending = false;
          if (!context.mounted) return;
          await ProcurementFeedback.showSuccess(
            context: context,
            title: 'Paiement enregistré',
            message:
                'Paiement de ${formatFcfa(_amount ?? 0)} enregistré pour la facture '
                '#${widget.invoice.invoiceNumber}.',
          );
          if (context.mounted) Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Enregistrer un paiement')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facture #${widget.invoice.invoiceNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.invoice.supplierName ??
                          'Fournisseur #${widget.invoice.supplierId}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Solde restant : ${formatFcfa(widget.remainingBalance)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _amountController.text = '${widget.remainingBalance}';
                    }),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Solde total'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final half = (widget.remainingBalance / 2).round();
                      setState(() {
                        _amountController.text = '$half';
                      });
                    },
                    icon: const Icon(Icons.horizontal_split, size: 18),
                    label: const Text('Moitié'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Montant du paiement (FCFA) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                'Date : ${DateTime.fromMillisecondsSinceEpoch(_paymentDateMs).toLocal().toString().substring(0, 10)}',
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.fromMillisecondsSinceEpoch(_paymentDateMs),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() {
                    _paymentDateMs = date.millisecondsSinceEpoch;
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Mode de paiement',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...PurchasePaymentMethod.values.map(
              (method) => RadioListTile<PurchasePaymentMethod>(
                title: Text(method.label),
                value: method,
                groupValue: _method,
                onChanged: (v) => setState(() => _method = v!),
              ),
            ),
            if (_needsReference) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: _method == PurchasePaymentMethod.check
                      ? 'Numéro de chèque'
                      : 'Référence transaction',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSizes.controlHeight),
              ),
              onPressed: _submitPending ? null : _submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Confirmer le paiement'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (amount == null || amount <= 0) {
      ProcurementFeedback.showErrorMessage(
        context,
        'Indiquez un montant valide.',
      );
      return;
    }
    if (amount > widget.remainingBalance) {
      ProcurementFeedback.showErrorMessage(
        context,
        'Le montant dépasse le solde restant (${formatFcfa(widget.remainingBalance)}).',
      );
      return;
    }

    final reference = _referenceController.text.trim();
    final paymentKind =
        amount == widget.remainingBalance ? 'total' : 'partiel';

    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: 'Confirmer le paiement ?',
      message:
          'Enregistrer un paiement $paymentKind de ${formatFcfa(amount)} '
          '(${_method.label}) pour la facture #${widget.invoice.invoiceNumber} ?',
      confirmLabel: 'Enregistrer',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitPending = true);
    context.read<ProcurementBloc>().add(
          ProcurementPaymentRecordSubmitted(
            invoiceId: widget.invoice.id,
            amount: amount,
            paymentMethod: _method,
            paymentDate: _paymentDateMs,
            reference: reference.isEmpty ? null : reference,
          ),
        );
  }
}
