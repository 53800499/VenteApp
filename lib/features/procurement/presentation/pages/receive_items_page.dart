import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/repositories/procurement_repository.dart';
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

  /// Lignes : acceptedCtrl, refusedCtrl, refusalReason, remaining, …
  final List<Map<String, dynamic>> _items = [];
  bool _submitPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextReceiptNumber());

    final poItems = widget.po.items ?? [];
    for (final it in poItems) {
      final remaining = it.quantityRemaining;
      if (remaining > 0) {
        _items.add({
          'purchaseOrderItemId': it.id,
          'productId': it.productId,
          'productName': it.productName ?? 'Produit #${it.productId}',
          'unitCost': it.unitCost,
          'remaining': remaining,
          'acceptedCtrl': TextEditingController(text: '$remaining'),
          'refusedCtrl': TextEditingController(text: '0'),
          'refusalReason': null as SupplierRefusalReason?,
          'batchController': TextEditingController(),
          'expiryMs': null,
        });
      }
    }
  }

  Future<void> _loadNextReceiptNumber() async {
    final shopId = context.read<ProcurementBloc>().shopId;
    final number =
        await sl<ProcurementRepository>().nextOrderReceiptNumber(shopId: shopId);
    if (mounted) {
      setState(() => _receiptNumberController.text = number);
    }
  }

  @override
  void dispose() {
    _receiptNumberController.dispose();
    _notesController.dispose();
    for (final it in _items) {
      (it['acceptedCtrl'] as TextEditingController).dispose();
      (it['refusedCtrl'] as TextEditingController).dispose();
      (it['batchController'] as TextEditingController).dispose();
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
                'Le bon « ${_receiptNumberController.text.trim()} » a été '
                'enregistré. Seules les quantités acceptées augmentent le stock.',
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
              TextFormField(
                controller: _receiptNumberController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de Bon de Réception (BR) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Accepté / refusé par article',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_items.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Tous les articles ont déjà été entièrement traités.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                ..._items.map(_buildLineCard),
              const SizedBox(height: AppSpacing.md),
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.controlHeight),
                  ),
                  onPressed:
                      _items.isEmpty || _submitPending ? null : _submitReceipt,
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

  Widget _buildLineCard(Map<String, dynamic> it) {
    final remaining = it['remaining'] as int;
    final refusedCtrl = it['refusedCtrl'] as TextEditingController;
    final refusedQty = int.tryParse(refusedCtrl.text.trim()) ?? 0;

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
              'Prix d\'achat : ${formatFcfa(it['unitCost'] as int)}/u · '
              'Reste $remaining',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: it['acceptedCtrl'] as TextEditingController,
                    decoration: const InputDecoration(
                      labelText: 'Accepté',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final accepted = int.tryParse(v?.trim() ?? '');
                      final refused = int.tryParse(
                            (it['refusedCtrl'] as TextEditingController)
                                .text
                                .trim(),
                          ) ??
                          0;
                      if (accepted == null || accepted < 0) return 'Invalide';
                      if (accepted + refused <= 0) return 'Saisir une qté';
                      if (accepted + refused > remaining) {
                        return 'Max $remaining';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: refusedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Refusé',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final refused = int.tryParse(v?.trim() ?? '');
                      if (refused == null || refused < 0) return 'Invalide';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (refusedQty > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<SupplierRefusalReason>(
                value: it['refusalReason'] as SupplierRefusalReason?,
                decoration: const InputDecoration(
                  labelText: 'Motif du refus *',
                  border: OutlineInputBorder(),
                ),
                items: SupplierRefusalReason.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.labelFr),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => it['refusalReason'] = v),
                validator: (v) {
                  if (refusedQty > 0 && v == null) return 'Motif requis';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 8),
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
                      setState(() => it['expiryMs'] = ms);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReceipt() async {
    if (!_formKey.currentState!.validate()) return;

    final receiptItems = <Map<String, dynamic>>[];
    var totalAccepted = 0;
    var totalRefused = 0;
    for (final it in _items) {
      final accepted = int.parse(
        (it['acceptedCtrl'] as TextEditingController).text.trim(),
      );
      final refused = int.parse(
        (it['refusedCtrl'] as TextEditingController).text.trim(),
      );
      if (accepted + refused <= 0) continue;
      totalAccepted += accepted;
      totalRefused += refused;
      final reason = it['refusalReason'] as SupplierRefusalReason?;
      receiptItems.add({
        'purchaseOrderItemId': it['purchaseOrderItemId'] as int,
        'productId': it['productId'] as int,
        'quantityReceived': accepted,
        'quantityRefused': refused,
        'refusalReason': refused > 0 ? reason?.code : null,
        'unitCost': it['unitCost'] as int,
        'batchNumber':
            (it['batchController'] as TextEditingController).text.trim().isEmpty
                ? null
                : (it['batchController'] as TextEditingController).text.trim(),
        'expiryDate': it['expiryMs'],
      });
    }

    if (receiptItems.isEmpty) {
      ActionFeedback.showErrorMessage(
        context,
        'Indiquez au moins une quantité acceptée ou refusée.',
      );
      return;
    }

    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Confirmer la réception ?',
      message:
          'Bon « ${_receiptNumberController.text.trim()} » — '
          'commande #${widget.po.number}.\n\n'
          'Accepté : $totalAccepted (→ stock)\n'
          'Refusé : $totalRefused'
          '${totalRefused > 0 ? ' (tracé sur le BR)' : ''}',
      confirmLabel: 'Confirmer la réception',
    );
    if (confirmed != true || !mounted) return;

    final shopId = context.read<ProcurementBloc>().shopId;
    final priceFlowOk = await ProcurementPriceUpdateFlow().run(
      context: context,
      shopId: shopId,
      lines: receiptItems
          .where((it) => (it['quantityReceived'] as int) > 0)
          .map(
            (it) => ProcurementReceiptLineInput(
              productId: it['productId'] as int,
              unitCost: it['unitCost'] as int,
              quantityReceived: it['quantityReceived'] as int,
              productName: _items
                  .firstWhere(
                    (row) => row['productId'] == it['productId'],
                  )['productName'] as String?,
            ),
          )
          .toList(),
    );
    if (!priceFlowOk || !mounted) return;

    _submitPending = true;
    context.read<ProcurementBloc>().add(
          ProcurementOrderReceiveSubmitted(
            poId: widget.po.id,
            receiptNumber: _receiptNumberController.text.trim(),
            receivedAt: DateTime.now().millisecondsSinceEpoch,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: receiptItems,
          ),
        );
  }
}

class _ExpirySelector extends StatelessWidget {
  const _ExpirySelector({
    required this.expiryMs,
    required this.onSelected,
  });

  final int? expiryMs;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = expiryMs == null
        ? 'Expiration'
        : DateTime.fromMillisecondsSinceEpoch(expiryMs!)
            .toLocal()
            .toString()
            .substring(0, 10);
    return OutlinedButton(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: expiryMs == null
              ? now.add(const Duration(days: 30))
              : DateTime.fromMillisecondsSinceEpoch(expiryMs!),
          firstDate: now,
          lastDate: now.add(const Duration(days: 3650)),
        );
        onSelected(
          picked == null ? null : picked.millisecondsSinceEpoch,
        );
      },
      child: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
