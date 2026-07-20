import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/stock_transfer.dart';

class TransferReceiveResult {
  const TransferReceiveResult({
    required this.quantitiesByItemId,
    this.refusalsByItemId = const {},
  });

  final Map<int, int> quantitiesByItemId;
  final Map<int, StockTransferReceiveRefusal> refusalsByItemId;
}

class TransferReceiveDialog extends StatefulWidget {
  const TransferReceiveDialog({
    super.key,
    required this.transfer,
    this.shipmentId,
    this.initialQuantities,
  });

  final StockTransfer transfer;
  final int? shipmentId;
  final Map<int, int>? initialQuantities;

  static Future<TransferReceiveResult?> show(
    BuildContext context, {
    required StockTransfer transfer,
    int? shipmentId,
    Map<int, int>? initialQuantities,
  }) {
    return showDialog<TransferReceiveResult>(
      context: context,
      builder: (_) => TransferReceiveDialog(
        transfer: transfer,
        shipmentId: shipmentId,
        initialQuantities: initialQuantities,
      ),
    );
  }

  @override
  State<TransferReceiveDialog> createState() => _TransferReceiveDialogState();
}

class _TransferReceiveDialogState extends State<TransferReceiveDialog> {
  final Map<int, TextEditingController> _receivedControllers = {};
  final Map<int, TextEditingController> _refusedControllers = {};
  final Map<int, String> _refusalReasons = {};
  final Map<int, String> _refusalResolutions = {};

  @override
  void dispose() {
    for (final controller in _receivedControllers.values) {
      controller.dispose();
    }
    for (final controller in _refusedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _maxForItem(StockTransferItem item) {
    if (widget.shipmentId != null) {
      return item.quantityPendingReceiveInShipment(widget.shipmentId!);
    }
    return item.quantityPendingReceive;
  }

  void _submit() {
    final quantities = <int, int>{};
    final refusals = <int, StockTransferReceiveRefusal>{};

    for (final item in widget.transfer.items ?? []) {
      final maxQty = _maxForItem(item);
      if (maxQty <= 0) continue;

      final received =
          int.tryParse(_receivedControllers[item.id]?.text.trim() ?? '') ?? 0;
      final refused =
          int.tryParse(_refusedControllers[item.id]?.text.trim() ?? '') ?? 0;

      if (received <= 0 && refused <= 0) continue;
      if (received + refused > maxQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quantités invalides pour « ${item.productName ?? item.sourceProductId} ».',
            ),
          ),
        );
        return;
      }

      if (received > 0) quantities[item.id] = received;
      if (refused > 0) {
        final reason = _refusalReasons[item.id];
        final resolution = _refusalResolutions[item.id];
        if (reason == null || resolution == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Indiquez motif et résolution pour toute quantité refusée.',
              ),
            ),
          );
          return;
        }
        refusals[item.id] = StockTransferReceiveRefusal(
          quantity: refused,
          reason: reason,
          resolution: resolution,
        );
      }
    }

    if (quantities.isEmpty && refusals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez au moins une quantité.')),
      );
      return;
    }

    Navigator.pop(
      context,
      TransferReceiveResult(
        quantitiesByItemId: quantities,
        refusalsByItemId: refusals,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.transfer.items ?? [])
        .where((item) => _maxForItem(item) > 0)
        .toList();

    for (final item in items) {
      final maxQty = _maxForItem(item);
      final initial = widget.initialQuantities?[item.id] ?? maxQty;
      _receivedControllers.putIfAbsent(
        item.id,
        () => TextEditingController(text: '$initial'),
      );
      _refusedControllers.putIfAbsent(
        item.id,
        () => TextEditingController(text: '0'),
      );
      _refusalReasons.putIfAbsent(
        item.id,
        () => StockTransferRefusalReason.breakage,
      );
      _refusalResolutions.putIfAbsent(
        item.id,
        () => StockTransferRefusalResolution.returnToSource,
      );
    }

    return AlertDialog(
      title: const Text('Réception / refus'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saisissez les quantités reçues et, le cas échéant, '
                'les quantités refusées avec motif et résolution.',
              ),
              const SizedBox(height: AppSpacing.md),
              ...items.map((item) {
                final maxQty = _maxForItem(item);
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName ?? 'Produit #${item.sourceProductId}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text('En attente : $maxQty'),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _receivedControllers[item.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Reçu',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextField(
                                controller: _refusedControllers[item.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Refusé',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          value: _refusalReasons[item.id],
                          decoration: const InputDecoration(
                            labelText: 'Motif refus',
                            isDense: true,
                          ),
                          items: StockTransferRefusalReason.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    StockTransferRefusalReason.label(value),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _refusalReasons[item.id] = value);
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: _refusalResolutions[item.id],
                          decoration: const InputDecoration(
                            labelText: 'Résolution',
                            isDense: true,
                          ),
                          items: StockTransferRefusalResolution.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    StockTransferRefusalResolution.label(value),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(
                              () => _refusalResolutions[item.id] = value,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
