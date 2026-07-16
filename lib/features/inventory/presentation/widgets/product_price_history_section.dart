import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/datasources/local/product_pricing_local_datasource.dart';
import '../../domain/entities/product_pricing_entities.dart';

String _formatDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}

class ProductPriceHistorySection extends StatefulWidget {
  const ProductPriceHistorySection({
    super.key,
    required this.shopId,
    required this.productId,
  });

  final int shopId;
  final int productId;

  @override
  State<ProductPriceHistorySection> createState() =>
      _ProductPriceHistorySectionState();
}

class _ProductPriceHistorySectionState extends State<ProductPriceHistorySection> {
  late Future<List<ProductPriceHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = sl<ProductPricingLocalDatasource>().listPriceHistory(
      shopId: widget.shopId,
      productId: widget.productId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des prix',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<ProductPriceHistoryEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Aucun historique enregistré.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }

            final dateFmt = _formatDate;

            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    ListTile(
                      dense: true,
                      title: Text(dateFmt(entries[i].createdAt)),
                      subtitle: Text(entries[i].reasonLabel),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Prix de vente : ${formatFcfa(entries[i].priceSell)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (entries[i].unitCost != null)
                            Text(
                              'Prix d\'achat : ${formatFcfa(entries[i].unitCost!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      shape: i < entries.length - 1
                          ? const Border(
                              bottom: BorderSide(color: Colors.black12),
                            )
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
