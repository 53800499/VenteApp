import 'package:flutter/material.dart';
import '../../../../shared/components/app_dropdown.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/stock_transfer.dart';

class TransferResolveDiscrepancyResult {
  const TransferResolveDiscrepancyResult({
    required this.quantity,
    required this.reason,
    required this.resolution,
    this.notes,
  });

  final int quantity;
  final String reason;
  final String resolution;
  final String? notes;
}

class TransferResolveDiscrepancyDialog extends StatefulWidget {
  const TransferResolveDiscrepancyDialog({
    super.key,
    required this.productName,
    required this.maxQuantity,
  });

  final String productName;
  final int maxQuantity;

  static Future<TransferResolveDiscrepancyResult?> show(
    BuildContext context, {
    required String productName,
    required int maxQuantity,
  }) {
    return showDialog<TransferResolveDiscrepancyResult>(
      context: context,
      builder: (_) => TransferResolveDiscrepancyDialog(
        productName: productName,
        maxQuantity: maxQuantity,
      ),
    );
  }

  @override
  State<TransferResolveDiscrepancyDialog> createState() =>
      _TransferResolveDiscrepancyDialogState();
}

class _TransferResolveDiscrepancyDialogState
    extends State<TransferResolveDiscrepancyDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  String _reason = StockTransferDiscrepancyReason.loss;
  String _resolution = StockTransferDiscrepancyResolution.writeOff;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '${widget.maxQuantity}');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0 || quantity > widget.maxQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Indiquez une quantité entre 1 et ${widget.maxQuantity}.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      TransferResolveDiscrepancyResult(
        quantity: quantity,
        reason: _reason,
        resolution: _resolution,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Résoudre l\'écart'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantité (max ${widget.maxQuantity})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              labelText: 'Motif',
              initialItem: _reason,
              items: const [
                StockTransferDiscrepancyReason.loss,
                StockTransferDiscrepancyReason.breakage,
                StockTransferDiscrepancyReason.theft,
                StockTransferDiscrepancyReason.other,
              ],
              headerBuilder: (context, item, isExpanded) {
                String label = 'Autre';
                if (item == StockTransferDiscrepancyReason.loss) label = 'Perte';
                if (item == StockTransferDiscrepancyReason.breakage) label = 'Casse';
                if (item == StockTransferDiscrepancyReason.theft) label = 'Vol';
                return Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
              },
              listItemBuilder: (context, item, isSelected, onItemSelect) {
                String label = 'Autre';
                if (item == StockTransferDiscrepancyReason.loss) label = 'Perte';
                if (item == StockTransferDiscrepancyReason.breakage) label = 'Casse';
                if (item == StockTransferDiscrepancyReason.theft) label = 'Vol';
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(label),
                );
              },
              onChanged: (value) {
                if (value != null) setState(() => _reason = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppDropdown<String>(
              labelText: 'Résolution',
              initialItem: _resolution,
              items: const [
                StockTransferDiscrepancyResolution.writeOff,
                StockTransferDiscrepancyResolution.restockSource,
              ],
              headerBuilder: (context, item, isExpanded) {
                final label = item == StockTransferDiscrepancyResolution.writeOff
                    ? 'Perte acceptée (sans restock)'
                    : 'Restocker la boutique source';
                return Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
              },
              listItemBuilder: (context, item, isSelected, onItemSelect) {
                final label = item == StockTransferDiscrepancyResolution.writeOff
                    ? 'Perte acceptée (sans restock)'
                    : 'Restocker la boutique source';
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(label),
                );
              },
              onChanged: (value) {
                if (value != null) setState(() => _resolution = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
