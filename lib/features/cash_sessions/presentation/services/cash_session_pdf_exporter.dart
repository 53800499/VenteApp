import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/documents/pdf_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/cash_session_entities.dart';

/// Export PDF du rapport de clôture de caisse.
class CashSessionPdfExporter {
  const CashSessionPdfExporter();

  Future<void> sharePdf({
    required String shopName,
    required CashSession session,
    List<CashMovement> movements = const [],
  }) async {
    final doc = _buildDocument(
      shopName: shopName,
      session: session,
      movements: movements,
    );
    final bytes = await doc.save();
    final dt = DateTime.fromMillisecondsSinceEpoch(session.openedAt);
    final stamp =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'cloture_caisse_$stamp.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      subject: 'Clôture de caisse — $shopName',
    );
  }

  pw.Document _buildDocument({
    required String shopName,
    required CashSession session,
    required List<CashMovement> movements,
  }) {
    final doc = pw.Document();
    final opened = AppDateFormatter.formatDateTime(
      DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );
    final closed = session.closedAt != null
        ? AppDateFormatter.formatDateTime(
            DateTime.fromMillisecondsSinceEpoch(session.closedAt!),
          )
        : '—';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PdfTheme.headerBanner(
            title: shopName,
            subtitle: 'Rapport de clôture de caisse',
            badge: AppDateFormatter.formatDate(
              DateTime.fromMillisecondsSinceEpoch(session.openedAt),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Statut : ${session.status.label}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Ouverture : $opened · ${session.openedByName}'),
          if (session.submittedAt != null)
            pw.Text(
              'Soumission : ${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(session.submittedAt!))}',
            ),
          if (session.closedByName != null)
            pw.Text('Clôture : $closed · ${session.closedByName}'),
          if (session.approvedAt != null)
            pw.Text(
              'Validation : ${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(session.approvedAt!))}',
            ),
          pw.SizedBox(height: 16),
          _section('Synthèse', [
            _row('Fond initial espèces', session.openingCash),
            _row('Fond initial MoMo', session.openingMomo),
            _row('Ventes espèces', session.salesCash),
            _row('Ventes MoMo', session.salesMomo),
            _row('Dépenses espèces', session.expensesCash),
            _row('Dépenses MoMo', session.expensesMomo),
            _row('Entrées espèces', session.depositsCash),
            _row('Entrées MoMo', session.depositsMomo),
            _row('Retraits espèces', session.withdrawalsCash),
            _row('Retraits MoMo', session.withdrawalsMomo),
            _row('Nombre de ventes', session.saleCount, money: false),
          ]),
          pw.SizedBox(height: 12),
          _section('Clôture & Rapprochement', [
            _row('Attendu espèces', session.expectedCash ?? 0, bold: true),
            _row('Attendu MoMo', session.expectedMomo ?? 0, bold: true),
            _row('Compté espèces', session.countedCash ?? 0, bold: true),
            _row('Compté MoMo', session.countedMomo ?? 0, bold: true),
            _row('Écart espèces', session.differenceCash ?? 0, bold: true),
            _row('Écart MoMo', session.differenceMomo ?? 0, bold: true),
            _row('Écart net total', session.totalDifference, bold: true),
          ]),
          if (session.justificationCategory != null ||
              session.justificationNote != null) ...[
            pw.SizedBox(height: 12),
            _section('Justification de l\'écart', [
              if (session.justificationCategory != null)
                pw.Text(
                  'Motif : ${session.justificationCategory!.discrepancyCategoryLabel}',
                ),
              if (session.justificationNote != null)
                pw.Text('Explication employé : ${session.justificationNote!}'),
            ]),
          ],
          if (session.reviewNote?.isNotEmpty == true) ...[
            pw.SizedBox(height: 12),
            _section('Décision du responsable', [
              pw.Text('Observation : ${session.reviewNote!}'),
            ]),
          ],
          if (session.closingNote?.isNotEmpty == true) ...[
            pw.SizedBox(height: 12),
            pw.Text('Note générale : ${session.closingNote}'),
          ],
          if (movements.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Mouvements manuels',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Type', 'Support', 'Montant', 'Note'],
              data: movements
                  .map(
                    (m) => [
                      m.movementType.label,
                      m.registerType.label,
                      formatFcfa(m.amount),
                      m.note ?? '',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ],
      ),
    );
    return doc;
  }

  pw.Widget _section(String title, List<pw.Widget> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...rows,
      ],
    );
  }

  pw.Widget _row(String label, int value,
      {bool money = true, bool bold = false}) {
    final text = money ? formatFcfa(value) : '$value';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.Text(
            text,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
