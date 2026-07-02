import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

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
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Statistiques — $shopName',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            '${report.period.label} · exporté le ${_formatDateTime(report.generatedAt)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (report.consolidated)
            pw.Text(
              'Vue consolidée (toutes boutiques)',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          pw.SizedBox(height: 16),
          if (report.empty)
            pw.Text(report.emptyMessage ?? 'Aucune donnée sur la période.')
          else ...[
            pw.Text('Ventes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _kpiLine('CA brut', formatFcfa(report.sales.grossRevenue)),
            _kpiLine('CA encaissé', formatFcfa(report.sales.collectedRevenue)),
            _kpiLine('Crédit accordé', formatFcfa(report.sales.creditGranted)),
            _kpiLine('Panier moyen', formatFcfa(report.sales.averageBasket)),
            _kpiLine('Nombre de ventes', '${report.sales.saleCount}'),
            _kpiLine(
              'Espèces / MoMo',
              '${formatFcfa(report.sales.totalCash)} / ${formatFcfa(report.sales.totalMomo)}',
            ),
            if (includeFinancial && report.financial != null) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Financier',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              if (report.financial!.profitAvailable &&
                  report.financial!.estimatedProfit != null)
                _kpiLine(
                  'Bénéfice estimé',
                  formatFcfa(report.financial!.estimatedProfit!),
                )
              else if (report.financial!.profitWarning != null)
                pw.Text(report.financial!.profitWarning!),
              if (report.financial!.recoveryRateAvailable &&
                  report.financial!.recoveryRate != null)
                _kpiLine(
                  'Taux de recouvrement',
                  '${report.financial!.recoveryRate} %',
                ),
            ],
            if (report.topProducts.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Top produits',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              ...report.topProducts.map(
                (p) => pw.Text(
                  '${p.rank}. ${p.productName} — '
                  '${p.quantitySold.toStringAsFixed(0)} vendus · ${formatFcfa(p.revenue)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
            if (report.sellerPerformance != null &&
                report.sellerPerformance!.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Performance vendeurs',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              ...report.sellerPerformance!.map(
                (s) => pw.Text(
                  '${s.userName ?? 'Vendeur #${s.userId}'} — '
                  '${s.saleCount} ventes · ${formatFcfa(s.totalRevenue)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ],
        ],
      ),
    );
    return doc;
  }

  pw.Widget _kpiLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  String _formatDateTime(int ms) {
    const offset = 60 * 60 * 1000;
    final local = DateTime.fromMillisecondsSinceEpoch(ms + offset, isUtc: true);
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$d $h:$min';
  }
}
