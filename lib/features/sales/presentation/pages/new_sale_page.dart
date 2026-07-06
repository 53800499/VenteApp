import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../sales_analysis/domain/usecases/sales_analysis_usecases.dart';
import '../../../sales_analysis/presentation/utils/sales_analysis_formatters.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/entities/sale_pricing_entities.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../bloc/new_sale_bloc.dart';
import '../widgets/sale_feedback.dart';
import 'sale_receipt_page.dart';

/// Page de création d'une vente.
///
/// [TabBar] + [IndexedStack] : le [TabController] pilote l'index ;
/// chaque enfant de la pile doit recevoir des contraintes bornées
/// ([StackFit.expand] + [SizedBox.expand]).
class NewSalePage extends StatefulWidget {
  const NewSalePage({
    super.key,
    required this.session,
    this.conversion,
  });

  final AuthSession session;
  final QuickSaleConversion? conversion;

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabIndexChanged);
  }

  void _onTabIndexChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewSaleBloc(
        listProducts: sl(),
        listCustomers: sl(),
        createStandardSale: sl(),
        createCustomer: sl(),
        settingsLocal: sl(),
        customerPrices: sl(),
        convertQuickSale: sl(),
        conversion: widget.conversion,
        session: widget.session,
      )..add(const NewSaleLoadRequested()),
      child: BlocListener<NewSaleBloc, NewSaleState>(
        listenWhen: (prev, curr) =>
            prev.creatingCustomer && !curr.creatingCustomer,
        listener: (context, state) async {
          if (state.errorMessage != null) {
            await SaleFeedback.showErrorDialog(
              context,
              title: 'Création impossible',
              message: state.errorMessage!,
            );
            if (context.mounted) {
              context.read<NewSaleBloc>().add(const NewSaleErrorDismissed());
            }
          } else {
            await SaleFeedback.showSuccess(
              context: context,
              title: 'Client ajouté',
              message: 'Le nouveau client a été sélectionné pour la vente.',
            );
          }
        },
        child: BlocListener<NewSaleBloc, NewSaleState>(
        listenWhen: (prev, curr) {
          if (prev.status != curr.status) return true;
          if (curr.errorMessage != null &&
              prev.errorMessage != curr.errorMessage &&
              curr.status == NewSaleStatus.ready &&
              !(prev.creatingCustomer && !curr.creatingCustomer)) {
            return true;
          }
          return false;
        },
        listener: (context, state) async {
          if (state.status == NewSaleStatus.success &&
              state.createdSale != null) {
            final sale = state.createdSale!;
            await SaleFeedback.showSaleRegistered(context, sale: sale);
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SaleReceiptPage(
                  session: widget.session,
                  sale: sale,
                ),
              ),
            );
            if (context.mounted) Navigator.of(context).pop(true);
            return;
          }

          if (state.errorMessage != null &&
              state.status == NewSaleStatus.ready) {
            await SaleFeedback.showErrorDialog(
              context,
              title: 'Action impossible',
              message: state.errorMessage!,
            );
            if (context.mounted) {
              context.read<NewSaleBloc>().add(const NewSaleErrorDismissed());
            }
          }
        },
        child: BlocBuilder<NewSaleBloc, NewSaleState>(
          builder: (context, state) {
            return Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                title: Text(
                  widget.conversion != null
                      ? 'Convertir en vente standard'
                      : (_step == 0 ? 'Nouvelle vente' : 'Paiement'),
                ),
              ),
              body: _buildBody(context, state),
            );
          },
        ),
      ),
      ),
    );
  }

  Future<void> _confirmSubmit(BuildContext context, NewSaleState state) async {
    final conversion = widget.conversion;
    final confirmed = await SaleFeedback.confirm(
      context: context,
      title:
          conversion != null ? 'Confirmer la conversion' : 'Confirmer la vente',
      message: conversion != null
          ? 'Convertir ${conversion.receiptLabel ?? 'la vente'} '
              'pour ${formatFcfa(state.subtotal)} ?'
          : 'Enregistrer ${formatFcfa(state.subtotal)} '
              'en ${state.paymentMethod.label} ?',
    );
    if (confirmed == true && context.mounted) {
      context.read<NewSaleBloc>().add(const NewSaleSubmitRequested());
    }
  }

  Widget _buildBody(BuildContext context, NewSaleState state) {
    if (state.status == NewSaleStatus.loading && state.products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Chargement des produits…'),
          ],
        ),
      );
    }
    if (state.status == NewSaleStatus.failure) {
      return _ErrorBody(
        message: state.errorMessage ?? 'Erreur de chargement',
        onRetry: () =>
            context.read<NewSaleBloc>().add(const NewSaleLoadRequested()),
      );
    }

    return Stack(
      children: [
        Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.conversion != null)
          Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.conversion!.receiptLabel ??
                        'Vente #${widget.conversion!.saleId}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Montant à répartir : ${formatFcfa(widget.conversion!.targetTotal)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    state.subtotal == widget.conversion!.targetTotal
                        ? 'Panier complet ✓'
                        : state.subtotal > widget.conversion!.targetTotal
                            ? 'Dépassement : ${formatFcfa(state.subtotal - widget.conversion!.targetTotal)}'
                            : 'Reste à ajouter : ${formatFcfa(widget.conversion!.targetTotal - state.subtotal)}',
                    style: TextStyle(
                      color: state.subtotal == widget.conversion!.targetTotal
                          ? Colors.green.shade700
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: ErrorBanner(message: state.errorMessage!),
          ),
        if (_step == 0)
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Produits'),
                Tab(
                  text: state.cart.isEmpty
                      ? 'Panier'
                      : 'Panier (${state.cart.length})',
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.conversion != null || _step == 0
              ? IndexedStack(
                  index: _tabController.index,
                  sizing: StackFit.expand,
                  children: [
                    SizedBox.expand(
                      child: _ProductList(
                        state: state,
                        searchController: _searchController,
                      ),
                    ),
                    SizedBox.expand(
                      child: _CartPanel(state: state),
                    ),
                  ],
                )
              : _PaymentStep(state: state),
        ),
        _BottomBar(
          step: _step,
          state: state,
          isConversion: widget.conversion != null,
          targetTotal: widget.conversion?.targetTotal,
          onBack: () => setState(() => _step = 0),
          onNext: () {
            if (widget.conversion != null) {
              if (state.cart.isEmpty) {
                SaleFeedback.showErrorMessage(
                  context,
                  'Ajoutez au moins un produit.',
                );
                _tabController.animateTo(1);
                return;
              }
              if (state.subtotal != widget.conversion!.targetTotal) {
                SaleFeedback.showErrorMessage(
                  context,
                  'Le panier doit totaliser '
                  '${formatFcfa(widget.conversion!.targetTotal)}.',
                );
                return;
              }
              _confirmSubmit(context, state);
              return;
            }
            if (state.cart.isEmpty) {
              SaleFeedback.showErrorMessage(
                context,
                'Ajoutez au moins un produit.',
              );
              _tabController.animateTo(1);
              return;
            }
            setState(() => _step = 1);
          },
          onSubmit: () => _confirmSubmit(context, state),
        ),
      ],
    ),
        if (state.status == NewSaleStatus.loading)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.sm),
                      Text('Actualisation…'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.state,
    required this.searchController,
  });

  final NewSaleState state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final products = state.filteredProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher un produit…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) =>
                context.read<NewSaleBloc>().add(NewSaleSearchChanged(q)),
          ),
        ),
        if (state.pricingTiersEnabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SegmentedButton<SalePricingTier>(
              segments: SalePricingTier.values
                  .map(
                    (tier) => ButtonSegment(
                      value: tier,
                      label: Text(tier.label),
                    ),
                  )
                  .toList(),
              selected: {state.selectedPricingTier},
              onSelectionChanged: (selection) {
                context.read<NewSaleBloc>().add(
                      NewSalePricingTierChanged(selection.first),
                    );
              },
            ),
          ),
        ],
        Expanded(
          child: products.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state.products.isEmpty
                                      ? 'Aucun produit disponible.\nAjoutez des produits dans Inventaire, puis actualisez.'
                                      : 'Aucun produit ne correspond à votre recherche.',
                                  textAlign: TextAlign.center,
                                ),
                                if (state.products.isEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  OutlinedButton.icon(
                                    onPressed: () => context
                                        .read<NewSaleBloc>()
                                        .add(const NewSaleLoadRequested()),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Actualiser'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    context
                        .read<NewSaleBloc>()
                        .add(const NewSaleLoadRequested());
                    await context.read<NewSaleBloc>().stream.firstWhere(
                          (s) =>
                              s.status == NewSaleStatus.ready ||
                              s.status == NewSaleStatus.failure,
                        );
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final inCartIndex = state.cart
                          .indexWhere((l) => l.productId == product.id);
                      final inCart =
                          inCartIndex >= 0 ? state.cart[inCartIndex] : null;
                      final outOfStock = product.quantityInStock <= 0;
                      return Card(
                        key: ValueKey('product-${product.id}'),
                        color: outOfStock
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.sm,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      outOfStock
                                          ? '${formatFcfa(product.catalogPrice(state.selectedPricingTier))} · Rupture de stock'
                                          : '${formatFcfa(product.catalogPrice(state.selectedPricingTier))} · Stock ${product.quantityInStock}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _ProductCartControls(
                                product: product,
                                cartLine: inCart,
                                outOfStock: outOfStock,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.state});

  final NewSaleState state;

  List<CartLine> get cart => state.cart;
  int get total => state.subtotal;

  Future<void> _editUnitPrice(BuildContext context, CartLine line) async {
    final updated = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _UnitPriceEditDialog(line: line),
    );
    if (updated == null || !context.mounted) return;

    final bloc = context.read<NewSaleBloc>();
    ensureSalesAnalysisDependencies();
    final range = await sl<GetProductSoldPriceRange>()(
      shopId: bloc.session.shop.id,
      productId: line.productId,
    );

    if (!context.mounted) return;

    if (isUnusuallyLowPrice(enteredPrice: updated, range: range)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('Prix inhabituel'),
          content: Text(
            unusualPriceMessage(
              productName: line.productName,
              enteredPrice: updated,
              range: range,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Corriger'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    bloc.add(
      NewSaleLineUnitPriceChanged(
        productId: line.productId,
        unitPrice: updated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Panier vide\nAjoutez des produits depuis l\'onglet Produits.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final line = cart[index];
              return Card(
                key: ValueKey('cart-${line.productId}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.productName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: state.canOverridePrice
                                  ? () => _editUnitPrice(context, line)
                                  : null,
                              child: Text(
                                line.usedRememberedPrice
                                    ? '${formatFcfa(line.unitPrice)} / unité · dernier prix client'
                                    : line.isManualPrice
                                        ? '${formatFcfa(line.unitPrice)} / unité · prix modifié'
                                        : '${formatFcfa(line.unitPrice)} / unité',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: state.canOverridePrice
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                      decoration: state.canOverridePrice
                                          ? TextDecoration.underline
                                          : null,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _QuantityInput(
                        value: line.quantity,
                        maxQuantity: line.stockAvailable,
                        onChanged: (quantity) =>
                            context.read<NewSaleBloc>().add(
                                  NewSaleLineQuantityChanged(
                                    productId: line.productId,
                                    quantity: quantity,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Total panier : ${formatFcfa(total)}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitPriceEditDialog extends StatefulWidget {
  const _UnitPriceEditDialog({required this.line});

  final CartLine line;

  @override
  State<_UnitPriceEditDialog> createState() => _UnitPriceEditDialogState();
}

class _UnitPriceEditDialogState extends State<_UnitPriceEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.line.unitPrice}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value <= 0) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Prix — ${widget.line.productName}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Prix unitaire (FCFA)',
          helperText: 'Catalogue : ${formatFcfa(widget.line.catalogUnitPrice)}',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({required this.state});

  final NewSaleState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Total à payer : ${formatFcfa(state.subtotal)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Mode de paiement', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...PaymentMethod.values.map(
          (method) => RadioListTile<PaymentMethod>(
            title: Text(method.label),
            value: method,
            groupValue: state.paymentMethod,
            onChanged: (value) {
              if (value == null) return;
              context.read<NewSaleBloc>().add(
                    NewSalePaymentMethodChanged(value),
                  );
            },
          ),
        ),
        if (state.paymentMethod == PaymentMethod.mixed) ...[
          const SizedBox(height: AppSpacing.sm),
          _AmountField(
            label: 'Espèces (FCFA)',
            value: state.mixedAmountCash,
            onChanged: (v) => context.read<NewSaleBloc>().add(
                  NewSaleMixedAmountsChanged(amountCash: v),
                ),
          ),
          _AmountField(
            label: 'Mobile Money (FCFA)',
            value: state.mixedAmountMomo,
            onChanged: (v) => context.read<NewSaleBloc>().add(
                  NewSaleMixedAmountsChanged(amountMomo: v),
                ),
          ),
          _AmountField(
            label: 'Crédit (FCFA)',
            value: state.mixedAmountCredit,
            onChanged: (v) => context.read<NewSaleBloc>().add(
                  NewSaleMixedAmountsChanged(amountCredit: v),
                ),
          ),
          Text(
            state.mixedRemaining == 0
                ? 'Répartition complète ✓'
                : 'Reste à répartir : ${formatFcfa(state.mixedRemaining)}',
            style: TextStyle(
              color: state.mixedRemaining == 0
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (state.needsCustomer) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: MediaQuery.sizeOf(context).width - 2 * AppSpacing.md,
            child: Row(
              children: [
                Text('Client', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: state.creatingCustomer
                      ? null
                      : () => _showCreateCustomerSheet(context),
                  icon: state.creatingCustomer
                      ? SaleFeedback.inlineLoader(size: 16)
                      : const Icon(Icons.person_add_outlined),
                  label: Text(
                    state.creatingCustomer ? 'Création…' : 'Nouveau',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.customers.isEmpty)
            const Text(
              'Aucun client. Créez-en un pour enregistrer le crédit.',
            )
          else
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Sélectionner un client',
                border: OutlineInputBorder(),
              ),
              initialValue: state.selectedCustomerId,
              items: state.customers
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.phone != null ? '${c.name} (${c.phone})' : c.name,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) => context.read<NewSaleBloc>().add(
                    NewSaleCustomerSelected(id),
                  ),
            ),
        ],
      ],
    );
  }

  Future<void> _showCreateCustomerSheet(BuildContext context) async {
    final bloc = context.read<NewSaleBloc>();

    final result = await showModalBottomSheet<_NewCustomerSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _CreateCustomerSheet(),
    );

    if (result != null && context.mounted) {
      bloc.add(
        NewSaleCreateCustomerRequested(
          name: result.name,
          phone: result.phone,
        ),
      );
    }
  }
}

class _NewCustomerSheetResult {
  const _NewCustomerSheetResult({required this.name, this.phone});

  final String name;
  final String? phone;
}

class _CreateCustomerSheet extends StatefulWidget {
  const _CreateCustomerSheet();

  @override
  State<_CreateCustomerSheet> createState() => _CreateCustomerSheetState();
}

class _CreateCustomerSheetState extends State<_CreateCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.length < 2) return;
    final phone = _phoneController.text.trim();
    Navigator.pop(
      context,
      _NewCustomerSheetResult(
        name: name,
        phone: phone.isEmpty ? null : phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nouveau client',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Téléphone (recommandé)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _submit,
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _QuantityInput extends StatefulWidget {
  const _QuantityInput({
    this.value,
    required this.maxQuantity,
    this.onChanged,
    this.showPlusButton = true,
    this.allowRemove = true,
    super.key,
  });

  /// Si null, la quantité est gérée localement (sans rebuild parent).
  final int? value;
  final int maxQuantity;
  final ValueChanged<int>? onChanged;
  final bool showPlusButton;
  final bool allowRemove;

  @override
  State<_QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<_QuantityInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _localValue = 1;
  var _editing = false;

  bool get _isControlled => widget.value != null;

  int get _displayValue => widget.value ?? _localValue;

  int commitAndRead() {
    _commit();
    return _displayValue;
  }

  @override
  void initState() {
    super.initState();
    _localValue = widget.value ?? 1;
    _controller = TextEditingController(text: '$_localValue');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _commit();
    }
  }

  @override
  void didUpdateWidget(covariant _QuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isControlled &&
        !_editing &&
        widget.value != oldWidget.value &&
        widget.value != null) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _apply(int quantity) {
    if (quantity <= 0) {
      if (widget.allowRemove) {
        widget.onChanged?.call(0);
      } else if (!_isControlled) {
        setState(() => _localValue = 1);
        _controller.text = '1';
      }
      return;
    }

    final clamped = quantity.clamp(1, widget.maxQuantity);
    if (_isControlled) {
      widget.onChanged?.call(clamped);
    } else {
      setState(() => _localValue = clamped);
      _controller.text = '$clamped';
    }
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _controller.text = '$_displayValue';
      setState(() => _editing = false);
      return;
    }
    final parsed = int.tryParse(text) ?? _displayValue;
    _apply(parsed);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _displayValue <= 1
              ? (widget.allowRemove ? () => _apply(0) : null)
              : () => _apply(_displayValue - 1),
        ),
        SizedBox(
          width: 52,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onTap: () => setState(() => _editing = true),
            onSubmitted: (_) => _commit(),
            onChanged: (_) => _editing = true,
          ),
        ),
        if (widget.showPlusButton)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _displayValue >= widget.maxQuantity
                ? null
                : () => _apply(_displayValue + 1),
          ),
      ],
    );
  }
}

class _ProductCartControls extends StatefulWidget {
  const _ProductCartControls({
    required this.product,
    required this.cartLine,
    required this.outOfStock,
  });

  final SaleProductOption product;
  final CartLine? cartLine;
  final bool outOfStock;

  @override
  State<_ProductCartControls> createState() => _ProductCartControlsState();
}

class _ProductCartControlsState extends State<_ProductCartControls> {
  final _pendingQtyKey = GlobalKey<_QuantityInputState>();

  void _addToCart() {
    final qty = _pendingQtyKey.currentState?.commitAndRead() ?? 1;
    context.read<NewSaleBloc>().add(
          NewSaleProductAdded(widget.product, quantity: qty),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cartLine = widget.cartLine;
    if (cartLine != null) {
      return _QuantityInput(
        value: cartLine.quantity,
        maxQuantity: cartLine.stockAvailable,
        onChanged: (quantity) => context.read<NewSaleBloc>().add(
              NewSaleLineQuantityChanged(
                productId: widget.product.id,
                quantity: quantity,
              ),
            ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityInput(
          key: _pendingQtyKey,
          maxQuantity: widget.product.quantityInStock,
          showPlusButton: false,
          allowRemove: false,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.add_shopping_cart_outlined),
          tooltip: 'Ajouter au panier',
          onPressed: widget.outOfStock ? null : _addToCart,
        ),
      ],
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: _textForValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant _AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;

    final current = int.tryParse(_controller.text) ?? 0;
    if (widget.value != current && !_focusNode.hasFocus) {
      _controller.text = _textForValue(widget.value);
    }
  }

  String _textForValue(int value) => value > 0 ? '$value' : '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (text) {
          final parsed = int.tryParse(text) ?? 0;
          if (parsed != widget.value) {
            widget.onChanged(parsed);
          }
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.state,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    this.isConversion = false,
    this.targetTotal,
  });

  final int step;
  final NewSaleState state;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final bool isConversion;
  final int? targetTotal;

  static final _actionStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 44),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    final submitting = state.status == NewSaleStatus.submitting;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (step == 1)
              TextButton(
                onPressed: submitting ? null : onBack,
                child: const Text('Retour'),
              ),
            if (!isConversion && step == 0 && state.cart.isNotEmpty) ...[
              Expanded(
                child: Text(
                  formatFcfa(state.subtotal),
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            FilledButton(
              style: _actionStyle,
              onPressed: submitting
                  ? null
                  : (isConversion
                      ? onNext
                      : (step == 0 ? onNext : onSubmit)),
              child: submitting
                  ? SaleFeedback.inlineLoader()
                  : Text(
                      isConversion
                          ? 'Valider la conversion'
                          : (step == 0 ? 'Paiement' : 'Valider la vente'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
