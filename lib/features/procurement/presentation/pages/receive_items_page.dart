import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';
import '../utils/procurement_price_update_flow.dart';

class ReceiveItemsPage extends StatefulWidget {
  const ReceiveItemsPage({super.key, required this.po});
  final PurchaseOrder po;

  @override
  State<ReceiveItemsPage> createState() => _ReceiveItemsPageState();
}

class _ReceiveItemsPageState extends State<ReceiveItemsPage> {
  final _formKey = GlobalKey<FormState>();
  final _receiptNumberController = TextEditingController();
  final _notesController = TextEditingController();

  // List holding user inputs: {purchaseOrderItemId: int, productId: int, quantityReceived: int, unitCost: int, remaining: int, productName: String, controller: TextEditingController, batchController: TextEditingController, expiryMs: int?}
  final List<Map<String, dynamic>> _items = [];
  bool _submitPending = false;

  @override
  void initState() {
    super.initState();
    // Default delivery receipt number
    _receiptNumberController.text = 'BR-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    // Populate lines
    final poItems = widget.po.items ?? [];
    for (final it in poItems) {
      final remaining = it.quantityOrdered - it.quantityReceived;
      if (remaining > 0) {
        _items.add({
          'purchaseOrderItemId': it.id,
          'productId': it.productId,
          'productName': it.productName ?? "Produit #${it.productId}",
          'unitCost': it.unitCost,
          'remaining': remaining,
          'controller': TextEditingController(text: '$remaining'),
          'batchController': TextEditingController(),
          'expiryMs': null,
        });
      }
    }
  }

  @override
  void dispose() {
    _receiptNumberController.dispose();
    _notesController.dispose();
    for (final it in _items) {
      it['controller'].dispose();
      it['batchController'].dispose();
    }
    super.dispose();
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
            title: 'Réception impossible',
            message: state.errorMessage!,
          );
          return;
        }

        if (state.status == ProcurementStatus.loaded) {
          _submitPending = false;
          if (!context.mounted) return;
          await ProcurementFeedback.showSuccess(
            context: context,
            title: 'Réception enregistrée',
            message:
                'Le bon de réception « ${_receiptNumberController.text.trim()} » '
                'a été enregistré. Le stock a été mis à jour.',
          );
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Réception Articles'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Commande #${widget.po.number}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Fournisseur: ${widget.po.supplierName ?? "#${widget.po.supplierId}"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),

            // Receipt number
            TextFormField(
              controller: _receiptNumberController,
              decoration: const InputDecoration(
                labelText: 'Numéro de Bon de Réception (BR) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'Quantités reçues par article',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    'Tous les articles ont déjà été entièrement réceptionnés.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              )
            else
              ..._items.map((it) {
                final remaining = it['remaining'] as int;

                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it['productName'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prix d\'achat : ${formatFcfa(it['unitCost'] as int)}/u',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Reste à recevoir: $remaining unités'),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: it['controller'] as TextEditingController,
                                decoration: const InputDecoration(
                                  labelText: 'Reçu *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requis';
                                  final val = int.tryParse(v);
                                  if (val == null || val < 0) return 'Invalide';
                                  if (val > remaining) return 'Max $remaining';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Lot / Expiry Fields
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: it['batchController'] as TextEditingController,
                                decoration: const InputDecoration(
                                  labelText: 'N° de Lot',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _ExpirySelector(
                                expiryMs: it['expiryMs'] as int?,
                                onSelected: (ms) {
                                  setState(() {
                                    it['expiryMs'] = ms;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: AppSpacing.md),
            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Remarques sur la livraison',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
                onPressed: _items.isEmpty || _submitPending ? null : _submitReceipt,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmer la réception'),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _submitReceipt() async {
    if (!_formKey.currentState!.validate()) return;

    final receiptItems = <Map<String, dynamic>>[];
    var totalQty = 0;
    for (final it in _items) {
      final qty = int.parse((it['controller'] as TextEditingController).text.trim());
      if (qty > 0) {
        totalQty += qty;
        receiptItems.add({
          'purchaseOrderItemId': it['purchaseOrderItemId'] as int,
          'productId': it['productId'] as int,
          'quantityReceived': qty,
          'unitCost': it['unitCost'] as int,
          'batchNumber': (it['batchController'] as TextEditingController).text.trim().isEmpty
              ? null
              : (it['batchController'] as TextEditingController).text.trim(),
          'expiryDate': it['expiryMs'],
        });
      }
    }

    if (receiptItems.isEmpty) {
      ProcurementFeedback.showErrorMessage(
        context,
        'Veuillez saisir une quantité supérieure à 0 pour au moins un article.',
      );
      return;
    }

    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: 'Confirmer la réception ?',
      message:
          'Enregistrer le bon « ${_receiptNumberController.text.trim()} » '
          'pour la commande #${widget.po.number} ?\n\n'
          '$totalQty unité(s) seront ajoutées au stock.',
      confirmLabel: 'Confirmer la réception',
    );
    if (confirmed != true || !mounted) return;

    final shopId = context.read<ProcurementBloc>().shopId;
    final priceFlowOk = await ProcurementPriceUpdateFlow().run(
      context: context,
      shopId: shopId,
      lines: receiptItems
          .map(
            (it) => ProcurementReceiptLineInput(
              productId: it['productId'] as int,
              unitCost: it['unitCost'] as int,
              quantityReceived: it['quantityReceived'] as int,
              productName: _items
                  .cast<Map<String, dynamic>>()
                  .firstWhere(
                    (row) => row['productId'] == it['productId'],
                    orElse: () => {},
                  )['productName'] as String?,
            ),
          )
          .toList(),
    );
    if (!priceFlowOk || !mounted) return;

    setState(() => _submitPending = true);
    context.read<ProcurementBloc>().add(
          ProcurementOrderReceiveSubmitted(
            poId: widget.po.id,
            receiptNumber: _receiptNumberController.text.trim(),
            receivedAt: DateTime.now().millisecondsSinceEpoch,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            items: receiptItems,
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Expiry Date Selector widget
// ---------------------------------------------------------------------------
class _ExpirySelector extends StatelessWidget {
  const _ExpirySelector({required this.expiryMs, required this.onSelected});
  final int? expiryMs;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final hasDate = expiryMs != null;
    final text = hasDate
        ? DateTime.fromMillisecondsSinceEpoch(expiryMs!).toLocal().toString().substring(0, 10)
        : 'Sélectionner Exp.';

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      icon: const Icon(Icons.calendar_month),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 90)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (date != null) {
          onSelected(date.millisecondsSinceEpoch);
        }
      },
    );
  }
}
