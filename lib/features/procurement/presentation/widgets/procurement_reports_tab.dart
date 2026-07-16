import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/procurement_report_entities.dart';
import '../bloc/procurement_bloc.dart';

class ProcurementReportsTab extends StatefulWidget {
  const ProcurementReportsTab({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<ProcurementReportsTab> createState() => _ProcurementReportsTabState();
}

class _ProcurementReportsTabState extends State<ProcurementReportsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementBloc>().add(const ProcurementReportLoadRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProcurementBloc, ProcurementState>(
      builder: (context, state) {
        if (state.status == ProcurementStatus.loading &&
            state.reportSummary == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = state.reportSummary;
        if (report == null) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: const Center(
                    child: Text('Rapport indisponible. Tirez pour actualiser.'),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Synthèse approvisionnement',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _KpiGrid(report: report),
              const SizedBox(height: AppSpacing.lg),
              if (report.overdueOrderCount > 0)
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: Icon(Icons.schedule, color: Colors.orange.shade800),
                    title: Text(
                      '${report.overdueOrderCount} commande(s) en retard',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    subtitle: const Text('Date de livraison prévue dépassée'),
                  ),
                ),
              if (report.unpaidInvoiceCount > 0)
                Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: Icon(Icons.receipt_long, color: Colors.red.shade800),
                    title: Text(
                      '${report.unpaidInvoiceCount} facture(s) impayée(s)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                    subtitle: Text(
                      'Montant dû : ${formatFcfa(report.unpaidInvoiceAmount)}',
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Top fournisseurs',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Divider(),
              if (report.topSuppliers.isEmpty)
                const Text(
                  'Aucune donnée.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                )
              else
                ...report.topSuppliers.map(
                  (s) => ListTile(
                    dense: true,
                    title: Text(s.supplierName),
                    subtitle: Text('${s.orderCount} commande(s)'),
                    trailing: Text(formatFcfa(s.totalAmount)),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Produits les plus commandés',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Divider(),
              if (report.topProducts.isEmpty)
                const Text(
                  'Aucune donnée.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                )
              else
                ...report.topProducts.map(
                  (p) => ListTile(
                    dense: true,
                    title: Text(p.productName),
                    subtitle: Text('${p.quantityOrdered} unités'),
                    trailing: Text(formatFcfa(p.totalCost)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.report});

  final ProcurementReportSummary report;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: [
        _KpiTile(
          label: 'En attente',
          value: '${report.pendingOrderCount}',
          subtitle: formatFcfa(report.pendingOrderAmount),
          icon: Icons.hourglass_top_outlined,
        ),
        _KpiTile(
          label: 'Réceptionnées',
          value: '${report.receivedOrderCount}',
          subtitle: formatFcfa(report.receivedOrderAmount),
          icon: Icons.inventory_2_outlined,
          color: Colors.green,
        ),
        _KpiTile(
          label: 'Annulées',
          value: '${report.cancelledOrderCount}',
          icon: Icons.cancel_outlined,
          color: Colors.red,
        ),
        _KpiTile(
          label: 'Factures impayées',
          value: '${report.unpaidInvoiceCount}',
          subtitle: formatFcfa(report.unpaidInvoiceAmount),
          icon: Icons.receipt_long_outlined,
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 20),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
