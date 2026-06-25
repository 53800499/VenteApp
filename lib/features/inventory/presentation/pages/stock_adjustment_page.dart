import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/usecases/inventory_usecases.dart';

class StockAdjustmentPage extends StatefulWidget {
  const StockAdjustmentPage({
    super.key,
    required this.session,
    required this.product,
  });

  final AuthSession session;
  final Product product;

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  StockAdjustmentType _type = StockAdjustmentType.restock;
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _unitCostController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  int _signedQuantity(int raw) {
    return switch (_type) {
      StockAdjustmentType.restock => raw.abs(),
      StockAdjustmentType.loss => -raw.abs(),
      StockAdjustmentType.adjustment => raw,
    };
  }

  Future<void> _submit() async {
    final raw = int.tryParse(_quantityController.text.trim());
    if (raw == null || raw == 0) {
      setState(() => _errorMessage = 'Indiquez une quantité non nulle.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await sl<AdjustProductStock>()(
        shopId: widget.session.shop.id,
        userId: widget.session.user.id,
        productId: widget.product.id,
        input: AdjustStockInput(
          type: _type,
          quantityChange: _signedQuantity(raw),
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
          unitCost: _unitCostController.text.trim().isEmpty
              ? null
              : int.tryParse(_unitCostController.text.trim()),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Ajustement impossible.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsReason =
        _type == StockAdjustmentType.adjustment || _type == StockAdjustmentType.loss;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajuster le stock')),
      body: SafeArea(
        child: ResponsiveFormPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.product.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Stock actuel : ${widget.product.quantityInStock}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<StockAdjustmentType>(
                segments: const [
                  ButtonSegment(
                    value: StockAdjustmentType.restock,
                    label: Text('Entrée'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: StockAdjustmentType.loss,
                    label: Text('Perte'),
                    icon: Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: StockAdjustmentType.adjustment,
                    label: Text('Correction'),
                    icon: Icon(Icons.tune),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (value) {
                  setState(() => _type = value.first);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: _type == StockAdjustmentType.adjustment
                      ? 'Quantité (+ ou -)'
                      : 'Quantité',
                  prefixIcon: const Icon(Icons.numbers),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                inputFormatters: _type == StockAdjustmentType.adjustment
                    ? [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ]
                    : [FilteringTextInputFormatter.digitsOnly],
              ),
              if (_type == StockAdjustmentType.restock) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _unitCostController,
                  decoration: const InputDecoration(
                    labelText: 'Coût unitaire (optionnel)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
              if (needsReason) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motif (obligatoire)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Valider l\'ajustement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
