import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
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
  ShopConfiguration? _config;

  ReceiptFormatterService get _formatter => sl<ReceiptFormatterService>();

  String get _shopName =>
      _config?.shop.name ?? widget.session.shop.name;

  String? get _shopPhone => _config?.shop.phone;

  String? get _shopAddress => _config?.shop.address;

  String? get _receiptFooter => _config?.receipts.footer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    ensureSettingsDependencies();
    try {
      final config = await sl<GetShopConfiguration>()(
        shopId: widget.session.shop.id,
      );
      if (mounted) setState(() => _config = config);
    } catch (_) {}
  }

  Future<void> _shareReceipt() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final doc = _formatter.buildPdf(
        shopName: _shopName,
        sale: widget.sale,
        shopPhone: _shopPhone,
        shopAddress: _shopAddress,
        receiptFooter: _receiptFooter,
      );
      final bytes = await doc.save();
      final receiptNo =
          widget.sale.receiptNumber ?? 'vente_${widget.sale.id}';
      final safeName = receiptNo.replaceAll(RegExp(r'[^\w\-]+'), '_');

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'recu_$safeName.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        subject: 'Reçu — $_shopName',
        text: _formatter.formatText(
          shopName: _shopName,
          sale: widget.sale,
          shopPhone: _shopPhone,
          shopAddress: _shopAddress,
          receiptFooter: _receiptFooter,
        ),
      );
      if (mounted) {
        await SaleFeedback.showSuccess(
          context: context,
          title: 'Reçu partagé',
          message: 'Le PDF est prêt dans l\'application choisie.',
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
          final doc = _formatter.buildPdf(
            shopName: _shopName,
            sale: widget.sale,
            shopPhone: _shopPhone,
            shopAddress: _shopAddress,
            receiptFooter: _receiptFooter,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final date = _formatDisplayDate(sale.createdAt);
    final footer = _receiptFooter?.trim().isNotEmpty == true
        ? _receiptFooter!.trim()
        : 'Merci pour votre achat !';

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
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
            tooltip: 'Terminer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _shopName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.seed,
                        ),
                      ),
                      if (_shopPhone != null && _shopPhone!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _shopPhone!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                      if (_shopAddress != null && _shopAddress!.isNotEmpty)
                        Text(
                          _shopAddress!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      const _DashedDivider(),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          sale.receiptNumber ?? 'Vente #${sale.id}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        date,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _DashedDivider(),
                      if (sale.items.isNotEmpty) ...[
                        _ReceiptTableHeader(theme: theme),
                        ...sale.items.map(
                          (item) => _ReceiptItemRow(item: item),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            'Vente rapide',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      const _DashedDivider(),
                      _ReceiptRow(
                        label: 'Sous-total',
                        value: formatFcfa(sale.subtotal),
                      ),
                      if (sale.discountAmount > 0)
                        _ReceiptRow(
                          label: 'Remise',
                          value: '- ${formatFcfa(sale.discountAmount)}',
                          valueColor: colorScheme.error,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: _ReceiptRow(
                          label: 'Total',
                          value: formatFcfa(sale.totalAmount),
                          emphasized: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _DashedDivider(),
                      _ReceiptRow(
                        label: 'Paiement',
                        value: sale.paymentMethod.label,
                      ),
                      if (sale.amountCash > 0)
                        _ReceiptRow(
                          label: 'Espèces',
                          value: formatFcfa(sale.amountCash),
                        ),
                      if (sale.amountMomo > 0)
                        _ReceiptRow(
                          label: 'Mobile Money',
                          value: formatFcfa(sale.amountMomo),
                        ),
                      if (sale.amountCredit > 0)
                        _ReceiptRow(
                          label: 'Crédit',
                          value: formatFcfa(sale.amountCredit),
                        ),
                      if (sale.customerName != null)
                        _ReceiptRow(
                          label: 'Client',
                          value: sale.customerName!,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        footer,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
          FilledButton.icon(
            onPressed: _sharing ? null : _shareReceipt,
            icon: _sharing
                ? SaleFeedback.inlineLoader(size: 18)
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_sharing ? 'Partage…' : 'Partager le reçu (PDF)'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
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

  String _formatDisplayDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} à $h:$min';
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final dashCount =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ReceiptTableHeader extends StatelessWidget {
  const _ReceiptTableHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final label = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.onSurfaceMuted,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Article', style: label)),
          Expanded(child: Text('Qté', textAlign: TextAlign.center, style: label)),
          Expanded(
            flex: 2,
            child: Text('Total', textAlign: TextAlign.end, style: label),
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemRow extends StatelessWidget {
  const _ReceiptItemRow({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${formatFcfa(item.unitPrice)} × ${item.quantity}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatFcfa(item.lineTotal),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style?.copyWith(
              color: valueColor,
              fontWeight: emphasized ? FontWeight.w700 : style.fontWeight,
            ),
          ),
        ],
      ),
    );
  }
}
