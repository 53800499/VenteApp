import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/benin_day_range.dart';
import '../../domain/entities/audit_entities.dart';

class AuditPdfExporter {
  const AuditPdfExporter();

  Future<void> sharePdf({
    required String shopName,
    required AuditExportResult export,
  }) async {
    final doc = _buildDocument(shopName: shopName, export: export);
    final bytes = await doc.save();

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'audit_${formatBeninDate(export.exportedAt)}.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      subject: 'Journal d\'audit — $shopName',
    );
  }

  Future<void> printPdf({
    required String shopName,
    required AuditExportResult export,
  }) async {
    final doc = _buildDocument(shopName: shopName, export: export);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Document _buildDocument({
    required String shopName,
    required AuditExportResult export,
  }) {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Journal d\'audit — $shopName',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            'Exporté le ${_formatDateTime(export.exportedAt)} — '
            '${export.total} entrée(s)',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          ...export.entries.map(_entryBlock),
          if (export.pdfHint.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              export.pdfHint,
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
    return doc;
  }

  pw.Widget _entryBlock(AuditLogDetail entry) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${entry.actionLabel} — ${entry.moduleLabel}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${_formatDateTime(entry.createdAt)} · '
            '${entry.userName ?? 'Utilisateur #${entry.userId}'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (entry.reason != null && entry.reason!.isNotEmpty)
            pw.Text('Motif : ${entry.reason}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'Entité : ${entry.entityTable} #${entry.entityId}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (entry.oldValue != null)
            pw.Text(
              'Avant : ${_compactJson(entry.oldValue!)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          if (entry.newValue != null)
            pw.Text(
              'Après : ${_compactJson(entry.newValue!)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(int ms) {
    const offset = 60 * 60 * 1000;
    final local = DateTime.fromMillisecondsSinceEpoch(
      ms + offset,
      isUtc: true,
    );
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$d $h:$min';
  }

  String _compactJson(Map<String, dynamic> map) {
    try {
      final encoded = jsonEncode(map);
      return encoded.length > 120 ? '${encoded.substring(0, 117)}…' : encoded;
    } catch (_) {
      return map.toString();
    }
  }
}

String formatAuditDateTime(int ms) {
  const offset = 60 * 60 * 1000;
  final local = DateTime.fromMillisecondsSinceEpoch(ms + offset, isUtc: true);
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$m-$d à $h:$min';
}
