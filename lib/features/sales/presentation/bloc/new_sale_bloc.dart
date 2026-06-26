import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../inventory/domain/usecases/inventory_usecases.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';

part 'new_sale_event.dart';
part 'new_sale_state.dart';

class NewSaleBloc extends Bloc<NewSaleEvent, NewSaleState> {
  NewSaleBloc({
    required ListProducts listProducts,
    required ListSaleCustomers listCustomers,
    required CreateStandardSale createStandardSale,
    required AuthSession session,
  })  : _listProducts = listProducts,
        _listCustomers = listCustomers,
        _createStandardSale = createStandardSale,
        _session = session,
        super(const NewSaleState()) {
    on<NewSaleLoadRequested>(_onLoad);
    on<NewSaleProductAdded>(_onProductAdded);
    on<NewSaleLineQuantityChanged>(_onQuantityChanged);
    on<NewSaleLineRemoved>(_onLineRemoved);
    on<NewSalePaymentMethodChanged>(_onPaymentChanged);
    on<NewSaleCustomerSelected>(_onCustomerSelected);
    on<NewSaleSubmitRequested>(_onSubmit);
  }

  final ListProducts _listProducts;
  final ListSaleCustomers _listCustomers;
  final CreateStandardSale _createStandardSale;
  final AuthSession _session;

  Future<void> _onLoad(
    NewSaleLoadRequested event,
    Emitter<NewSaleState> emit,
  ) async {
    emit(state.copyWith(status: NewSaleStatus.loading, clearError: true));
    try {
      final products = await _listProducts(
        shopId: _session.shop.id,
        filters: const ProductListFilters(),
      );
      final customers = await _listCustomers(session: _session);
      emit(
        state.copyWith(
          status: NewSaleStatus.ready,
          products: products
              .where((p) => !p.isArchived && p.quantityInStock > 0)
              .map(
                (p) => SaleProductOption(
                  id: p.id,
                  name: p.name,
                  priceSell: p.priceSell,
                  quantityInStock: p.quantityInStock,
                ),
              )
              .toList(),
          customers: customers,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: NewSaleStatus.failure,
          errorMessage: 'Impossible de charger les produits.',
        ),
      );
    }
  }

  void _onProductAdded(
    NewSaleProductAdded event,
    Emitter<NewSaleState> emit,
  ) {
    final existing = state.cart.indexWhere(
      (l) => l.productId == event.product.id,
    );
    if (existing >= 0) {
      final line = state.cart[existing];
      if (line.quantity >= line.stockAvailable) return;
      final updated = List<CartLine>.from(state.cart);
      updated[existing] = line.copyWith(quantity: line.quantity + 1);
      emit(state.copyWith(cart: updated));
      return;
    }

    emit(
      state.copyWith(
        cart: [
          ...state.cart,
          CartLine(
            productId: event.product.id,
            productName: event.product.name,
            unitPrice: event.product.priceSell,
            quantity: 1,
            stockAvailable: event.product.quantityInStock,
          ),
        ],
      ),
    );
  }

  void _onQuantityChanged(
    NewSaleLineQuantityChanged event,
    Emitter<NewSaleState> emit,
  ) {
    if (event.quantity <= 0) {
      add(NewSaleLineRemoved(event.productId));
      return;
    }
    final updated = state.cart.map((line) {
      if (line.productId != event.productId) return line;
      final qty = event.quantity.clamp(1, line.stockAvailable);
      return line.copyWith(quantity: qty);
    }).toList();
    emit(state.copyWith(cart: updated));
  }

  void _onLineRemoved(
    NewSaleLineRemoved event,
    Emitter<NewSaleState> emit,
  ) {
    emit(
      state.copyWith(
        cart: state.cart
            .where((line) => line.productId != event.productId)
            .toList(),
      ),
    );
  }

  void _onPaymentChanged(
    NewSalePaymentMethodChanged event,
    Emitter<NewSaleState> emit,
  ) {
    emit(
      state.copyWith(
        paymentMethod: event.method,
        clearCustomer: event.method != PaymentMethod.credit &&
            event.method != PaymentMethod.mixed,
      ),
    );
  }

  void _onCustomerSelected(
    NewSaleCustomerSelected event,
    Emitter<NewSaleState> emit,
  ) {
    emit(state.copyWith(selectedCustomerId: event.customerId));
  }

  Future<void> _onSubmit(
    NewSaleSubmitRequested event,
    Emitter<NewSaleState> emit,
  ) async {
    if (state.cart.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Ajoutez au moins un produit au panier.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: NewSaleStatus.submitting, clearError: true));

    try {
      final total = state.subtotal;
      final payment = _buildPayment(total);

      final sale = await _createStandardSale(
        session: _session,
        input: CreateStandardSaleInput(
          items: state.cart
              .map(
                (line) => SaleLineDraft(
                  productId: line.productId,
                  quantity: line.quantity,
                  unitPrice: line.unitPrice,
                ),
              )
              .toList(),
          payment: payment,
          customerId: state.selectedCustomerId,
        ),
      );

      emit(
        state.copyWith(
          status: NewSaleStatus.success,
          createdSale: sale,
          cart: const [],
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: NewSaleStatus.ready,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: NewSaleStatus.ready,
          errorMessage: 'Échec de l\'enregistrement de la vente.',
        ),
      );
    }
  }

  PaymentDraft _buildPayment(int total) {
    return switch (state.paymentMethod) {
      PaymentMethod.cash => PaymentDraft(
          method: PaymentMethod.cash,
          amountCash: total,
        ),
      PaymentMethod.mtnMomo => PaymentDraft(
          method: PaymentMethod.mtnMomo,
          amountMomo: total,
        ),
      PaymentMethod.moovMoney => PaymentDraft(
          method: PaymentMethod.moovMoney,
          amountMomo: total,
        ),
      PaymentMethod.credit => PaymentDraft(
          method: PaymentMethod.credit,
          amountCredit: total,
        ),
      PaymentMethod.mixed => PaymentDraft(
          method: PaymentMethod.mixed,
          amountCash: total,
        ),
    };
  }
}
