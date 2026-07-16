import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/domain/entities/product_pricing_entities.dart';
import '../../../inventory/domain/services/product_pricing_service.dart';

/// Dialogue affiché lorsqu'un coût d'achat diffère du dernier connu.
class ProcurementPriceUpdateDialog extends StatefulWidget {
  const ProcurementPriceUpdateDialog({
    super.key,
    required this.change,
    required this.pricingService,
  });

  final ProcurementCostChange change;
  final ProductPricingService pricingService;

  static Future<ProcurementPriceDecision?> show(
    BuildContext context, {
    required ProcurementCostChange change,
    ProductPricingService? pricingService,
  }) {
    return showDialog<ProcurementPriceDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProcurementPriceUpdateDialog(
        change: change,
        pricingService: pricingService ?? const ProductPricingService(),
      ),
    );
  }

  @override
  State<ProcurementPriceUpdateDialog> createState() =>
      _ProcurementPriceUpdateDialogState();
}

class _ProcurementPriceUpdateDialogState
    extends State<ProcurementPriceUpdateDialog> {
  late ProcurementPriceDecisionType _selected;
  late final TextEditingController _priceController;
  int? _suggestedPrice;

  @override
  void initState() {
    super.initState();
    _suggestedPrice = widget.pricingService.calculateSuggestedSalePrice(
      unitCost: widget.change.newUnitCost,
      mode: widget.change.pricingMode,
      marginValue: widget.change.marginValue,
    );
    _selected = _suggestedPrice != null
        ? ProcurementPriceDecisionType.applySuggested
        : ProcurementPriceDecisionType.keepCurrent;
    _priceController = TextEditingController(
      text: '${_suggestedPrice ?? widget.change.currentPriceSell}',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final change = widget.change;
    final pct = change.costChangePercent;
    final pctLabel = pct != null
        ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %'
        : 'nouveau prix d\'achat';

    return AlertDialog(
      title: Text('Prix d\'achat modifié — ${change.productName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Le prix d\'achat a changé ($pctLabel). '
              'Souhaitez-vous ajuster le prix de vente ?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _CostRow(
              label: 'Ancien prix d\'achat',
              value: formatFcfa(change.previousUnitCost),
            ),
            _CostRow(
              label: 'Nouveau prix d\'achat',
              value: formatFcfa(change.newUnitCost),
            ),
            _CostRow(
              label: 'Prix de vente actuel',
              value: formatFcfa(change.currentPriceSell),
            ),
            if (_suggestedPrice != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _CostRow(
                label: 'Prix de vente conseillé',
                value: formatFcfa(_suggestedPrice!),
                emphasized: true,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            RadioListTile<ProcurementPriceDecisionType>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Conserver le prix de vente actuel'),
              value: ProcurementPriceDecisionType.keepCurrent,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            if (_suggestedPrice != null)
              RadioListTile<ProcurementPriceDecisionType>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Appliquer le prix conseillé (${formatFcfa(_suggestedPrice!)})',
                ),
                value: ProcurementPriceDecisionType.applySuggested,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v!),
              ),
            RadioListTile<ProcurementPriceDecisionType>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Saisir un nouveau prix de vente'),
              value: ProcurementPriceDecisionType.updateManual,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
            if (_selected == ProcurementPriceDecisionType.updateManual) ...[
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Nouveau prix de vente (FCFA)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
            RadioListTile<ProcurementPriceDecisionType>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Décider plus tard'),
              value: ProcurementPriceDecisionType.decideLater,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Valider'),
        ),
      ],
    );
  }

  void _submit() {
    int? newPrice;
    switch (_selected) {
      case ProcurementPriceDecisionType.keepCurrent:
      case ProcurementPriceDecisionType.decideLater:
        break;
      case ProcurementPriceDecisionType.applySuggested:
        newPrice = _suggestedPrice;
        break;
      case ProcurementPriceDecisionType.updateManual:
        newPrice = int.tryParse(_priceController.text.trim());
        if (newPrice == null || newPrice <= 0) return;
        break;
    }

    Navigator.pop(
      context,
      ProcurementPriceDecision(
        productId: widget.change.productId,
        type: _selected,
        newPriceSell: newPrice,
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
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
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
