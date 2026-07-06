import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/documents/pdf_theme.dart';
import '../../../../core/utils/benin_day_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/expense_entities.dart';

/// Export PDF de la liste des dépenses.
class ExpensePdfExporter {
  const ExpensePdfExporter();

  Future<void> sharePdf({
    required String shopName,
    required List<Expense> expenses,
    required ExpenseSummary? summary,
    String periodLabel = 'Toutes périodes',
  }) async {
    final doc = _buildDocument(
      shopName: shopName,
      expenses: expenses,
      summary: summary,
      periodLabel: periodLabel,
    );
    final bytes = await doc.save();
    final stamp = formatBeninDate().replaceAll('/', '-');

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'depenses_$stamp.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      subject: 'Dépenses — $shopName',
    );
  }

  pw.Document _buildDocument({
    required String shopName,
    required List<Expense> expenses,
    required ExpenseSummary? summary,
    required String periodLabel,
  }) {
    final doc = pw.Document();
    final validated = expenses.where((e) => e.isValidated).toList();
    final total = validated.fold<int>(0, (sum, e) => sum + e.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PdfTheme.headerBanner(
            title: shopName,
            subtitle: 'Rapport des dépenses',
            badge: periodLabel,
          ),
          pw.SizedBox(height: 16),
          if (summary != null)
            PdfTheme.kpiGrid([
              (
                label: 'Aujourd\'hui',
                value: formatFcfa(summary.today.totalAmount),
              ),
              (
                label: 'Cette semaine',
                value: formatFcfa(summary.week.totalAmount),
              ),
              (
                label: 'Ce mois',
                value: formatFcfa(summary.month.totalAmount),
              ),
              (
                label: 'Caisse estimée',
                value: formatFcfa(summary.estimatedCashBalance),
              ),
            ]),
          pw.SizedBox(height: 20),
          PdfTheme.sectionTitle('Liste (${validated.length} dépense(s))'),
          pw.SizedBox(height: 8),
          if (validated.isEmpty)
            pw.Text('Aucune dépense validée sur la période.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Titre', 'Catégorie', 'Paiement', 'Montant'],
              data: validated
                  .map(
                    (e) => [
                      formatBeninDate(e.expenseDate),
                      e.title,
                      e.categoryName ?? '—',
                      e.paymentMethod.label,
                      formatFcfa(e.amount),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfTheme.surface),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total validé : ${formatFcfa(total)}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return doc;
  }
}
