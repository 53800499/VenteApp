import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../inventory/data/datasources/local/inventory_local_datasource.dart';
import '../../../inventory/data/mappers/product_mapper.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../sales/domain/entities/sale_entities.dart';
import '../../domain/entities/sales_order.dart';
import '../bloc/sales_order_bloc.dart';

class SalesOrderDeliverPage extends StatefulWidget {
  const SalesOrderDeliverPage({
    super.key,
    required this.session,
    required this.order,
  });

  final AuthSession session;
  final SalesOrder order;

  @override
  State<SalesOrderDeliverPage> createState() => _SalesOrderDeliverPageState();
}

class _SalesOrderDeliverPageState extends State<SalesOrderDeliverPage> {
  late final Map<int, TextEditingController> _accepted;
  late final Map<int, TextEditingController> _refused;
  late final Map<int, TextEditingController> _replaced;
  late final Map<int, TextEditingController> _replacementPrice;
  late final Map<int, SalesOrderRefusalReason?> _reasons;
  late final Map<int, SalesOrderRefusalDestination?> _destinations;
  late final Map<int, int?> _replacementProductIds;
  late final Map<int, String?> _replacementProductNames;
  PaymentMethod _payment = PaymentMethod.cash;
  SalesOrderRemainingReason? _remainingReason;
  final _notesController = TextEditingController();
  final _driverController = TextEditingController();
  final _vehicleController = TextEditingController();
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    _accepted = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0)
          i.id: TextEditingController(text: '${i.quantityRemaining}'),
    };
    _refused = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0) i.id: TextEditingController(text: '0'),
    };
    _replaced = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0) i.id: TextEditingController(text: '0'),
    };
    _replacementPrice = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0)
          i.id: TextEditingController(text: '${i.unitPrice}'),
    };
    _reasons = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0) i.id: null,
    };
    _destinations = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0)
          i.id: SalesOrderRefusalDestination.returnToStock,
    };
    _replacementProductIds = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0) i.id: null,
    };
    _replacementProductNames = {
      for (final i in widget.order.items)
        if (i.quantityRemaining > 0) i.id: null,
    };
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final local = sl<InventoryLocalDatasource>();
    final threshold =
        await local.getDefaultAlertThreshold(widget.session.shop.id);
    final rows = await local.listProductRows(
      shopId: widget.session.shop.id,
      filters: const ProductListFilters(),
    );
    if (!mounted) return;
    setState(() {
      _products = rows
          .map(
            (r) => ProductMapper.fromRow(
              row: r.product,
              effectiveThreshold: threshold,
              categoryName: r.categoryName,
            ),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    for (final c in _accepted.values) {
      c.dispose();
    }
    for (final c in _refused.values) {
      c.dispose();
    }
    for (final c in _replaced.values) {
      c.dispose();
    }
    for (final c in _replacementPrice.values) {
      c.dispose();
    }
    _notesController.dispose();
    _driverController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  int _parse(TextEditingController? c) =>
      int.tryParse(c?.text.trim() ?? '') ?? 0;

  Future<void> _pickReplacement(SalesOrderItem item) async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun produit disponible.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final candidates = _products
            .where((p) => p.id != item.productId && !p.isArchived)
            .toList();
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                const ListTile(title: Text('Produit de remplacement')),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (_, i) {
                      final p = candidates[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          'Stock ${p.quantityInStock} · '
                          '${formatFcfa(p.priceSell)}',
                        ),
                        onTap: () => Navigator.pop(ctx, p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _replacementProductIds[item.id] = selected.id;
      _replacementProductNames[item.id] = selected.name;
      _replacementPrice[item.id]!.text = '${selected.priceSell}';
    });
  }

  Future<void> _submit() async {
    final lines = <DeliveryLineInput>[];
    for (final item in widget.order.items) {
      if (!_accepted.containsKey(item.id)) continue;
      final accepted = _parse(_accepted[item.id]);
      final refused = _parse(_refused[item.id]);
      final replaced = _parse(_replaced[item.id]);
      if (accepted + refused + replaced <= 0) continue;
      lines.add(
        DeliveryLineInput(
          salesOrderItemId: item.id,
          quantitySent: accepted + refused + replaced,
          quantityAccepted: accepted,
          quantityRefused: refused,
          quantityReplaced: replaced,
          refusalReason: refused > 0 ? _reasons[item.id] : null,
          refusalDestination: refused > 0 ? _destinations[item.id] : null,
          replacementProductId:
              replaced > 0 ? _replacementProductIds[item.id] : null,
          replacementUnitPrice: replaced > 0
              ? _parse(_replacementPrice[item.id])
              : null,
        ),
      );
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez au moins une quantité.')),
      );
      return;
    }

    var remainingAfter = 0;
    for (final item in widget.order.items) {
      DeliveryLineInput? line;
      for (final l in lines) {
        if (l.salesOrderItemId == item.id) {
          line = l;
          break;
        }
      }
      final consumed = line == null
          ? 0
          : line.quantityAccepted +
              line.quantityRefused +
              line.quantityReplaced;
      remainingAfter +=
          (item.quantityRemaining - consumed).clamp(0, item.quantityRemaining);
    }
    if (remainingAfter > 0 && _remainingReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indiquez pourquoi un reliquat reste.'),
        ),
      );
      return;
    }

    final acceptedQty =
        lines.fold<int>(0, (s, l) => s + l.quantityAccepted);
    final refusedQty =
        lines.fold<int>(0, (s, l) => s + l.quantityRefused);
    final replacedQty =
        lines.fold<int>(0, (s, l) => s + l.quantityReplaced);
    final saleTotal = lines.fold<int>(0, (s, l) {
      final item =
          widget.order.items.firstWhere((i) => i.id == l.salesOrderItemId);
      final acceptedValue = l.quantityAccepted * item.unitPrice;
      final replacedValue =
          l.quantityReplaced * (l.replacementUnitPrice ?? 0);
      return s + acceptedValue + replacedValue;
    });
    final originalReplacedValue = lines.fold<int>(0, (s, l) {
      final item =
          widget.order.items.firstWhere((i) => i.id == l.salesOrderItemId);
      return s + l.quantityReplaced * item.unitPrice;
    });
    final issuedReplacedValue = lines.fold<int>(
      0,
      (s, l) => s + l.quantityReplaced * (l.replacementUnitPrice ?? 0),
    );
    final priceDiff = issuedReplacedValue - originalReplacedValue;
    final lossQty = lines
        .where(
          (l) =>
              l.quantityRefused > 0 &&
              l.refusalDestination == SalesOrderRefusalDestination.loss,
        )
        .fold<int>(0, (s, l) => s + l.quantityRefused);

    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Valider cette livraison ?',
      message:
          'Commande ${widget.order.number}\n'
          'Accepté : $acceptedQty · Refusé : $refusedQty · Remplacé : $replacedQty\n'
          '${remainingAfter > 0 ? 'Reliquat : $remainingAfter (${_remainingReason!.labelFr})\n' : ''}'
          '${lossQty > 0 ? 'Perte inventaire : $lossQty\n' : ''}'
          'Montant vente : ${formatFcfa(saleTotal)} (${_payment.label})\n'
          '${replacedQty > 0 ? 'Écart remplacement : ${formatFcfa(priceDiff)} (non encaissé)\n' : ''}'
          '\nLe stock diminue pour l’accepté, le remplacé et les pertes.',
      confirmLabel: 'Valider la livraison',
    );
    if (confirmed != true || !mounted) return;

    context.read<SalesOrderBloc>().add(
          SalesOrderDeliverRequested(
            orderId: widget.order.id,
            lines: lines,
            paymentMethod: _payment,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            driverName: _driverController.text.trim().isEmpty
                ? null
                : _driverController.text.trim(),
            vehiclePlate: _vehicleController.text.trim().isEmpty
                ? null
                : _vehicleController.text.trim(),
            remainingReason: remainingAfter > 0 ? _remainingReason : null,
            amountCash: _payment == PaymentMethod.cash ? saleTotal : 0,
            amountMomo: _payment == PaymentMethod.mtnMomo ||
                    _payment == PaymentMethod.moovMoney
                ? saleTotal
                : 0,
            amountCredit:
                _payment == PaymentMethod.credit ? saleTotal : 0,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final remainingItems =
        widget.order.items.where((i) => i.quantityRemaining > 0).toList();

    return BlocListener<SalesOrderBloc, SalesOrderState>(
      listenWhen: (p, c) =>
          p.lastDelivery != c.lastDelivery ||
          p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context
              .read<SalesOrderBloc>()
              .add(const SalesOrderFeedbackCleared());
        }
        if (state.lastDelivery != null &&
            state.lastDelivery!.salesOrderId == widget.order.id) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Livraison ${widget.order.number}'),
        ),
        body: remainingItems.isEmpty
            ? const Center(child: Text('Rien à livrer.'))
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'Client : ${widget.order.customerName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...remainingItems.map((item) {
                    final refusedQty = _parse(_refused[item.id]);
                    final replacedQty = _parse(_replaced[item.id]);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              item.productName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Reste ${item.quantityRemaining} · '
                              '${formatFcfa(item.unitPrice)}'
                              '${item.quantityInStock != null ? ' · stock ${item.quantityInStock}' : ''}',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _accepted[item.id],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Accepté',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextField(
                                    controller: _refused[item.id],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Refusé',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextField(
                                    controller: _replaced[item.id],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Remplacé',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            if (refusedQty > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              DropdownButtonFormField<SalesOrderRefusalReason>(
                                value: _reasons[item.id],
                                decoration: const InputDecoration(
                                  labelText: 'Motif du refus',
                                ),
                                items: SalesOrderRefusalReason.values
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.labelFr),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _reasons[item.id] = v),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              DropdownButtonFormField<
                                  SalesOrderRefusalDestination>(
                                value: _destinations[item.id],
                                decoration: const InputDecoration(
                                  labelText: 'Destination du refus',
                                ),
                                items: SalesOrderRefusalDestination.values
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d.labelFr),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                  () => _destinations[item.id] = v,
                                ),
                              ),
                            ],
                            if (replacedQty > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              OutlinedButton.icon(
                                onPressed: () => _pickReplacement(item),
                                icon: const Icon(Icons.swap_horiz),
                                label: Text(
                                  _replacementProductNames[item.id] ??
                                      'Choisir le produit de remplacement',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: _replacementPrice[item.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Prix unitaire remplacement',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  Builder(
                    builder: (context) {
                      var remainingAfter = 0;
                      for (final item in remainingItems) {
                        final accepted = _parse(_accepted[item.id]);
                        final refused = _parse(_refused[item.id]);
                        final replaced = _parse(_replaced[item.id]);
                        remainingAfter += (item.quantityRemaining -
                                accepted -
                                refused -
                                replaced)
                            .clamp(0, item.quantityRemaining);
                      }
                      if (remainingAfter <= 0) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<SalesOrderRemainingReason>(
                            value: _remainingReason,
                            decoration: InputDecoration(
                              labelText:
                                  'Pourquoi le reliquat ($remainingAfter) ?',
                            ),
                            items: SalesOrderRemainingReason.values
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r.labelFr),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _remainingReason = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    },
                  ),
                  DropdownButtonFormField<PaymentMethod>(
                    value: _payment,
                    decoration: const InputDecoration(
                      labelText: 'Paiement (accepté + remplacé)',
                    ),
                    items: const [
                      PaymentMethod.cash,
                      PaymentMethod.mtnMomo,
                      PaymentMethod.moovMoney,
                      PaymentMethod.credit,
                    ]
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _payment = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _driverController,
                    decoration: const InputDecoration(
                      labelText: 'Chauffeur (optionnel)',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _vehicleController,
                    decoration: const InputDecoration(
                      labelText: 'Plaque véhicule (optionnel)',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BlocBuilder<SalesOrderBloc, SalesOrderState>(
                    builder: (context, state) {
                      return FilledButton(
                        onPressed: state.saving ? null : _submit,
                        child: state.saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Valider la livraison'),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
