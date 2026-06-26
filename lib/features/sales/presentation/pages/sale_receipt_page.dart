import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';

class SaleReceiptPage extends StatelessWidget {
  const SaleReceiptPage({
    super.key,
    required this.session,
    required this.sale,
  });

  final AuthSession session;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reçu de vente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  session.shop.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  sale.receiptNumber ?? 'Vente #${sale.id}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(date),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xl),
          if (sale.items.isNotEmpty) ...[
            Text('Articles', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...sale.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item.productName} × ${item.quantity}'),
                    ),
                    Text(formatFcfa(item.lineTotal)),
                  ],
                ),
              ),
            ),
            const Divider(),
          ],
          _ReceiptRow(label: 'Sous-total', value: formatFcfa(sale.subtotal)),
          if (sale.discountAmount > 0)
            _ReceiptRow(
              label: 'Remise',
              value: '- ${formatFcfa(sale.discountAmount)}',
            ),
          _ReceiptRow(
            label: 'Total',
            value: formatFcfa(sale.totalAmount),
            emphasized: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _ReceiptRow(
            label: 'Paiement',
            value: sale.paymentMethod.label,
          ),
          if (sale.amountCash > 0)
            _ReceiptRow(label: 'Espèces', value: formatFcfa(sale.amountCash)),
          if (sale.amountMomo > 0)
            _ReceiptRow(
              label: 'Mobile Money',
              value: formatFcfa(sale.amountMomo),
            ),
          if (sale.amountCredit > 0)
            _ReceiptRow(label: 'Crédit', value: formatFcfa(sale.amountCredit)),
          if (sale.customerName != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ReceiptRow(label: 'Client', value: sale.customerName!),
          ],
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Merci pour votre achat !',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
