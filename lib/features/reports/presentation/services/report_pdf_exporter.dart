import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/documents/pdf_theme.dart';
import '../../../../core/utils/benin_day_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/report_entities.dart';

/// Export PDF des statistiques (RG-STAT-04).
class ReportPdfExporter {
  const ReportPdfExporter();

  Future<void> sharePdf({
    required String shopName,
    required Report report,
    required bool includeFinancial,
  }) async {
    final doc = _buildDocument(
      shopName: shopName,
      report: report,
      includeFinancial: includeFinancial,
    );
    final bytes = await doc.save();
    final stamp = formatBeninDate(report.generatedAt).replaceAll('/', '-');

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'statistiques_$stamp.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      subject: 'Statistiques — $shopName',
    );
  }

  pw.Document _buildDocument({
    required String shopName,
    required Report report,
    required bool includeFinancial,
  }) {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PdfTheme.headerBanner(
            title: shopName,
            subtitle: 'Rapport statistiques',
            badge: report.period.label,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Exporté le ${PdfTheme.formatBeninDateTime(report.generatedAt)}',
            style: PdfTheme.subtitleStyle,
          ),
          if (report.consolidated)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Vue consolidée (toutes boutiques)',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfTheme.textMuted,
                ),
              ),
            ),
          pw.SizedBox(height: 20),
          if (report.empty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: PdfTheme.surface,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfTheme.border),
              ),
              child: pw.Text(
                report.emptyMessage ?? 'Aucune donnée sur la période.',
                textAlign: pw.TextAlign.center,
                style: PdfTheme.bodyStyle,
              ),
            )
          else ...[
            PdfTheme.sectionTitle('Indicateurs ventes'),
            PdfTheme.kpiGrid([
              (label: 'CA brut', value: formatFcfa(report.sales.grossRevenue)),
              (label: 'CA encaissé', value: formatFcfa(report.sales.collectedRevenue)),
              (label: 'Nombre de ventes', value: '${report.sales.saleCount}'),
              (label: 'Panier moyen', value: formatFcfa(report.sales.averageBasket)),
              (label: 'Crédit accordé', value: formatFcfa(report.sales.creditGranted)),
              (
                label: 'Espèces / MoMo',
                value:
                    '${formatFcfa(report.sales.totalCash)} / ${formatFcfa(report.sales.totalMomo)}',
              ),
            ]),
            if (includeFinancial && report.financial != null) ...[
              pw.SizedBox(height: 16),
              PdfTheme.sectionTitle('Financier'),
              if (report.financial!.profitAvailable &&
                  report.financial!.estimatedProfit != null)
                PdfTheme.kpiGrid([
                  (
                    label: 'Bénéfice estimé',
                    value: formatFcfa(report.financial!.estimatedProfit!),
                  ),
                ])
              else if (report.financial!.profitWarning != null)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfTheme.surface,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfTheme.border),
                  ),
                  child: pw.Text(
                    report.financial!.profitWarning!,
                    style: PdfTheme.bodyStyle,
                  ),
                ),
              if (report.financial!.recoveryRateAvailable &&
                  report.financial!.recoveryRate != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: PdfTheme.kpiGrid([
                    (
                      label: 'Taux de recouvrement',
                      value: '${report.financial!.recoveryRate} %',
                    ),
                  ]),
                ),
            ],
            if (report.topProducts.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              PdfTheme.sectionTitle('Top produits'),
              pw.SizedBox(height: 6),
              PdfTheme.dataTable(
                headers: const ['#', 'Produit', 'Qté vendue', 'Chiffre d\'affaires'],
                columnWidths: const [0.6, 3, 1.2, 1.8],
                rows: report.topProducts
                    .map(
                      (p) => [
                        '${p.rank}',
                        p.productName,
                        p.quantitySold.toStringAsFixed(0),
                        formatFcfa(p.revenue),
                      ],
                    )
                    .toList(),
              ),
            ],
            if (report.sellerPerformance != null &&
                report.sellerPerformance!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              PdfTheme.sectionTitle('Performance vendeurs'),
              pw.SizedBox(height: 6),
              PdfTheme.dataTable(
                headers: const ['Vendeur', 'Ventes', 'Chiffre d\'affaires'],
                columnWidths: const [3, 1, 1.8],
                rows: report.sellerPerformance!
                    .map(
                      (s) => [
                        s.userName ?? 'Vendeur #${s.userId}',
                        '${s.saleCount}',
                        formatFcfa(s.totalRevenue),
                      ],
                    )
                    .toList(),
              ),
            ],
          ],
          pw.SizedBox(height: 24),
          PdfTheme.footerNote('Document généré par ARIKE'),
        ],
      ),
    );
    return doc;
  }
}
