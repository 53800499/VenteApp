import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/documents/pdf_theme.dart';
import '../../../../core/utils/benin_day_range.dart';
import '../../domain/entities/audit_entities.dart';
import 'audit_value_presenter.dart';

class AuditPdfExporter {
  const AuditPdfExporter();

  static const _presenter = AuditValuePresenter();

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
    final single = export.entries.length == 1;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PdfTheme.headerBanner(
            title: shopName,
            subtitle: single
                ? 'Détail d\'audit'
                : 'Journal d\'audit',
            badge: '${export.total} entrée(s)',
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Exporté le ${_formatDateTime(export.exportedAt)}',
            style: PdfTheme.subtitleStyle,
          ),
          pw.SizedBox(height: 16),
          if (!single) ...[
            PdfTheme.sectionTitle('Synthèse'),
            PdfTheme.dataTable(
              headers: const [
                'Date',
                'Action',
                'Module',
                'Utilisateur',
                'Entité',
              ],
              columnWidths: const [1.4, 1.6, 1.1, 1.3, 1.2],
              rows: export.entries
                  .map(
                    (e) => [
                      _formatDateTime(e.createdAt),
                      e.actionLabel,
                      e.moduleLabel,
                      e.userName ?? '#${e.userId}',
                      '${_presenter.entityLabel(e.entityTable)} #${e.entityId}',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            PdfTheme.sectionTitle('Détail des modifications'),
          ],
          ...export.entries.map(_entryBlock),
          if (export.pdfHint.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              export.pdfHint,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfTheme.textMuted,
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
    final diffs = _presenter.diff(
      before: entry.oldValue,
      after: entry.newValue,
    );
    final rows = diffs.isEmpty && entry.newValue != null
        ? _presenter.rowsFrom(entry.newValue!)
        : const <({String label, String value})>[];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfTheme.border),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            entry.actionLabel,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.primaryDark,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${entry.moduleLabel} · ${_formatDateTime(entry.createdAt)}',
            style: PdfTheme.labelStyle,
          ),
          pw.Text(
            'Par ${entry.userName ?? 'Utilisateur #${entry.userId}'} · '
            '${_presenter.entityLabel(entry.entityTable)} #${entry.entityId}',
            style: PdfTheme.labelStyle,
          ),
          if (entry.reason != null && entry.reason!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Motif : ${entry.reason}', style: PdfTheme.bodyStyle),
          ],
          if (diffs.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Modifications', style: PdfTheme.sectionTitleStyle),
            pw.SizedBox(height: 6),
            PdfTheme.dataTable(
              headers: const ['Champ', 'Avant', 'Après'],
              columnWidths: const [1.2, 1.4, 1.4],
              rows: diffs
                  .map(
                    (d) => [
                      d.label,
                      d.before ?? '—',
                      d.after ?? '—',
                    ],
                  )
                  .toList(),
            ),
          ] else if (rows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Données', style: PdfTheme.sectionTitleStyle),
            pw.SizedBox(height: 6),
            PdfTheme.dataTable(
              headers: const ['Champ', 'Valeur'],
              columnWidths: const [1.2, 2.8],
              rows: rows.map((r) => [r.label, r.value]).toList(),
            ),
          ],
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
    return '$d/$m/${local.year} $h:$min';
  }
}

String formatAuditDateTime(int ms) {
  const offset = 60 * 60 * 1000;
  final local = DateTime.fromMillisecondsSinceEpoch(ms + offset, isUtc: true);
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$d/$m/${local.year} à $h:$min';
}
