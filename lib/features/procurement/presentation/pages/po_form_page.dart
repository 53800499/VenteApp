import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/repositories/procurement_repository.dart';
import '../bloc/procurement_bloc.dart';
import '../models/po_form_prefill.dart';
import '../widgets/procurement_feedback.dart';
import '../utils/procurement_price_update_flow.dart';

class PoFormPage extends StatefulWidget {
  const PoFormPage({
    super.key,
    this.orderToEdit,
    this.prefill,
  });

  final PurchaseOrder? orderToEdit;
  final PoFormPrefill? prefill;

  @override
  State<PoFormPage> createState() => _PoFormPageState();
}

class _PoFormPageState extends State<PoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');

  int? _selectedSupplierId;
  final List<Map<String, dynamic>> _selectedItems = []; // {product: ..., quantityOrdered: int, unitCost: int, subtotal: int}

  List<dynamic> _allProducts = []; // List of Drift Product rows
  bool _loadingProducts = true;
  bool _submitPending = false;
  int? _expectedAtMs;

  bool get _isEditMode => widget.orderToEdit != null;

  @override
  void initState() {
    super.initState();
    final order = widget.orderToEdit;
    if (order != null) {
      _numberController.text = order.number;
      _selectedSupplierId = order.supplierId;
      _discountController.text = '${order.discount}';
      _taxController.text = '${order.tax}';
      _notesController.text = order.notes ?? '';
      _expectedAtMs = order.expectedAt;
    } else {
      _expectedAtMs =
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
      if (!_isEditMode) _loadNextPoNumber();
    });
  }

  Future<void> _loadNextPoNumber() async {
    final shopId = context.read<ProcurementBloc>().shopId;
    final number =
        await sl<ProcurementRepository>().nextPurchaseOrderNumber(shopId: shopId);
    if (mounted) {
      setState(() => _numberController.text = number);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final localInventory = sl<InventoryLocalDatasource>();
      if (!mounted) return;
      final shopId = context.read<ProcurementBloc>().shopId;
      // Fetch products using local cast
      final list = await localInventory.listProductRows(
        shopId: shopId,
        filters: const ProductListFilters(), // Default empty filters
      );
      if (!mounted) return;
      setState(() {
        _allProducts = list.map((r) => r.product).toList();
        _loadingProducts = false;
        _hydrateItemsFromContext();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingProducts = false;
        });
      }
    }
  }

  void _hydrateItemsFromContext() {
    if (_selectedItems.isNotEmpty) return;

    final order = widget.orderToEdit;
    if (order?.items != null && order!.items!.isNotEmpty) {
      for (final it in order.items!) {
        dynamic product;
        for (final p in _allProducts) {
          if (p.id == it.productId) {
            product = p;
            break;
          }
        }
        product ??= _StubProduct(id: it.productId, name: it.productName ?? 'Produit #${it.productId}');
        _selectedItems.add({
          'product': product,
          'productId': it.productId,
          'quantityOrdered': it.quantityOrdered,
          'unitCost': it.unitCost,
          'subtotal': it.subtotal,
        });
      }
      return;
    }

    final prefill = widget.prefill;
    if (prefill != null) {
      dynamic product;
      for (final p in _allProducts) {
        if (p.id == prefill.productId) {
          product = p;
          break;
        }
      }
      product ??= _StubProduct(id: prefill.productId, name: prefill.productName);
      final cost = prefill.unitCost ??
          (product is Product ? product.priceBuy : null) ??
          0;
      final qty = prefill.suggestedQuantity;
      _selectedItems.add({
        'product': product,
        'productId': prefill.productId,
        'quantityOrdered': qty,
        'unitCost': cost,
        'subtotal': qty * cost,
      });
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  int get _subtotal {
    return _selectedItems.fold(0, (sum, item) => sum + (item['subtotal'] as int));
  }

  int get _discount {
    return int.tryParse(_discountController.text) ?? 0;
  }

  int get _tax {
    return int.tryParse(_taxController.text) ?? 0;
  }

  int get _total {
    return _subtotal - _discount + _tax;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProcurementBloc, ProcurementState>(
      listenWhen: (prev, curr) => _submitPending && prev.status != curr.status,
      listener: (context, state) async {
        if (!_submitPending) return;

        if (state.status == ProcurementStatus.failure &&
            state.errorMessage != null) {
          _submitPending = false;
          await ProcurementFeedback.showErrorDialog(
            context,
            title: 'Enregistrement impossible',
            message: state.errorMessage!,
          );
          return;
        }

        if (state.status == ProcurementStatus.loaded) {
          _submitPending = false;
          if (!context.mounted) return;
          await ProcurementFeedback.showSuccess(
            context: context,
            title: _isEditMode ? 'Commande modifiée' : 'Commande créée',
            message: _isEditMode
                ? 'Les modifications de « ${_numberController.text.trim()} » ont été enregistrées.'
                : 'La commande « ${_numberController.text.trim()} » a été enregistrée.',
          );
          if (context.mounted) Navigator.pop(context, true);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier la commande' : 'Nouvelle commande'),
      ),
      body: BlocBuilder<ProcurementBloc, ProcurementState>(
        builder: (context, state) {
          final suppliers = state.suppliers;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Section: Informations générales
                Text(
                  'Informations générales',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de commande *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _selectedSupplierId,
                  hint: const Text('Sélectionner un fournisseur'),
                  decoration: const InputDecoration(
                    labelText: 'Fournisseur *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: suppliers.map((s) {
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSupplierId = val;
                    });
                  },
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    _expectedAtMs != null
                        ? 'Livraison prévue : ${DateTime.fromMillisecondsSinceEpoch(_expectedAtMs!).toLocal().toString().substring(0, 10)}'
                        : 'Date de livraison prévue (optionnelle)',
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _expectedAtMs != null
                          ? DateTime.fromMillisecondsSinceEpoch(_expectedAtMs!)
                          : DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _expectedAtMs = date.millisecondsSinceEpoch;
                      });
                    }
                  },
                ),
                if (_expectedAtMs != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _expectedAtMs = null),
                      child: const Text('Retirer la date prévue'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),

                // Section: Articles
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Articles de la commande',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      height: 40,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter'),
                        onPressed: _loadingProducts ? null : _showAddItemDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Items list
                if (_selectedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(
                      child: Text(
                        'Aucun article sélectionné. Cliquez sur le bouton + pour en ajouter.',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._selectedItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final product = item['product'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${item['quantityOrdered']} u · achat ${formatFcfa(item['unitCost'])}/u',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatFcfa(item['subtotal'] as int),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 20),
                              onPressed: () => _confirmRemoveItem(
                                context,
                                index: idx,
                                productName: product.name as String,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const Divider(),
                const SizedBox(height: AppSpacing.md),

                // Section: Financier
                Text(
                  'Récapitulatif financier',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(label: 'Sous-total', value: formatFcfa(_subtotal)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Expanded(child: Text('Remise (FCFA)')),
                            const SizedBox(width: AppSpacing.sm),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _discountController,
                                decoration: const InputDecoration(
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Expanded(child: Text('Taxes (FCFA)')),
                            const SizedBox(width: AppSpacing.sm),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _taxController,
                                decoration: const InputDecoration(
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _SummaryRow(
                          label: 'TOTAL',
                          value: formatFcfa(_total),
                          isBold: true,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarques',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.controlHeight),
                    ),
                    onPressed: _submitPending ? null : _submitForm,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _isEditMode
                          ? 'Enregistrer les modifications'
                          : 'Enregistrer la commande',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  void _showAddItemDialog() {
    dynamic selectedProduct;
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (diagContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Ajouter un article'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<dynamic>(
                isExpanded: true,
                value: selectedProduct,
                hint: const Text('Sélectionner un produit'),
                decoration: const InputDecoration(
                  labelText: 'Produit *',
                  border: OutlineInputBorder(),
                ),
                items: _allProducts.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p.name as String),
                  );
                }).toList(),
                onChanged: (val) async {
                  setStateDialog(() => selectedProduct = val);
                  if (val != null) {
                    final shopId = context.read<ProcurementBloc>().shopId;
                    final lotDs = InventoryLotLocalDatasource(
                      sl<InventoryLocalDatasource>().database,
                    );
                    final ref = await lotDs.getReferenceUnitCost(
                      shopId: shopId,
                      productId: val.id as int,
                    );
                    if (context.mounted) {
                      setStateDialog(() => costController.text = '$ref');
                    }
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: qtyController,
                decoration: const InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: costController,
                decoration: const InputDecoration(
                  labelText: 'Prix d\'achat unitaire (FCFA)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(diagContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () {
                if (selectedProduct == null) return;
                final qty = int.tryParse(qtyController.text) ?? 1;
                final cost = int.tryParse(costController.text) ?? 0;

                setState(() {
                  _selectedItems.add({
                    'product': selectedProduct,
                    'productId': selectedProduct.id,
                    'quantityOrdered': qty,
                    'unitCost': cost,
                    'subtotal': qty * cost,
                  });
                });

                Navigator.pop(diagContext);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveItem(
    BuildContext context, {
    required int index,
    required String productName,
  }) async {
    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: 'Retirer l\'article ?',
      message: 'Retirer « $productName » de cette commande ?',
      confirmLabel: 'Retirer',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _selectedItems.removeAt(index));
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      ProcurementFeedback.showErrorMessage(
        context,
        'Veuillez ajouter au moins un produit à la commande.',
      );
      return;
    }

    final state = context.read<ProcurementBloc>().state;
    String? supplierName;
    for (final s in state.suppliers) {
      if (s.id == _selectedSupplierId) {
        supplierName = s.name;
        break;
      }
    }

    final expectedLabel = _expectedAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(_expectedAtMs!)
            .toLocal()
            .toString()
            .substring(0, 10)
        : 'non définie';

    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: _isEditMode ? 'Enregistrer les modifications ?' : 'Enregistrer la commande ?',
      message: _isEditMode
          ? 'Mettre à jour la commande « ${_numberController.text.trim()} » '
              '(${_selectedItems.length} article(s), ${formatFcfa(_total)}) ?\n\n'
              'Livraison prévue : $expectedLabel.'
          : 'Créer la commande « ${_numberController.text.trim()} » '
              '(${_selectedItems.length} article(s), ${formatFcfa(_total)}) '
              'pour ${supplierName ?? 'le fournisseur sélectionné'} ?\n\n'
              'Livraison prévue : $expectedLabel.',
      confirmLabel: 'Enregistrer',
    );
    if (confirmed != true || !mounted) return;

    final shopId = context.read<ProcurementBloc>().shopId;
    final priceFlowOk = await ProcurementPriceUpdateFlow().run(
      context: context,
      shopId: shopId,
      lines: _selectedItems
          .map(
            (item) => ProcurementReceiptLineInput(
              productId: item['productId'] as int,
              unitCost: item['unitCost'] as int,
              quantityReceived: item['quantityOrdered'] as int,
              productName: (item['product'] as dynamic).name as String?,
            ),
          )
          .toList(),
    );
    if (!priceFlowOk || !mounted) return;

    final itemsPayload = _selectedItems.map((item) => {
          'productId': item['productId'] as int,
          'quantityOrdered': item['quantityOrdered'] as int,
          'unitCost': item['unitCost'] as int,
          'subtotal': item['subtotal'] as int,
        }).toList();

    final notes = _notesController.text.trim();

    setState(() => _submitPending = true);
    final bloc = context.read<ProcurementBloc>();
    if (_isEditMode) {
      bloc.add(
        ProcurementOrderUpdateSubmitted(
          poId: widget.orderToEdit!.id,
          supplierId: _selectedSupplierId!,
          number: _numberController.text.trim(),
          orderedAt: widget.orderToEdit!.orderedAt,
          expectedAt: _expectedAtMs,
          subtotal: _subtotal,
          discount: _discount,
          tax: _tax,
          total: _total,
          notes: notes.isEmpty ? null : notes,
          items: itemsPayload,
        ),
      );
    } else {
      bloc.add(
        ProcurementOrderCreateSubmitted(
          supplierId: _selectedSupplierId!,
          number: _numberController.text.trim(),
          orderedAt: DateTime.now().millisecondsSinceEpoch,
          expectedAt: _expectedAtMs,
          subtotal: _subtotal,
          discount: _discount,
          tax: _tax,
          total: _total,
          notes: notes.isEmpty ? null : notes,
          items: itemsPayload,
        ),
      );
    }
  }
}

class _StubProduct {
  _StubProduct({required this.id, required this.name});
  final int id;
  final String name;
  int? get priceBuy => null;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.size = 14,
  });

  final String label;
  final String value;
  final bool isBold;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
