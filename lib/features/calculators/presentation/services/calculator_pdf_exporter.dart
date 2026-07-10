import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/time.dart';
import '../../../../core/utils/benin_day_range.dart';
import '../../../../core/utils/currency_formatter.dart';

class CalculatorPdfExporter {
  const CalculatorPdfExporter();

  Future<void> sharePdf({
    required String shopName,
    required String calculatorLabel,
    required Map<String, dynamic> inputs,
    required List<Map<String, String>> metrics,
    double estimatedPrice = 0.0,
    String? productName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          shopName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Calculateur Métier : $calculatorLabel',
                          style: const pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date : ${formatBeninDate(nowMs())}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.blue900),
                pw.SizedBox(height: 24),

                if (productName != null) ...[
                  pw.Text(
                    'Produit lié : $productName',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section Inputs
                pw.Text(
                  'Paramètres de calcul (Entrées)',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  headers: ['Paramètre', 'Valeur renseignée'],
                  data: inputs.entries.map((e) {
                    final keyTranslated = _translateInputKey(e.key);
                    return [keyTranslated, '${e.value}'];
                  }).toList(),
                ),
                pw.SizedBox(height: 24),

                // Section Results (Metrics)
                pw.Text(
                  'Quantités estimées (Résultats)',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  headers: ['Libellé', 'Estimation', 'Unité'],
                  data: metrics.map((m) {
                    return [
                      m['label'] ?? '',
                      m['value'] ?? '',
                      m['unit'] ?? '',
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 24),

                // Total Price Estimation
                if (estimatedPrice > 0)
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Coût total estimé : ',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          formatFcfa(estimatedPrice.toInt()),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),

                pw.Spacer(),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Signature Conseiller', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 40),
                        pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Signature Client', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 40),
                        pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileStamp = nowMs().toString();

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'estimation_${calculatorLabel.toLowerCase()}_$fileStamp.pdf',
          mimeType: 'application/pdf',
        )
      ],
      subject: 'Fiche d\'estimation $calculatorLabel — $shopName',
    );
  }

  String _translateInputKey(String key) {
    switch (key) {
      case 'area':
        return 'Surface (m2)';
      case 'tileLengthCm':
        return 'Longueur carreau (cm)';
      case 'tileWidthCm':
        return 'Largeur carreau (cm)';
      case 'wastePercent':
        return 'Marge de perte (%)';
      case 'piecesPerBox':
        return 'Carreaux par carton';
      case 'coveragePerLiter':
        return 'Rendement (m2/L)';
      case 'coatsCount':
        return 'Nombre de couches';
      case 'bucketVolume':
        return 'Volume contenant (L)';
      case 'volume':
        return 'Volume béton (m3)';
      case 'cementDosage':
        return 'Dosage ciment (kg/m3)';
      case 'bagWeight':
        return 'Poids sac ciment (kg)';
      case 'sandProportion':
        return 'Proportion sable (L/m3)';
      case 'gravelProportion':
        return 'Proportion gravier (L/m3)';
      default:
        return key;
    }
  }
}
