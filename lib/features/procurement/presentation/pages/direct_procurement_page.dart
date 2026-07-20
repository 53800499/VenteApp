import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../inventory/data/datasources/local/inventory_lot_local_datasource.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/repositories/procurement_repository.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';
import '../widgets/procurement_sync_progress_sheet.dart';
import '../utils/procurement_price_update_flow.dart';

class DirectProcurementPage extends StatefulWidget {
  const DirectProcurementPage({super.key});

  @override
  State<DirectProcurementPage> createState() => _DirectProcurementPageState();
}

class _DirectProcurementPageState extends State<DirectProcurementPage> {
  final _formKey = GlobalKey<FormState>();
  final _receiptNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _paymentReferenceController = TextEditingController();

  int? _selectedSupplierId;
  final List<Map<String, dynamic>> _items = [];
  List<dynamic> _allProducts = [];
  bool _loadingProducts = true;
  bool _submitPending = false;
  bool _recordInvoice = true;
  bool _payNow = true;
  PurchasePaymentMethod _paymentMethod = PurchasePaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initReceiptNumber();
      _loadProducts();
    });
  }

  Future<void> _initReceiptNumber() async {
    final shopId = context.read<ProcurementBloc>().shopId;
    final repo = sl<ProcurementRepository>();
    final number = await repo.nextDirectReceiptNumber(shopId: shopId);
    if (mounted) {
      _receiptNumberController.text = number;
      _invoiceNumberController.text = 'FAC-$number';
    }
  }

  Future<void> _loadProducts() async {
    try {
      final localInventory = sl<InventoryLocalDatasource>();
      if (!mounted) return;
      final shopId = context.read<ProcurementBloc>().shopId;
      final list = await localInventory.listProductRows(
        shopId: shopId,
        filters: const ProductListFilters(),
      );
      if (!mounted) return;
      setState(() {
        _allProducts = list.map((r) => r.product).toList();
        _loadingProducts = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  int get _subtotal => _items.fold<int>(
        0,
        (sum, it) => sum + (it['subtotal'] as int),
      );

  @override
  void dispose() {
    _receiptNumberController.dispose();
    _notesController.dispose();
    _invoiceNumberController.dispose();
    _paymentReferenceController.dispose();
    super.dispose();
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
            title: 'Approvisionnement impossible',
            message: state.errorMessage!,
          );
          return;
        }

        if (state.status == ProcurementStatus.loaded) {
          _submitPending = false;
          if (!context.mounted) return;
          final shopId = context.read<ProcurementBloc>().shopId;
          final receiptNumber = _receiptNumberController.text.trim();
          final withInvoice = _recordInvoice;
          final withPayment = _payNow && withInvoice;
          Navigator.pop(context);
          if (context.mounted) {
            await ProcurementSyncProgressSheet.show(
              context,
              shopId: shopId,
              receiptNumber: receiptNumber,
              invoiceExpected: withInvoice,
              paymentExpected: withPayment,
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Approvisionnement direct'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Réception sans commande fournisseur',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Les articles seront ajoutés au stock via le moteur de lots FIFO.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              BlocBuilder<ProcurementBloc, ProcurementState>(
                builder: (context, state) {
                  return DropdownButtonFormField<int>(
                    value: _selectedSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'Fournisseur *',
                      border: OutlineInputBorder(),
                    ),
                    items: state.suppliers
                        .where((s) => s.isActive)
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedSupplierId = val),
                    validator: (val) =>
                        val == null ? 'Sélectionnez un fournisseur' : null,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _receiptNumberController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de bon de réception *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatoire' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Articles',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _loadingProducts ? null : _showAddItemDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Aucun article. Ajoutez au moins un produit.'),
                )
              else
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final product = item['product'];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      title: Text(product.name as String),
                      subtitle: Text(
                        '${item['quantityReceived']} u · achat ${formatFcfa(item['unitCost'] as int)}/u',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatFcfa(item['subtotal'] as int),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () =>
                                setState(() => _items.removeAt(idx)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const Divider(height: 32),
              Text(
                'Facturation & paiement',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Créer une facture fournisseur'),
                value: _recordInvoice,
                onChanged: (v) => setState(() => _recordInvoice = v),
              ),
              if (_recordInvoice) ...[
                TextFormField(
                  controller: _invoiceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de facture',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Payer maintenant (${formatFcfa(_subtotal)})'),
                  value: _payNow,
                  onChanged: (v) => setState(() => _payNow = v),
                ),
                if (!_payNow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'La facture sera créée en attente de paiement. '
                      'Vous pourrez payer plus tard depuis l\'onglet « Appro direct ».',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                if (_payNow) ...[
                  DropdownButtonFormField<PurchasePaymentMethod>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Mode de paiement',
                      border: OutlineInputBorder(),
                    ),
                    items: PurchasePaymentMethod.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _paymentMethod = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _paymentReferenceController,
                    decoration: const InputDecoration(
                      labelText: 'Référence paiement (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarques',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        formatFcfa(_subtotal),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.controlHeight),
                  ),
                  onPressed: _submitPending ? null : _submit,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Enregistrer l\'approvisionnement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    dynamic selectedProduct;
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController();
    final batchController = TextEditingController();
    int? expiryMs;

    showDialog(
      context: context,
      builder: (diagContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Ajouter un article'),
          content: SingleChildScrollView(
            child: Column(
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
                    labelText: 'Quantité *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: costController,
                  decoration: const InputDecoration(
                    labelText: 'Prix d\'achat unitaire (FCFA) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: batchController,
                  decoration: const InputDecoration(
                    labelText: 'N° de lot (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setStateDialog(() {
                        expiryMs = picked.millisecondsSinceEpoch;
                      });
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    expiryMs == null
                        ? 'Date d\'expiration (optionnel)'
                        : DateTime.fromMillisecondsSinceEpoch(expiryMs!)
                            .toLocal()
                            .toString()
                            .substring(0, 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(diagContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedProduct == null) return;
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                final cost = int.tryParse(costController.text.trim()) ?? 0;
                if (qty <= 0) return;

                setState(() {
                  _items.add({
                    'product': selectedProduct,
                    'productId': selectedProduct.id,
                    'quantityReceived': qty,
                    'unitCost': cost,
                    'subtotal': qty * cost,
                    'batchNumber': batchController.text.trim().isEmpty
                        ? null
                        : batchController.text.trim(),
                    'expiryDate': expiryMs,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ProcurementFeedback.showErrorMessage(
        context,
        'Veuillez ajouter au moins un produit.',
      );
      return;
    }

    final supplierName = context
        .read<ProcurementBloc>()
        .state
        .suppliers
        .where((s) => s.id == _selectedSupplierId)
        .map((s) => s.name)
        .firstOrNull;

    final receiptItems = _items
        .map(
          (it) => {
            'productId': it['productId'] as int,
            'quantityReceived': it['quantityReceived'] as int,
            'unitCost': it['unitCost'] as int,
            'batchNumber': it['batchNumber'] as String?,
            'expiryDate': it['expiryDate'] as int?,
          },
        )
        .toList();

    final totalQty = receiptItems.fold<int>(
      0,
      (sum, it) => sum + (it['quantityReceived'] as int),
    );

    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: 'Confirmer l\'approvisionnement ?',
      message:
          'Enregistrer le bon « ${_receiptNumberController.text.trim()} » '
          'chez ${supplierName ?? 'le fournisseur'} ?\n\n'
          '$totalQty unité(s) seront ajoutées au stock.',
      confirmLabel: 'Confirmer',
    );
    if (confirmed != true || !mounted) return;

    final shopId = context.read<ProcurementBloc>().shopId;
    final priceFlowOk = await ProcurementPriceUpdateFlow().run(
      context: context,
      shopId: shopId,
      lines: receiptItems
          .map(
            (it) {
              final product = _items.firstWhere(
                (row) => row['productId'] == it['productId'],
                orElse: () => const {},
              )['product'];
              return ProcurementReceiptLineInput(
                productId: it['productId'] as int,
                unitCost: it['unitCost'] as int,
                quantityReceived: it['quantityReceived'] as int,
                productName: product?.name as String?,
              );
            },
          )
          .toList(),
    );
    if (!priceFlowOk || !mounted) return;

    setState(() => _submitPending = true);
    context.read<ProcurementBloc>().add(
          ProcurementDirectProcurementSubmitted(
            supplierId: _selectedSupplierId!,
            receiptNumber: _receiptNumberController.text.trim(),
            receivedAt: DateTime.now().millisecondsSinceEpoch,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: receiptItems,
            recordSupplierInvoice: _recordInvoice,
            invoiceNumber: _recordInvoice
                ? _invoiceNumberController.text.trim()
                : null,
            paymentAmount: _recordInvoice && _payNow ? _subtotal : null,
            paymentMethod: _paymentMethod,
            paymentReference: _paymentReferenceController.text.trim().isEmpty
                ? null
                : _paymentReferenceController.text.trim(),
          ),
        );
  }
}
