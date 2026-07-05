import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Styles et helpers partagés pour les exports PDF (reçus, statistiques…).
abstract final class PdfTheme {
  static const primary = PdfColor.fromInt(0xFF0B6E4F);
  static const primaryDark = PdfColor.fromInt(0xFF084A36);
  static const surface = PdfColor.fromInt(0xFFF4F7F5);
  static const border = PdfColor.fromInt(0xFFDDE5E0);
  static const textMuted = PdfColor.fromInt(0xFF5C6B63);

  static pw.TextStyle get titleStyle => pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: primaryDark,
      );

  static pw.TextStyle get subtitleStyle => const pw.TextStyle(
        fontSize: 10,
        color: textMuted,
      );

  static pw.TextStyle get sectionTitleStyle => pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: primaryDark,
      );

  static pw.TextStyle get bodyStyle => const pw.TextStyle(fontSize: 10);

  static pw.TextStyle get labelStyle => const pw.TextStyle(
        fontSize: 9,
        color: textMuted,
      );

  static pw.Widget headerBanner({
    required String title,
    String? subtitle,
    String? badge,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: primary,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
            ),
          ],
          if (badge != null && badge.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                badge,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
      child: pw.Text(title, style: sectionTitleStyle),
    );
  }

  static pw.Widget kpiGrid(List<({String label, String value})> items) {
    final rows = <pw.Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            children: [
              pw.Expanded(child: kpiCard(items[i].label, items[i].value)),
              if (i + 1 < items.length) ...[
                pw.SizedBox(width: 8),
                pw.Expanded(child: kpiCard(items[i + 1].label, items[i + 1].value)),
              ] else
                pw.Spacer(),
            ],
          ),
        ),
      );
    }
    return pw.Column(children: rows);
  }

  static pw.Widget kpiCard(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: labelStyle),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget dataTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<double>? columnWidths,
  }) {
    if (rows.isEmpty) {
      return pw.Text('Aucune donnée.', style: labelStyle);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.5),
      columnWidths: columnWidths != null
          ? {
              for (var i = 0; i < columnWidths.length; i++)
                i: pw.FlexColumnWidth(columnWidths[i]),
            }
          : null,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: surface),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: row
                .map(
                  (cell) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(cell, style: bodyStyle),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget dashedDivider() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      height: 1,
      color: border,
    );
  }

  static pw.Widget totalRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryDark,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget keyValueRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: bold
                  ? pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)
                  : bodyStyle,
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: bold
                  ? pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)
                  : bodyStyle,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget footerNote(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontStyle: pw.FontStyle.italic,
          color: textMuted,
        ),
      ),
    );
  }

  static String formatBeninDateTime(int ms) {
    const offset = 60 * 60 * 1000;
    final local = DateTime.fromMillisecondsSinceEpoch(ms + offset, isUtc: true);
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} à $h:$min';
  }
}
