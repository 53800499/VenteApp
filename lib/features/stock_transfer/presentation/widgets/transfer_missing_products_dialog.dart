import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/stock_transfer.dart';

class TransferMissingProductsDialog extends StatefulWidget {
  const TransferMissingProductsDialog({
    super.key,
    required this.products,
  });

  final List<TransferMissingDestinationProduct> products;

  static Future<Map<int, int>?> show(
    BuildContext context, {
    required List<TransferMissingDestinationProduct> products,
  }) {
    return showDialog<Map<int, int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferMissingProductsDialog(products: products),
    );
  }

  @override
  State<TransferMissingProductsDialog> createState() =>
      _TransferMissingProductsDialogState();
}

class _TransferMissingProductsDialogState
    extends State<TransferMissingProductsDialog> {
  late final Map<int, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final product in widget.products)
        product.itemId: TextEditingController(
          text: product.suggestedPriceSell?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final prices = <int, int>{};
    for (final product in widget.products) {
      final raw = _controllers[product.itemId]?.text.trim() ?? '';
      final price = int.tryParse(raw);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Indiquez un prix de vente valide pour « ${product.productName} ».',
            ),
          ),
        );
        return;
      }
      prices[product.itemId] = price;
    }
    Navigator.pop(context, prices);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveaux produits à créer'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ces articles n\'existent pas encore dans votre catalogue. '
                'Confirmez leur création et fixez vos prix de vente locaux.',
              ),
              const SizedBox(height: AppSpacing.md),
              ...widget.products.map((product) {
                final buy = product.suggestedPriceBuy;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.productName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (buy != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Coût d\'achat transféré : ${formatFcfa(buy)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _controllers[product.itemId],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Prix de vente (FCFA)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
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
          child: const Text('Créer et réceptionner'),
        ),
      ],
    );
  }
}
