import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/documents/pdf_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/sale_entities.dart';

/// Formate un reçu de vente (texte, PDF partage / impression).
class ReceiptFormatterService {
  const ReceiptFormatterService();

  String formatText({
    required String shopName,
    required Sale sale,
    String? shopPhone,
    String? shopAddress,
    String? receiptFooter,
  }) {
    final buffer = StringBuffer();
    final date = PdfTheme.formatBeninDateTime(sale.createdAt);

    buffer.writeln(shopName.toUpperCase());
    if (shopPhone != null && shopPhone.isNotEmpty) buffer.writeln(shopPhone);
    if (shopAddress != null && shopAddress.isNotEmpty) buffer.writeln(shopAddress);
    buffer.writeln('─' * 32);
    buffer.writeln(sale.receiptNumber ?? 'Vente #${sale.id}');
    buffer.writeln(date);
    buffer.writeln('─' * 32);

    if (sale.items.isEmpty) {
      buffer.writeln('Vente rapide');
    } else {
      for (final item in sale.items) {
        buffer.writeln(_padLine(item.productName, item.quantity.toString()));
        buffer.writeln(_padLine('  ${formatFcfa(item.unitPrice)} × ${item.quantity}', formatFcfa(item.lineTotal)));
      }
    }

    buffer.writeln('─' * 32);
    buffer.writeln(_padLine('Sous-total', formatFcfa(sale.subtotal)));
    if (sale.discountAmount > 0) {
      buffer.writeln(_padLine('Remise', '- ${formatFcfa(sale.discountAmount)}'));
    }
    buffer.writeln(_padLine('TOTAL', formatFcfa(sale.totalAmount)));
    buffer.writeln('─' * 32);
    buffer.writeln(_padLine('Paiement', sale.paymentMethod.label));
    if (sale.amountCash > 0) buffer.writeln(_padLine('Espèces', formatFcfa(sale.amountCash)));
    if (sale.amountMomo > 0) buffer.writeln(_padLine('Mobile Money', formatFcfa(sale.amountMomo)));
    if (sale.amountCredit > 0) buffer.writeln(_padLine('Crédit', formatFcfa(sale.amountCredit)));
    if (sale.customerName != null) {
      buffer.writeln(_padLine('Client', sale.customerName!));
    }
    buffer.writeln('─' * 32);
    buffer.writeln(receiptFooter?.trim().isNotEmpty == true ? receiptFooter!.trim() : 'Merci pour votre achat !');
    return buffer.toString();
  }

  pw.Document buildPdf({
    required String shopName,
    required Sale sale,
    String? shopPhone,
    String? shopAddress,
    String? receiptFooter,
  }) {
    final doc = pw.Document();
    final date = PdfTheme.formatBeninDateTime(sale.createdAt);
    final receiptNo = sale.receiptNumber ?? 'Vente #${sale.id}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              shopName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: PdfTheme.titleStyle.copyWith(fontSize: 14),
            ),
            if (shopPhone != null && shopPhone.isNotEmpty)
              pw.Text(shopPhone, textAlign: pw.TextAlign.center, style: PdfTheme.subtitleStyle),
            if (shopAddress != null && shopAddress.isNotEmpty)
              pw.Text(shopAddress, textAlign: pw.TextAlign.center, style: PdfTheme.subtitleStyle),
            PdfTheme.dashedDivider(),
            pw.Text(receiptNo, textAlign: pw.TextAlign.center, style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            )),
            pw.Text(date, textAlign: pw.TextAlign.center, style: PdfTheme.subtitleStyle),
            PdfTheme.dashedDivider(),
            if (sale.items.isEmpty)
              pw.Text('Vente rapide', style: PdfTheme.bodyStyle)
            else
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfTheme.surface),
                    children: [
                      _cell('Article', bold: true),
                      _cell('Qté', bold: true, align: pw.TextAlign.center),
                      _cell('Total', bold: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...sale.items.map(
                    (item) => pw.TableRow(
                      children: [
                        _cell(item.productName),
                        _cell('${item.quantity}', align: pw.TextAlign.center),
                        _cell(formatFcfa(item.lineTotal), align: pw.TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
            PdfTheme.dashedDivider(),
            PdfTheme.keyValueRow('Sous-total', formatFcfa(sale.subtotal)),
            if (sale.discountAmount > 0)
              PdfTheme.keyValueRow('Remise', '- ${formatFcfa(sale.discountAmount)}'),
            pw.SizedBox(height: 4),
            PdfTheme.totalRow('TOTAL', formatFcfa(sale.totalAmount)),
            PdfTheme.dashedDivider(),
            PdfTheme.keyValueRow('Paiement', sale.paymentMethod.label),
            if (sale.amountCash > 0)
              PdfTheme.keyValueRow('Espèces', formatFcfa(sale.amountCash)),
            if (sale.amountMomo > 0)
              PdfTheme.keyValueRow('Mobile Money', formatFcfa(sale.amountMomo)),
            if (sale.amountCredit > 0)
              PdfTheme.keyValueRow('Crédit', formatFcfa(sale.amountCredit)),
            if (sale.customerName != null)
              PdfTheme.keyValueRow('Client', sale.customerName!),
            PdfTheme.footerNote(
              receiptFooter?.trim().isNotEmpty == true
                  ? receiptFooter!.trim()
                  : 'Merci pour votre achat !',
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'ARIKE',
              textAlign: pw.TextAlign.center,
              style: PdfTheme.labelStyle,
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _padLine(String left, String right, {int width = 32}) {
    final gap = width - left.length - right.length;
    if (gap <= 0) return '$left $right';
    return '$left${' ' * gap}$right';
  }
}
