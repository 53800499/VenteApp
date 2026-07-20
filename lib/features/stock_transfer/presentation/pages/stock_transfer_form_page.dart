import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../shop/domain/repositories/shop_repository.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/stock_transfer_repository.dart';
import '../bloc/stock_transfer_bloc.dart';

class StockTransferFormPage extends StatefulWidget {
  const StockTransferFormPage({super.key});

  @override
  State<StockTransferFormPage> createState() => _StockTransferFormPageState();
}

class _StockTransferFormPageState extends State<StockTransferFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  int? _destinationShopId;
  List<ShopOption> _destinationShops = const [];
  final List<Map<String, dynamic>> _items = [];
  List<dynamic> _allProducts = [];
  bool _loadingProducts = true;
  bool _loadingDestinations = true;
  bool _submitPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    _initReference();
    _loadProducts();
    try {
      await sl<ShopRepository>().listShops();
    } catch (_) {
      // Hors ligne : boutiques déjà en cache local.
    }
    if (!mounted) return;
    final shopId = context.read<StockTransferBloc>().shopId;
    final shops = await sl<StockTransferRepository>().listDestinationShops(
      currentShopId: shopId,
    );
    if (!mounted) return;
    setState(() {
      _destinationShops = shops;
      _loadingDestinations = false;
    });
    context
        .read<StockTransferBloc>()
        .add(const StockTransferDestinationsLoadRequested());
  }

  Future<void> _initReference() async {
    final shopId = context.read<StockTransferBloc>().shopId;
    final ref = await sl<StockTransferRepository>().nextReference(shopId: shopId);
    if (mounted) _referenceController.text = ref;
  }

  Future<void> _loadProducts() async {
    try {
      final local = sl<InventoryLocalDatasource>();
      final shopId = context.read<StockTransferBloc>().shopId;
      final rows = await local.listProductRows(
        shopId: shopId,
        filters: const ProductListFilters(),
      );
      if (!mounted) return;
      setState(() {
        _allProducts = rows.map((r) => r.product).where((p) => !p.isArchived).toList();
        _loadingProducts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StockTransferBloc, StockTransferState>(
      listenWhen: (prev, curr) => _submitPending && prev.status != curr.status,
      listener: (context, state) async {
        if (!_submitPending) return;
        if (state.status == StockTransferBlocStatus.failure) {
          _submitPending = false;
          if (state.errorMessage != null) {
            await showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Transfert impossible'),
                content: Text(state.errorMessage!),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
        if (state.status == StockTransferBlocStatus.loaded && state.selectedTransfer != null) {
          _submitPending = false;
          if (!context.mounted) return;
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nouveau transfert')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Transfert vers une autre boutique',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Le stock sera déduit en FIFO à l\'expédition. '
                'Les lots destination conserveront le même prix d\'achat.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Builder(
                builder: (context) {
                  final destinations = _destinationShops;
                  final canSelect =
                      !_loadingDestinations && destinations.isNotEmpty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          'dest-${destinations.length}-$_loadingDestinations',
                        ),
                        initialValue: _destinationShopId,
                        decoration: InputDecoration(
                          labelText: 'Boutique destination *',
                          border: const OutlineInputBorder(),
                          suffixIcon: _loadingDestinations
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        hint: const Text('Sélectionnez une boutique'),
                        items: destinations
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  s.address != null && s.address!.trim().isNotEmpty
                                      ? '${s.displayLabel} · ${s.address!.trim()}'
                                      : s.displayLabel,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: canSelect
                            ? (v) => setState(() => _destinationShopId = v)
                            : null,
                        validator: (v) =>
                            v == null ? 'Sélectionnez une boutique' : null,
                      ),
                      if (!_loadingDestinations && destinations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'Aucune autre boutique disponible dans votre réseau. '
                            'Créez ou synchronisez vos boutiques depuis Paramètres.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Référence *',
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
                  child: Text('Ajoutez au moins un produit.'),
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
                      subtitle: Text('${item['quantityRequested']} unité(s)'),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => setState(() => _items.removeAt(idx)),
                      ),
                    ),
                  );
                }),
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
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer le brouillon'),
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

    showDialog<void>(
      context: context,
      builder: (diagContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un produit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<dynamic>(
                isExpanded: true,
                initialValue: selectedProduct,
                hint: const Text('Produit'),
                decoration: const InputDecoration(
                  labelText: 'Produit *',
                  border: OutlineInputBorder(),
                ),
                items: _allProducts.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} (${p.quantityInStock} en stock)'),
                  );
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedProduct = v),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedProduct == null) return;
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) return;
                setState(() {
                  _items.add({
                    'productId': selectedProduct.id as int,
                    'product': selectedProduct,
                    'quantityRequested': qty,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un produit.')),
      );
      return;
    }
    if (_destinationShopId == null) return;

    setState(() => _submitPending = true);
    context.read<StockTransferBloc>().add(
          StockTransferCreateSubmitted(
            destinationShopId: _destinationShopId!,
            reference: _referenceController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: _items
                .map(
                  (it) => {
                    'productId': it['productId'],
                    'quantityRequested': it['quantityRequested'],
                  },
                )
                .toList(),
          ),
        );
  }
}
