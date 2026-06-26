import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../bloc/new_sale_bloc.dart';
import 'sale_receipt_page.dart';

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key, required this.session});

  final AuthSession session;

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewSaleBloc(
        listProducts: sl(),
        listCustomers: sl(),
        createStandardSale: sl(),
        session: widget.session,
      )..add(const NewSaleLoadRequested()),
      child: BlocListener<NewSaleBloc, NewSaleState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) async {
          if (state.status == NewSaleStatus.success && state.createdSale != null) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SaleReceiptPage(
                  session: widget.session,
                  sale: state.createdSale!,
                ),
              ),
            );
            if (context.mounted) Navigator.of(context).pop(true);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_step == 0 ? 'Nouvelle vente' : 'Paiement'),
          ),
          body: BlocBuilder<NewSaleBloc, NewSaleState>(
            builder: (context, state) {
              if (state.status == NewSaleStatus.loading ||
                  state.status == NewSaleStatus.initial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == NewSaleStatus.failure) {
                return Center(child: Text(state.errorMessage ?? 'Erreur'));
              }

              return Column(
                children: [
                  if (state.errorMessage != null)
                    MaterialBanner(
                      content: Text(state.errorMessage!),
                      actions: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: _step == 0
                        ? _ProductPicker(state: state)
                        : _PaymentStep(state: state),
                  ),
                  _BottomBar(
                    step: _step,
                    state: state,
                    onBack: () => setState(() => _step = 0),
                    onNext: () {
                      if (state.cart.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ajoutez au moins un produit.'),
                          ),
                        );
                        return;
                      }
                      setState(() => _step = 1);
                    },
                    onSubmit: () => context
                        .read<NewSaleBloc>()
                        .add(const NewSaleSubmitRequested()),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.state});

  final NewSaleState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: state.products.length,
            itemBuilder: (context, index) {
              final product = state.products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '${formatFcfa(product.priceSell)} · Stock: ${product.quantityInStock}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => context.read<NewSaleBloc>().add(
                        NewSaleProductAdded(product),
                      ),
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: _CartPanel(cart: state.cart),
        ),
      ],
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.cart});

  final List<CartLine> cart;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Center(child: Text('Panier vide'));
    }

    final total = cart.fold<int>(0, (sum, l) => sum + l.lineTotal);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final line = cart[index];
              return ListTile(
                title: Text(line.productName),
                subtitle: Text(formatFcfa(line.unitPrice)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => context.read<NewSaleBloc>().add(
                            NewSaleLineQuantityChanged(
                              productId: line.productId,
                              quantity: line.quantity - 1,
                            ),
                          ),
                    ),
                    Text('${line.quantity}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: line.quantity >= line.stockAvailable
                          ? null
                          : () => context.read<NewSaleBloc>().add(
                                NewSaleLineQuantityChanged(
                                  productId: line.productId,
                                  quantity: line.quantity + 1,
                                ),
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Total : ${formatFcfa(total)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
    final needsCustomer = state.paymentMethod == PaymentMethod.credit;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Total : ${formatFcfa(state.subtotal)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Mode de paiement', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...PaymentMethod.values
            .where((m) => m != PaymentMethod.mixed)
            .map(
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
        if (needsCustomer) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Client', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (state.customers.isEmpty)
            const Text('Aucun client enregistré. Créez un client d\'abord.')
          else
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Sélectionner un client',
              ),
              value: state.selectedCustomerId,
              items: state.customers
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
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
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.state,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final int step;
  final NewSaleState state;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final submitting = state.status == NewSaleStatus.submitting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (step == 1)
              TextButton(onPressed: submitting ? null : onBack, child: const Text('Retour')),
            const Spacer(),
            FilledButton(
              onPressed: submitting
                  ? null
                  : (step == 0 ? onNext : onSubmit),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(step == 0 ? 'Continuer' : 'Valider la vente'),
            ),
          ],
        ),
      ),
    );
  }
}
