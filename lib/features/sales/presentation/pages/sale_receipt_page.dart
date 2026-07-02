import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/services/receipt_formatter_service.dart';
import '../widgets/sale_feedback.dart';
import 'new_sale_page.dart';

class SaleReceiptPage extends StatefulWidget {
  const SaleReceiptPage({
    super.key,
    required this.session,
    required this.sale,
  });

  final AuthSession session;
  final Sale sale;

  @override
  State<SaleReceiptPage> createState() => _SaleReceiptPageState();
}

class _SaleReceiptPageState extends State<SaleReceiptPage> {
  bool _sharing = false;
  bool _printing = false;

  String get _receiptText {
    final formatter = sl<ReceiptFormatterService>();
    return formatter.formatText(
      shopName: widget.session.shop.name,
      sale: widget.sale,
    );
  }

  Future<void> _shareReceipt() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await Share.share(
        _receiptText,
        subject: widget.sale.receiptNumber ?? 'Reçu VenteApp',
      );
      if (mounted) {
        await SaleFeedback.showSuccess(
          context: context,
          title: 'Reçu partagé',
          message: 'Le reçu est prêt dans l\'application choisie.',
        );
      }
    } catch (_) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Partage impossible',
          message: 'Impossible de partager le reçu.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _printReceipt() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await SaleFeedback.runWithBlockingLoader(
        context: context,
        message: 'Préparation de l\'impression…',
        action: () async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.roll80,
              build: (context) => pw.Text(
                _receiptText,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          );
          await Printing.layoutPdf(onLayout: (_) async => doc.save());
        },
      );
    } catch (_) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Impression impossible',
          message: 'Impossible d\'imprimer le reçu.',
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _openConversion() async {
    final confirmed = await SaleFeedback.confirm(
      context: context,
      title: 'Convertir en vente standard',
      message:
          'Répartir ${formatFcfa(widget.sale.totalAmount)} en produits ?',
    );
    if (confirmed != true || !mounted) return;

    final converted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewSalePage(
          session: widget.session,
          conversion: QuickSaleConversion(
            saleId: widget.sale.id,
            targetTotal: widget.sale.totalAmount,
            receiptLabel: widget.sale.receiptNumber,
          ),
        ),
      ),
    );
    if (converted == true && mounted) {
      await SaleFeedback.showSuccess(
        context: context,
        title: 'Conversion réussie',
        message: 'La vente rapide a été convertie en vente standard.',
      );
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reçu de vente'),
        actions: [
          IconButton(
            icon: _sharing
                ? SaleFeedback.inlineLoader(size: 18)
                : const Icon(Icons.share_outlined),
            tooltip: 'Partager',
            onPressed: _sharing ? null : _shareReceipt,
          ),
          IconButton(
            icon: _printing
                ? SaleFeedback.inlineLoader(size: 18)
                : const Icon(Icons.print_outlined),
            tooltip: 'Imprimer',
            onPressed: _printing ? null : _printReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  widget.session.shop.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  sale.receiptNumber ?? 'Vente #${sale.id}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(date),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xl),
          if (sale.items.isNotEmpty) ...[
            Text('Articles', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...sale.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item.productName} × ${item.quantity}'),
                    ),
                    Text(formatFcfa(item.lineTotal)),
                  ],
                ),
              ),
            ),
            const Divider(),
          ],
          _ReceiptRow(label: 'Sous-total', value: formatFcfa(sale.subtotal)),
          if (sale.discountAmount > 0)
            _ReceiptRow(
              label: 'Remise',
              value: '- ${formatFcfa(sale.discountAmount)}',
            ),
          _ReceiptRow(
            label: 'Total',
            value: formatFcfa(sale.totalAmount),
            emphasized: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _ReceiptRow(
            label: 'Paiement',
            value: sale.paymentMethod.label,
          ),
          if (sale.amountCash > 0)
            _ReceiptRow(label: 'Espèces', value: formatFcfa(sale.amountCash)),
          if (sale.amountMomo > 0)
            _ReceiptRow(
              label: 'Mobile Money',
              value: formatFcfa(sale.amountMomo),
            ),
          if (sale.amountCredit > 0)
            _ReceiptRow(label: 'Crédit', value: formatFcfa(sale.amountCredit)),
          if (sale.customerName != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ReceiptRow(label: 'Client', value: sale.customerName!),
          ],
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Merci pour votre achat !',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (sale.saleType == SaleType.quick &&
              sale.items.isEmpty &&
              PermissionGuard.can(
                widget.session.user.permissions,
                Permission.salesCreate,
              )) ...[
            FilledButton.icon(
              onPressed: _openConversion,
              icon: const Icon(Icons.transform_outlined),
              label: const Text('Convertir en vente standard'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: _sharing ? null : _shareReceipt,
            icon: _sharing
                ? SaleFeedback.inlineLoader(size: 18)
                : const Icon(Icons.share_outlined),
            label: Text(_sharing ? 'Partage…' : 'Partager le reçu'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _printing ? null : _printReceipt,
            icon: _printing
                ? SaleFeedback.inlineLoader(size: 18)
                : const Icon(Icons.print_outlined),
            label: Text(_printing ? 'Impression…' : 'Imprimer'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
