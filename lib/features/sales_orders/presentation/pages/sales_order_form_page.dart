import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/domain/entities/customer_entities.dart';
import '../../../customers/domain/usecases/customer_usecases.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../inventory/domain/usecases/inventory_usecases.dart';
import '../../domain/entities/sales_order.dart';
import '../bloc/sales_order_bloc.dart';

class SalesOrderFormPage extends StatefulWidget {
  const SalesOrderFormPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SalesOrderFormPage> createState() => _SalesOrderFormPageState();
}

class _SalesOrderFormPageState extends State<SalesOrderFormPage> {
  final _notesController = TextEditingController();
  List<Customer> _customers = [];
  List<Product> _products = [];
  int? _customerId;
  final List<_LineDraft> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final customers = await sl<ListCustomers>()(
      session: widget.session,
    );
    final products = await sl<ListProducts>()(
      shopId: widget.session.shop.id,
      filters: const ProductListFilters(),
    );
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _products = products.where((p) => !p.isArchived).toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    Product? selected;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ajouter un produit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                decoration: const InputDecoration(labelText: 'Produit'),
                items: _products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (stock ${p.quantityInStock})'),
                      ),
                    )
                    .toList(),
                onChanged: (p) {
                  selected = p;
                  if (p != null) {
                    priceController.text = '${p.priceSell}';
                  }
                  setLocal(() {});
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Prix unitaire'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selected == null) return;
    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
    final price = int.tryParse(priceController.text.trim()) ?? 0;
    if (qty <= 0 || price <= 0) return;
    setState(() {
      _lines.add(
        _LineDraft(
          productId: selected!.id,
          productName: selected!.name,
          quantity: qty,
          unitPrice: price,
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un client.')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un produit.')),
      );
      return;
    }

    final customerName = _customers
            .where((c) => c.id == _customerId)
            .map((c) => c.name)
            .firstOrNull ??
        'ce client';
    final totalQty = _lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final totalAmount = _lines.fold<int>(
      0,
      (sum, l) => sum + (l.quantity * l.unitPrice),
    );

    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Enregistrer la commande ?',
      message:
          'Créer un brouillon pour $customerName : '
          '${_lines.length} ligne(s), $totalQty article(s), '
          '${formatFcfa(totalAmount)}.\n\n'
          'Aucune sortie de stock pour l’instant. '
          'Vous pourrez confirmer la commande ensuite.',
      confirmLabel: 'Enregistrer',
    );
    if (confirmed != true || !mounted) return;

    context.read<SalesOrderBloc>().add(
          SalesOrderCreateRequested(
            customerId: _customerId!,
            items: _lines
                .map(
                  (l) => SalesOrderLineInput(
                    productId: l.productId,
                    quantityOrdered: l.quantity,
                    unitPrice: l.unitPrice,
                  ),
                )
                .toList(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesOrderBloc, SalesOrderState>(
      listenWhen: (p, c) =>
          p.successMessage != c.successMessage ||
          p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.successMessage != null && state.selected != null) {
          Navigator.of(context).pop(true);
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context
              .read<SalesOrderBloc>()
              .add(const SalesOrderFeedbackCleared());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nouvelle commande')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  DropdownButtonFormField<int>(
                    value: _customerId,
                    decoration: const InputDecoration(
                      labelText: 'Client *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: _customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _customerId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Text(
                        'Lignes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add),
                        label: const Text('Produit'),
                      ),
                    ],
                  ),
                  if (_lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text('Aucun produit — la commande peut dépasser le stock actuel.'),
                    ),
                  ..._lines.asMap().entries.map((e) {
                    final i = e.key;
                    final line = e.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.productName),
                      subtitle: Text(
                        '${line.quantity} × ${formatFcfa(line.unitPrice)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            setState(() => _lines.removeAt(i)),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.lg),
                  BlocBuilder<SalesOrderBloc, SalesOrderState>(
                    builder: (context, state) {
                      return FilledButton(
                        onPressed: state.saving ? null : _submit,
                        child: state.saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Enregistrer le brouillon'),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _LineDraft {
  _LineDraft({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final String productName;
  final int quantity;
  final int unitPrice;
}
