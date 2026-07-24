import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../voice_input/domain/entities/voice_navigation_seeds.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../widgets/sale_feedback.dart';

class SaleReplacementPage extends StatefulWidget {
  const SaleReplacementPage({
    super.key,
    required this.session,
    required this.sale,
    this.voiceSeed,
  });

  final AuthSession session;
  final Sale sale;
  final VoiceSaleReplacementSeed? voiceSeed;

  @override
  State<SaleReplacementPage> createState() => _SaleReplacementPageState();
}

class _LineDraft {
  _LineDraft({
    required this.saleItem,
    required this.returnable,
    required this.returnedCtrl,
    required this.issuedCtrl,
    required this.issuedProductId,
    required this.issuedProductName,
    required this.unitPriceIssued,
  });

  final SaleItem saleItem;
  final int returnable;
  final TextEditingController returnedCtrl;
  final TextEditingController issuedCtrl;
  int issuedProductId;
  String issuedProductName;
  int unitPriceIssued;
  SaleReplacementReason? reason;
  bool selected = false;
}

class _SaleReplacementPageState extends State<SaleReplacementPage> {
  final _notesCtrl = TextEditingController();
  final List<_LineDraft> _lines = [];
  List<dynamic> _products = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final returned = await sl<GetSaleReturnedQuantities>()(
        session: widget.session,
        saleId: widget.sale.id,
      );
      final shopId = widget.session.shop.id;
      final productRows = await sl<InventoryLocalDatasource>().listProductRows(
        shopId: shopId,
        filters: const ProductListFilters(),
      );
      if (!mounted) return;

      setState(() {
        _products = productRows.map((r) => r.product).toList();
        for (final item in widget.sale.items) {
          if (item.productId == null) continue;
          final already = returned[item.id] ?? 0;
          final returnable = saleItemQuantityReturnable(
            soldQuantity: item.quantity,
            alreadyReturned: already,
          );
          if (returnable <= 0) continue;
          _lines.add(
            _LineDraft(
              saleItem: item,
              returnable: returnable,
              returnedCtrl: TextEditingController(text: '$returnable'),
              issuedCtrl: TextEditingController(text: '$returnable'),
              issuedProductId: item.productId!,
              issuedProductName: item.productName,
              unitPriceIssued: item.unitPrice,
            ),
          );
        }
        _applyVoiceSeed();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de préparer le remplacement.';
        });
      }
    }
  }

  void _applyVoiceSeed() {
    final seed = widget.voiceSeed;
    if (seed == null || !seed.hasAny || _lines.isEmpty) return;

    _LineDraft? target;
    if (seed.returnedProductId != null) {
      for (final line in _lines) {
        if (line.saleItem.productId == seed.returnedProductId) {
          target = line;
          break;
        }
      }
    }
    target ??= _lines.first;

    for (final line in _lines) {
      line.selected = identical(line, target);
    }

    final qty = seed.quantity;
    if (qty != null && qty > 0) {
      final capped = qty > target.returnable ? target.returnable : qty;
      target.returnedCtrl.text = '$capped';
      target.issuedCtrl.text = '$capped';
    }

    if (seed.issuedProductId != null) {
      target.issuedProductId = seed.issuedProductId!;
      target.issuedProductName =
          seed.issuedProductName ?? target.issuedProductName;
      for (final p in _products) {
        if (p is Product && p.id == seed.issuedProductId) {
          target.issuedProductName = p.name;
          target.unitPriceIssued = p.priceSell;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final line in _lines) {
      line.returnedCtrl.dispose();
      line.issuedCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remplacer des produits')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _lines.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Aucun produit retournable sur cette vente.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        Text(
                          'Vente ${widget.sale.receiptNumber ?? '#${widget.sale.id}'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Retournez un produit et choisissez celui qui sort '
                          'du stock. Aucun mouvement de caisse.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._lines.map(_buildLineCard),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optionnel)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? SaleFeedback.inlineLoader()
                                : const Icon(Icons.swap_horiz),
                            label: const Text('Valider le remplacement'),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildLineCard(_LineDraft line) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: line.selected,
              title: Text(
                line.saleItem.productName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Vendu ${line.saleItem.quantity} · '
                'Retournable ${line.returnable} · '
                '${formatFcfa(line.saleItem.unitPrice)}/u',
              ),
              onChanged: (v) => setState(() {
                line.selected = v ?? false;
                if (line.selected && line.reason == null) {
                  line.reason = SaleReplacementReason.quality;
                }
              }),
            ),
            if (line.selected) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: line.returnedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Qté retournée',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: line.issuedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Qté émise',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                value: line.issuedProductId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Produit de remplacement',
                  border: OutlineInputBorder(),
                ),
                items: _products.map((p) {
                  return DropdownMenuItem<int>(
                    value: p.id as int,
                    child: Text('${p.name} (stock ${p.quantityInStock})'),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final product = _products.firstWhere((p) => p.id == id);
                  setState(() {
                    line.issuedProductId = id;
                    line.issuedProductName = product.name as String;
                    line.unitPriceIssued = product.priceSell as int;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<SaleReplacementReason>(
                value: line.reason,
                decoration: const InputDecoration(
                  labelText: 'Motif *',
                  border: OutlineInputBorder(),
                ),
                items: SaleReplacementReason.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.labelFr),
                      ),
                    )
                    .toList(),
                onChanged: (r) => setState(() => line.reason = r),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final selected = _lines.where((l) => l.selected).toList();
    if (selected.isEmpty) {
      SaleFeedback.showErrorMessage(
        context,
        'Cochez au moins une ligne à remplacer.',
      );
      return;
    }

    final inputs = <SaleReplacementLineInput>[];
    var returnedValue = 0;
    var issuedValue = 0;

    for (final line in selected) {
      final returned = int.tryParse(line.returnedCtrl.text.trim()) ?? 0;
      final issued = int.tryParse(line.issuedCtrl.text.trim()) ?? 0;
      if (returned <= 0 || issued <= 0) {
        SaleFeedback.showErrorMessage(
          context,
          'Quantités invalides pour ${line.saleItem.productName}.',
        );
        return;
      }
      if (returned > line.returnable) {
        SaleFeedback.showErrorMessage(
          context,
          'Retour trop élevé pour ${line.saleItem.productName} '
          '(max ${line.returnable}).',
        );
        return;
      }
      if (line.reason == null) {
        SaleFeedback.showErrorMessage(
          context,
          'Motif requis pour ${line.saleItem.productName}.',
        );
        return;
      }

      returnedValue += returned * line.saleItem.unitPrice;
      issuedValue += issued * line.unitPriceIssued;

      inputs.add(
        SaleReplacementLineInput(
          returnedSaleItemId: line.saleItem.id,
          quantityReturned: returned,
          issuedProductId: line.issuedProductId,
          quantityIssued: issued,
          unitPriceIssued: line.unitPriceIssued,
          reason: line.reason!,
        ),
      );
    }

    final delta = issuedValue - returnedValue;
    final deltaLabel = delta == 0
        ? 'Écart de prix : 0 FCFA'
        : delta > 0
            ? 'Écart : client devrait +${formatFcfa(delta)} (non réglé ici)'
            : 'Écart : boutique devrait ${formatFcfa(-delta)} (non réglé ici)';

    final confirmed = await SaleFeedback.confirm(
      context: context,
      title: 'Confirmer le remplacement ?',
      message:
          '${inputs.length} ligne(s).\n'
          'Retour en stock + sortie FIFO.\n'
          '$deltaLabel\n'
          'Aucun mouvement de caisse.',
      confirmLabel: 'Confirmer',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final rx = await sl<CreateSaleReplacement>()(
        session: widget.session,
        input: CreateSaleReplacementInput(
          saleId: widget.sale.id,
          items: inputs,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      await SaleFeedback.showSuccess(
        context: context,
        title: 'Remplacement enregistré',
        message: '${rx.number} — stock mis à jour.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Remplacement impossible',
          message: e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Remplacement impossible',
          message: 'Une erreur est survenue.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
