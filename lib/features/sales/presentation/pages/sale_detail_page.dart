import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../widgets/sale_feedback.dart';
import 'new_sale_page.dart';
import 'sale_receipt_page.dart';
import 'sale_replacement_page.dart';

class SaleDetailPage extends StatefulWidget {
  const SaleDetailPage({
    super.key,
    required this.session,
    required this.saleId,
  });

  final AuthSession session;
  final int saleId;

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  Sale? _sale;
  List<SaleReplacement> _replacements = const [];
  String? _error;
  bool _loading = true;
  bool _cancelling = false;

  bool get _canCancel =>
      widget.session.user.role == UserRole.owner &&
      PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCancel,
      );

  bool get _canReplace =>
      PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCreate,
      );

  bool get _canConvert =>
      PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCreate,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshSale() async {
    try {
      final sale = await sl<GetSale>()(
        session: widget.session,
        saleId: widget.saleId,
      );
      final replacements = await sl<ListSaleReplacements>()(
        session: widget.session,
        saleId: widget.saleId,
      );
      if (mounted) {
        setState(() {
          _sale = sale;
          _replacements = replacements;
          _error = null;
          _loading = false;
        });
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger la vente.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _refreshSale();
  }

  Future<void> _cancel() async {
    final reason = await SaleFeedback.confirmWithReason(
      context: context,
      title: 'Annuler la vente',
      hint: 'Motif (min. 5 caractères)',
      confirmLabel: 'Annuler la vente',
    );
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await sl<CancelSale>()(
        session: widget.session,
        saleId: widget.saleId,
        reason: reason,
      );

      if (!mounted) return;
      await SaleFeedback.showSuccess(
        context: context,
        title: 'Vente annulée',
        message: 'La vente a été annulée avec succès.',
      );
      if (mounted) await _refreshSale();
    } on Failure catch (e) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Annulation impossible',
          message: e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Annulation impossible',
          message: 'Échec de l\'annulation.',
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail vente'),
        actions: [
          if (_sale != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SaleReceiptPage(
                    session: widget.session,
                    sale: _sale!,
                  ),
                ),
              ),
            ),
          const AppHeaderActions(),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text('Chargement de la vente…'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(context, _sale!),
      bottomNavigationBar: _sale == null || _sale!.isCancelled
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_sale!.isCancelled &&
                        _sale!.saleType == SaleType.standard &&
                        _sale!.items.isNotEmpty &&
                        _canReplace)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _cancelling ? null : _openReplacement,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Remplacer'),
                          ),
                        ),
                      ),
                    if (!_sale!.isCancelled &&
                        _sale!.saleType == SaleType.quick &&
                        _sale!.items.isEmpty &&
                        _canConvert)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _cancelling
                                ? null
                                : () => _openConversion(_sale!),
                            icon: const Icon(Icons.transform_outlined),
                            label: const Text('Convertir en vente standard'),
                          ),
                        ),
                      ),
                    if (!_sale!.isCancelled && _canCancel)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _cancelling ? null : _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                          child: _cancelling
                              ? SaleFeedback.inlineLoader()
                              : const Text('Annuler la vente'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _openReplacement() async {
    final sale = _sale;
    if (sale == null) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SaleReplacementPage(
          session: widget.session,
          sale: sale,
        ),
      ),
    );
    if (done == true && mounted) await _refreshSale();
  }

  Future<void> _openConversion(Sale sale) async {
    final confirmed = await SaleFeedback.confirm(
      context: context,
      title: 'Convertir en vente standard',
      message:
          'Répartir ${formatFcfa(sale.totalAmount)} en produits '
          'pour la vente ${sale.receiptNumber ?? '#${sale.id}'} ?',
    );
    if (confirmed != true || !mounted) return;

    final converted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewSalePage(
          session: widget.session,
          conversion: QuickSaleConversion(
            saleId: sale.id,
            targetTotal: sale.totalAmount,
            receiptLabel: sale.receiptNumber,
          ),
        ),
      ),
    );
    if (converted == true && mounted) {
      await _refreshSale();
      if (!mounted) return;
      await SaleFeedback.showSuccess(
        context: context,
        title: 'Conversion réussie',
        message: 'La vente rapide a été convertie en vente standard.',
      );
    }
  }

  Widget _buildContent(BuildContext context, Sale sale) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
    final date = AppDateFormatter.formatDateTime(dt);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ListTile(
          title: Text(sale.receiptNumber?.replaceAll('/', '') ?? 'Vente #${sale.id}'),
          subtitle: Text(date),
          trailing: Text(
            formatFcfa(sale.totalAmount),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (sale.isCancelled)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              title: const Text('Vente annulée'),
              subtitle: Text(sale.cancelReason ?? ''),
            ),
          ),
        if (sale.saleType == SaleType.quick && sale.items.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.flash_on_outlined),
              title: const Text('Vente rapide'),
              subtitle: const Text(
                'Montant enregistré sans détail produit ni impact stock.',
              ),
            ),
          ),
        const Divider(),
        ...sale.items.map(
          (item) => ListTile(
            title: Text(item.productName),
            subtitle: Text('${item.quantity} × ${formatFcfa(item.unitPrice)}'),
            trailing: Text(formatFcfa(item.lineTotal)),
          ),
        ),
        if (_replacements.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Remplacements',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Divider(),
          ..._replacements.map((rx) {
            final dt = DateTime.fromMillisecondsSinceEpoch(rx.replacedAt);
            final date =
                '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year}';
            final summary = rx.items
                .map(
                  (i) =>
                      '${i.returnedProductName ?? 'Produit'} ×${i.quantityReturned}'
                      ' → ${i.issuedProductName ?? 'Produit'} ×${i.quantityIssued}',
                )
                .join('\n');
            return ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(rx.number),
              subtitle: Text('$date\n$summary'),
              isThreeLine: true,
            );
          }),
        ],
      ],
    );
  }
}
