import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/commerce_shop_scope.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/domain/entities/customer_entities.dart';
import '../../../customers/domain/usecases/customer_usecases.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../inventory/domain/usecases/inventory_usecases.dart';
import '../../../settings/data/datasources/local/settings_local_datasource.dart';
import '../../data/datasources/local/customer_product_price_local_datasource.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/entities/sale_pricing_entities.dart';
import '../../domain/usecases/sale_usecases.dart';

part 'new_sale_event.dart';
part 'new_sale_state.dart';

class NewSaleBloc extends Bloc<NewSaleEvent, NewSaleState> {
  NewSaleBloc({
    required ListProducts listProducts,
    required ListSaleCustomers listCustomers,
    required CreateStandardSale createStandardSale,
    required CreateCustomer createCustomer,
    required AuthSession session,
    required SettingsLocalDatasource settingsLocal,
    required CustomerProductPriceLocalDatasource customerPrices,
    ConvertQuickSaleToStandard? convertQuickSale,
    QuickSaleConversion? conversion,
  })  : _listProducts = listProducts,
        _listCustomers = listCustomers,
        _createStandardSale = createStandardSale,
        _createCustomer = createCustomer,
        _settingsLocal = settingsLocal,
        _customerPrices = customerPrices,
        _convertQuickSale = convertQuickSale,
        _conversion = conversion,
        _session = session,
        super(const NewSaleState()) {
    on<NewSaleLoadRequested>(_onLoad);
    on<NewSaleProductAdded>(_onProductAdded);
    on<NewSaleLineQuantityChanged>(_onQuantityChanged);
    on<NewSaleLineRemoved>(_onLineRemoved);
    on<NewSaleLineUnitPriceChanged>(_onLineUnitPriceChanged);
    on<NewSalePricingTierChanged>(_onPricingTierChanged);
    on<NewSalePaymentMethodChanged>(_onPaymentChanged);
    on<NewSaleCustomerSelected>(_onCustomerSelected);
    on<NewSaleSearchChanged>(_onSearchChanged);
    on<NewSaleMixedAmountsChanged>(_onMixedAmountsChanged);
    on<NewSaleCreateCustomerRequested>(_onCreateCustomer);
    on<NewSaleErrorDismissed>(_onErrorDismissed);
    on<NewSaleSubmitRequested>(_onSubmit);
  }

  final ListProducts _listProducts;
  final ListSaleCustomers _listCustomers;
  final CreateStandardSale _createStandardSale;
  final CreateCustomer _createCustomer;
  final SettingsLocalDatasource _settingsLocal;
  final CustomerProductPriceLocalDatasource _customerPrices;
  final ConvertQuickSaleToStandard? _convertQuickSale;
  final QuickSaleConversion? _conversion;
  final AuthSession _session;

  AuthSession get session => _session;

  bool get isConversion => _conversion != null;

  Future<void> _onLoad(
    NewSaleLoadRequested event,
    Emitter<NewSaleState> emit,
  ) async {
    emit(state.copyWith(status: NewSaleStatus.loading, clearError: true));
    try {
      final config =
          await _settingsLocal.loadConfiguration(_session.shop.id);
      final products = await _loadProducts();
      var customers = const <SaleCustomerOption>[];
      try {
        customers = await _listCustomers(session: _session);
      } on Object {
        // Clients optionnels pour une vente espèces.
      }

      emit(
        NewSaleState(
          status: NewSaleStatus.ready,
          products: products
              .map(
                (p) => SaleProductOption(
                  id: p.id,
                  name: p.name,
                  priceSell: p.priceSell,
                  priceSemiWholesale: p.priceSemiWholesale,
                  priceWholesale: p.priceWholesale,
                  quantityInStock: p.quantityInStock,
                ),
              )
              .toList(),
          customers: customers,
          cart: state.cart,
          paymentMethod: state.paymentMethod,
          selectedCustomerId: state.selectedCustomerId,
          mixedAmountCash: state.mixedAmountCash,
          mixedAmountMomo: state.mixedAmountMomo,
          mixedAmountCredit: state.mixedAmountCredit,
          searchQuery: state.searchQuery,
          pricingTiersEnabled: config.commerce.pricingTiersEnabled,
          selectedPricingTier: state.selectedPricingTier,
          canOverridePrice: PermissionGuard.can(
            _session.user.permissions,
            Permission.salesPriceOverride,
          ),
        ),
      );
    } on Failure catch (error) {
      emit(
        state.copyWith(
          status: NewSaleStatus.failure,
          errorMessage: friendlyErrorMessage(error),
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

  Future<List<Product>> _loadProducts() async {
    const filters = ProductListFilters();
    final shopIds = CommerceShopScope.candidateLocalShopIds(_session);

    for (final shopId in shopIds) {
      final products = await _listProducts(shopId: shopId, filters: filters);
      if (products.isNotEmpty) {
        return products;
      }
    }

    return _listProducts(shopId: _session.shop.id, filters: filters);
  }

  int _resolveUnitPrice(SaleProductOption product) {
    final remembered = state.customerRememberedPrices[product.id];
    if (state.selectedCustomerId != null &&
        remembered != null &&
        remembered > 0) {
      return remembered;
    }
    return product.catalogPrice(state.selectedPricingTier);
  }

  bool _usesRememberedPrice(SaleProductOption product, int unitPrice) {
    final remembered = state.customerRememberedPrices[product.id];
    return state.selectedCustomerId != null &&
        remembered != null &&
        remembered > 0 &&
        unitPrice == remembered;
  }

  CartLine _buildCartLine({
    required SaleProductOption product,
    required int quantity,
    int? unitPrice,
    bool isManualPrice = false,
  }) {
    final resolved = unitPrice ?? _resolveUnitPrice(product);
    final catalog = product.catalogPrice(state.selectedPricingTier);
    return CartLine(
      productId: product.id,
      productName: product.name,
      catalogUnitPrice: catalog,
      unitPrice: resolved,
      quantity: quantity,
      stockAvailable: product.quantityInStock,
      isManualPrice: isManualPrice,
      usedRememberedPrice:
          _usesRememberedPrice(product, resolved) && !isManualPrice,
    );
  }

  Future<Map<int, int>> _loadRememberedPrices(int? customerId) async {
    if (customerId == null) return {};
    final productIds = state.products.map((p) => p.id);
    if (productIds.isEmpty) return {};
    return _customerPrices.loadForCustomer(
      shopId: _session.shop.id,
      customerId: customerId,
      productIds: productIds,
    );
  }

  List<CartLine> _refreshCartPrices({
    required List<CartLine> cart,
    required SalePricingTier tier,
    required Map<int, int> remembered,
  }) {
    final productsById = {for (final p in state.products) p.id: p};
    return cart.map((line) {
      if (line.isManualPrice) return line;
      final product = productsById[line.productId];
      if (product == null) return line;

      final rememberedPrice = remembered[product.id];
      final unitPrice = state.selectedCustomerId != null &&
              rememberedPrice != null &&
              rememberedPrice > 0
          ? rememberedPrice
          : product.catalogPrice(tier);

      return line.copyWith(
        catalogUnitPrice: product.catalogPrice(tier),
        unitPrice: unitPrice,
        usedRememberedPrice: state.selectedCustomerId != null &&
            rememberedPrice != null &&
            rememberedPrice > 0 &&
            unitPrice == rememberedPrice,
      );
    }).toList();
  }

  void _onSearchChanged(
    NewSaleSearchChanged event,
    Emitter<NewSaleState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onProductAdded(
    NewSaleProductAdded event,
    Emitter<NewSaleState> emit,
  ) {
    final stock = event.product.quantityInStock;
    if (stock <= 0) return;

    final addQty = event.quantity.clamp(1, stock);
    final existing = state.cart.indexWhere(
      (l) => l.productId == event.product.id,
    );
    if (existing >= 0) {
      final line = state.cart[existing];
      final newQty = (line.quantity + addQty).clamp(1, line.stockAvailable);
      if (newQty == line.quantity) return;
      final updated = List<CartLine>.from(state.cart);
      updated[existing] = line.copyWith(quantity: newQty);
      emit(state.copyWith(cart: updated, clearError: true));
      return;
    }

    emit(
      state.copyWith(
        cart: [
          ...state.cart,
          _buildCartLine(product: event.product, quantity: addQty),
        ],
        clearError: true,
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

  void _onLineUnitPriceChanged(
    NewSaleLineUnitPriceChanged event,
    Emitter<NewSaleState> emit,
  ) {
    if (!state.canOverridePrice || event.unitPrice <= 0) return;
    final updated = state.cart.map((line) {
      if (line.productId != event.productId) return line;
      return line.copyWith(
        unitPrice: event.unitPrice,
        isManualPrice: true,
        usedRememberedPrice: false,
      );
    }).toList();
    emit(state.copyWith(cart: updated, clearError: true));
  }

  Future<void> _onPricingTierChanged(
    NewSalePricingTierChanged event,
    Emitter<NewSaleState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedPricingTier: event.tier,
        cart: _refreshCartPrices(
          cart: state.cart,
          tier: event.tier,
          remembered: state.customerRememberedPrices,
        ),
        clearError: true,
      ),
    );
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
    final total = state.subtotal;
    emit(
      state.copyWith(
        paymentMethod: event.method,
        clearCustomer: event.method != PaymentMethod.credit &&
            event.method != PaymentMethod.mixed,
        mixedAmountCash: event.method == PaymentMethod.mixed ? total : 0,
        mixedAmountMomo: 0,
        mixedAmountCredit: 0,
        clearRememberedPrices:
            event.method != PaymentMethod.credit &&
            event.method != PaymentMethod.mixed,
        clearError: true,
      ),
    );
  }

  void _onMixedAmountsChanged(
    NewSaleMixedAmountsChanged event,
    Emitter<NewSaleState> emit,
  ) {
    emit(
      state.copyWith(
        mixedAmountCash: event.amountCash ?? state.mixedAmountCash,
        mixedAmountMomo: event.amountMomo ?? state.mixedAmountMomo,
        mixedAmountCredit: event.amountCredit ?? state.mixedAmountCredit,
        clearError: true,
      ),
    );
  }

  Future<void> _onCustomerSelected(
    NewSaleCustomerSelected event,
    Emitter<NewSaleState> emit,
  ) async {
    if (event.customerId == null) {
      emit(
        state.copyWith(
          clearCustomer: true,
          clearRememberedPrices: true,
          cart: _refreshCartPrices(
            cart: state.cart,
            tier: state.selectedPricingTier,
            remembered: const {},
          ),
          clearError: true,
        ),
      );
      return;
    }

    final remembered = await _loadRememberedPrices(event.customerId);
    emit(
      state.copyWith(
        selectedCustomerId: event.customerId,
        customerRememberedPrices: remembered,
        cart: _refreshCartPrices(
          cart: state.cart,
          tier: state.selectedPricingTier,
          remembered: remembered,
        ),
        clearError: true,
        clearRememberedPrices: event.customerId == null,
      ),
    );
  }

  void _onErrorDismissed(
    NewSaleErrorDismissed event,
    Emitter<NewSaleState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _onCreateCustomer(
    NewSaleCreateCustomerRequested event,
    Emitter<NewSaleState> emit,
  ) async {
    emit(state.copyWith(creatingCustomer: true, clearError: true));
    try {
      final customer = await _createCustomer(
        session: _session,
        input: CreateCustomerInput(
          name: event.name,
          phone: event.phone,
        ),
      );
      final customers = await _listCustomers(session: _session);
      final remembered = await _loadRememberedPrices(customer.id);
      emit(
        state.copyWith(
          creatingCustomer: false,
          customers: customers,
          selectedCustomerId: customer.id,
          customerRememberedPrices: remembered,
          cart: _refreshCartPrices(
            cart: state.cart,
            tier: state.selectedPricingTier,
            remembered: remembered,
          ),
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          creatingCustomer: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          creatingCustomer: false,
          errorMessage: 'Impossible de créer le client.',
        ),
      );
    }
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

    if (state.needsCustomer && state.selectedCustomerId == null) {
      emit(
        state.copyWith(
          errorMessage: 'Sélectionnez ou créez un client pour le crédit.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: NewSaleStatus.submitting, clearError: true));

    try {
      final conversion = _conversion;
      if (conversion != null) {
        if (_convertQuickSale == null) {
          throw const ValidationFailure('Conversion indisponible.');
        }
        if (state.subtotal != conversion.targetTotal) {
          throw ValidationFailure(
            'Le panier doit totaliser exactement '
            '${conversion.targetTotal} FCFA.',
          );
        }

        final sale = await _convertQuickSale(
          session: _session,
          saleId: conversion.saleId,
          input: ConvertQuickSaleInput(
            items: state.cart
                .map(
                  (line) => SaleLineDraft(
                    productId: line.productId,
                    quantity: line.quantity,
                    unitPrice: line.unitPrice,
                  ),
                )
                .toList(),
          ),
        );

        emit(
          state.copyWith(
            status: NewSaleStatus.success,
            createdSale: sale,
            cart: const [],
          ),
        );
        return;
      }

      final total = state.subtotal;
      final payment = _buildPayment(total);
      final customerId = state.selectedCustomerId;

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
          customerId: customerId,
        ),
      );

      if (customerId != null) {
        final lines = state.cart
            .map(
              (line) => (
                productId: line.productId,
                unitPrice: line.unitPrice,
              ),
            )
            .toList();
        unawaited(
          _customerPrices.saveAfterSale(
            shopId: _session.shop.id,
            customerId: customerId,
            lines: lines,
          ),
        );
      }

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
          errorMessage: friendlyErrorMessage(e),
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
          amountCash: state.mixedAmountCash,
          amountMomo: state.mixedAmountMomo,
          amountCredit: state.mixedAmountCredit,
        ),
    };
  }
}
