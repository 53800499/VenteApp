import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';

class InvoiceFormPage extends StatefulWidget {
  const InvoiceFormPage({super.key, required this.po});
  final PurchaseOrder po;

  @override
  State<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends State<InvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _subtotalController = TextEditingController();
  final _taxController = TextEditingController();
  final _totalController = TextEditingController();

  int _invoiceDateMs = DateTime.now().millisecondsSinceEpoch;
  int? _dueDateMs;
  bool _submitPending = false;

  @override
  void initState() {
    super.initState();
    // Prefill from PO
    _numberController.text = 'INV-${widget.po.number.replaceAll("PO-", "")}';
    _subtotalController.text = '${widget.po.subtotal - widget.po.discount}'; // Net subtotal
    _taxController.text = '${widget.po.tax}';
    _totalController.text = '${widget.po.total}';
    
    // Default due date: 30 days after invoice date
    _dueDateMs = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _subtotalController.dispose();
    _taxController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _recalculateTotal() {
    final sub = int.tryParse(_subtotalController.text) ?? 0;
    final tax = int.tryParse(_taxController.text) ?? 0;
    setState(() {
      _totalController.text = '${sub + tax}';
    });
  }

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
            title: 'Facture impossible',
            message: state.errorMessage!,
          );
          return;
        }

        if (state.status == ProcurementStatus.loaded) {
          _submitPending = false;
          if (!context.mounted) return;
          await ProcurementFeedback.showSuccess(
            context: context,
            title: 'Facture enregistrée',
            message:
                'La facture « ${_numberController.text.trim()} » '
                '(${formatFcfa(int.parse(_totalController.text))}) a été créée.',
          );
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Facturer la commande'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Commande #${widget.po.number}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Fournisseur: ${widget.po.supplierName ?? "ID #${widget.po.supplierId}"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Invoice number
            TextFormField(
              controller: _numberController,
              decoration: const InputDecoration(
                labelText: 'Numéro de Facture Fournisseur *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Date buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      'Date Facture: ${DateTime.fromMillisecondsSinceEpoch(_invoiceDateMs).toLocal().toString().substring(0, 10)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.fromMillisecondsSinceEpoch(_invoiceDateMs),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() {
                          _invoiceDateMs = date.millisecondsSinceEpoch;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      _dueDateMs != null
                          ? 'Échéance: ${DateTime.fromMillisecondsSinceEpoch(_dueDateMs!).toLocal().toString().substring(0, 10)}'
                          : 'Sans Échéance',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDateMs != null
                            ? DateTime.fromMillisecondsSinceEpoch(_dueDateMs!)
                            : DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _dueDateMs = date.millisecondsSinceEpoch;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            // Subtotal
            TextFormField(
              controller: _subtotalController,
              decoration: const InputDecoration(
                labelText: 'Sous-total (net) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalculateTotal(),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Tax
            TextFormField(
              controller: _taxController,
              decoration: const InputDecoration(
                labelText: 'Taxes *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent_outlined),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalculateTotal(),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Total (read-only / recalculated)
            TextFormField(
              controller: _totalController,
              decoration: InputDecoration(
                labelText: 'Montant Total Facturé',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calculate_outlined),
                filled: true,
                fillColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
              ),
              readOnly: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.controlHeight),
                ),
                onPressed: _submitPending ? null : _submitInvoice,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer la facture'),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    final subtotal = int.parse(_subtotalController.text.trim());
    final tax = int.parse(_taxController.text.trim());
    final total = int.parse(_totalController.text.trim());

    final dueLabel = _dueDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(_dueDateMs!)
            .toLocal()
            .toString()
            .substring(0, 10)
        : 'sans échéance';

    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: 'Enregistrer la facture ?',
      message:
          'Créer la facture « ${_numberController.text.trim()} » '
          '(${formatFcfa(total)}) pour la commande #${widget.po.number} ?\n\n'
          'Échéance : $dueLabel.',
      confirmLabel: 'Enregistrer',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitPending = true);
    context.read<ProcurementBloc>().add(
          ProcurementInvoiceCreateSubmitted(
            poId: widget.po.id,
            invoiceNumber: _numberController.text.trim(),
            supplierId: widget.po.supplierId,
            invoiceDate: _invoiceDateMs,
            dueDate: _dueDateMs,
            subtotal: subtotal,
            tax: tax,
            total: total,
          ),
        );
  }
}
