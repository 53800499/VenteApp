import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/usecases/sales_analysis_usecases.dart';
import '../utils/sales_analysis_formatters.dart';

class ProductSalesDetailPage extends StatefulWidget {
  const ProductSalesDetailPage({
    super.key,
    required this.session,
    required this.query,
    this.productId,
    required this.productName,
  });

  final AuthSession session;
  final SalesAnalysisQuery query;
  final int? productId;
  final String productName;

  @override
  State<ProductSalesDetailPage> createState() => _ProductSalesDetailPageState();
}

class _ProductSalesDetailPageState extends State<ProductSalesDetailPage> {
  late Future<ProductSalesDetail> _future;

  @override
  void initState() {
    super.initState();
    ensureSalesAnalysisDependencies();
    _future = sl<GetProductSalesDetail>()(
      shopId: widget.session.shop.id,
      query: widget.query,
      productId: widget.productId,
      productName: widget.productName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.productName)),
      body: FutureBuilder<ProductSalesDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final detail = snapshot.data!;
          final isHeadless = SalesAnalysisHeadlessLabels.isHeadlessProductName(
            widget.productName,
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (isHeadless)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Ces ventes n\'ont pas de lignes produit enregistrées '
                      '(vente rapide ou synchronisation incomplète). '
                      'Le montant affiché correspond au total de chaque vente.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              if (isHeadless) const SizedBox(height: AppSpacing.md),
              _StatsCard(stats: detail.stats),
              if (detail.employeeStats.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Qui vend à quel prix ?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...detail.employeeStats.map(
                  (e) => Card(
                    child: ListTile(
                      title: Text(e.userName ?? 'Vendeur #${e.userId}'),
                      subtitle: Text(
                        '${e.saleLineCount} ventes · '
                        '${e.discountLineCount} écart(s)',
                      ),
                      trailing: Text(formatFcfa(e.averageUnitPrice)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Historique des ventes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (detail.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: EmptyListPlaceholder(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune vente sur cette période',
                  ),
                )
              else
                ...detail.lines.map((line) => _SaleLineTile(line: line)),
            ],
          );
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final ProductPriceStats stats;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (
        label: 'Prix catalogue',
        value: stats.catalogPrice != null
            ? formatFcfa(stats.catalogPrice!)
            : '—',
      ),
      (label: 'Prix minimum vendu', value: formatFcfa(stats.minSoldPrice)),
      (label: 'Prix maximum vendu', value: formatFcfa(stats.maxSoldPrice)),
      (label: 'Prix moyen', value: formatFcfa(stats.averageUnitPrice)),
      (
        label: 'Quantité vendue',
        value: formatQuantitySold(stats.quantitySold),
      ),
      (label: "Chiffre d'affaires", value: formatFcfa(stats.revenue)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    rows[i].value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SaleLineTile extends StatelessWidget {
  const _SaleLineTile({required this.line});

  final ProductSaleLine line;

  @override
  Widget build(BuildContext context) {
    final customer = line.customerName ?? 'Client comptoir';
    final seller = line.sellerName ?? '—';
    final qty = formatQuantitySold(line.quantity);
    final isHeadlessLine = line.catalogPrice == null && line.discountAmount == 0;
    final priceColor = line.catalogPrice != null &&
            line.unitPrice < line.catalogPrice!
        ? Theme.of(context).colorScheme.error
        : null;

    return Card(
      child: ListTile(
        title: Text('${formatRelativeSaleDate(line.soldAt)} · $customer'),
        subtitle: Text(
          isHeadlessLine
              ? 'Vendeur : $seller · Vente #${line.saleId}'
              : 'Vendeur : $seller · Qté $qty',
        ),
        trailing: Text(
          formatFcfa(line.unitPrice),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: priceColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
