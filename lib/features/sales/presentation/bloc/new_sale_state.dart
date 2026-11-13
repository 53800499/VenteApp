part of 'new_sale_bloc.dart';

class SaleProductOption extends Equatable {
  const SaleProductOption({
    required this.id,
    required this.name,
    required this.priceSell,
    this.priceSemiWholesale,
    this.priceWholesale,
    required this.quantityInStock,
  });

  final int id;
  final String name;
  final int priceSell;
  final int? priceSemiWholesale;
  final int? priceWholesale;
  final int quantityInStock;

  int catalogPrice(SalePricingTier tier) => catalogPriceForTier(
        priceSell: priceSell,
        priceSemiWholesale: priceSemiWholesale,
        priceWholesale: priceWholesale,
        tier: tier,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        priceSell,
        priceSemiWholesale,
        priceWholesale,
        quantityInStock,
      ];
}

class CartLine extends Equatable {
  const CartLine({
    required this.productId,
    required this.productName,
    required this.catalogUnitPrice,
    required this.unitPrice,
    required this.quantity,
    required this.stockAvailable,
    this.isManualPrice = false,
    this.usedRememberedPrice = false,
    this.deficitReason,
  });

  final int productId;
  final String productName;
  final int catalogUnitPrice;
  final int unitPrice;
  final int quantity;
  final int stockAvailable;
  final bool isManualPrice;
  final bool usedRememberedPrice;
  final String? deficitReason;

  int get lineTotal => unitPrice * quantity;
  int get deficitQuantity =>
      quantity > stockAvailable ? (quantity - (stockAvailable > 0 ? stockAvailable : 0)) : 0;
  bool get hasDeficit => deficitQuantity > 0;

  CartLine copyWith({
    int? quantity,
    int? catalogUnitPrice,
    int? unitPrice,
    bool? isManualPrice,
    bool? usedRememberedPrice,
    String? deficitReason,
  }) {
    return CartLine(
      productId: productId,
      productName: productName,
      catalogUnitPrice: catalogUnitPrice ?? this.catalogUnitPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      stockAvailable: stockAvailable,
      isManualPrice: isManualPrice ?? this.isManualPrice,
      usedRememberedPrice: usedRememberedPrice ?? this.usedRememberedPrice,
      deficitReason: deficitReason ?? this.deficitReason,
    );
  }

  @override
  List<Object?> get props => [
        productId,
        productName,
        catalogUnitPrice,
        unitPrice,
        quantity,
        stockAvailable,
        isManualPrice,
        usedRememberedPrice,
        deficitReason,
      ];
}

enum NewSaleStatus { initial, loading, ready, submitting, success, failure }

class NewSaleState extends Equatable {
  const NewSaleState({
    this.status = NewSaleStatus.initial,
    this.products = const [],
    this.cart = const [],
    this.customers = const [],
    this.paymentMethod = PaymentMethod.cash,
    this.selectedCustomerId,
    this.mixedAmountCash = 0,
    this.mixedAmountMomo = 0,
    this.mixedAmountCredit = 0,
    this.searchQuery = '',
    this.creatingCustomer = false,
    this.createdSale,
    this.errorMessage,
    this.pricingTiersEnabled = false,
    this.selectedPricingTier = SalePricingTier.retail,
    this.canOverridePrice = false,
    this.customerRememberedPrices = const {},
    this.cashSessionOpen = true,
    this.negativeStockMode = 'warning',
    this.allowCreditSales = true,
    this.confirmBeforeValidation = true,
    this.autoPrintReceipt = false,
  });

  final NewSaleStatus status;
  final List<SaleProductOption> products;
  final List<CartLine> cart;
  final List<SaleCustomerOption> customers;
  final PaymentMethod paymentMethod;
  final int? selectedCustomerId;
  final int mixedAmountCash;
  final int mixedAmountMomo;
  final int mixedAmountCredit;
  final String searchQuery;
  final bool creatingCustomer;
  final Sale? createdSale;
  final String? errorMessage;
  final bool pricingTiersEnabled;
  final SalePricingTier selectedPricingTier;
  final bool canOverridePrice;
  final Map<int, int> customerRememberedPrices;
  final bool cashSessionOpen;
  final String negativeStockMode;
  final bool allowCreditSales;
  final bool confirmBeforeValidation;
  final bool autoPrintReceipt;

  int get subtotal => cart.fold<int>(0, (sum, line) => sum + line.lineTotal);

  bool get needsCustomer =>
      paymentMethod == PaymentMethod.credit ||
      (paymentMethod == PaymentMethod.mixed && mixedAmountCredit > 0);

  List<SaleProductOption> get filteredProducts {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  int get mixedRemaining =>
      subtotal - mixedAmountCash - mixedAmountMomo - mixedAmountCredit;

  NewSaleState copyWith({
    NewSaleStatus? status,
    List<SaleProductOption>? products,
    List<CartLine>? cart,
    List<SaleCustomerOption>? customers,
    PaymentMethod? paymentMethod,
    int? selectedCustomerId,
    bool clearCustomer = false,
    int? mixedAmountCash,
    int? mixedAmountMomo,
    int? mixedAmountCredit,
    String? searchQuery,
    bool? creatingCustomer,
    Sale? createdSale,
    bool clearSale = false,
    String? errorMessage,
    bool clearError = false,
    bool? pricingTiersEnabled,
    SalePricingTier? selectedPricingTier,
    bool? canOverridePrice,
    Map<int, int>? customerRememberedPrices,
    bool clearRememberedPrices = false,
    bool? cashSessionOpen,
    String? negativeStockMode,
    bool? allowCreditSales,
    bool? confirmBeforeValidation,
    bool? autoPrintReceipt,
  }) {
    return NewSaleState(
      status: status ?? this.status,
      products: products ?? this.products,
      cart: cart ?? this.cart,
      customers: customers ?? this.customers,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      selectedCustomerId:
          clearCustomer ? null : (selectedCustomerId ?? this.selectedCustomerId),
      mixedAmountCash: mixedAmountCash ?? this.mixedAmountCash,
      mixedAmountMomo: mixedAmountMomo ?? this.mixedAmountMomo,
      mixedAmountCredit: mixedAmountCredit ?? this.mixedAmountCredit,
      searchQuery: searchQuery ?? this.searchQuery,
      creatingCustomer: creatingCustomer ?? this.creatingCustomer,
      createdSale: clearSale ? null : (createdSale ?? this.createdSale),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pricingTiersEnabled: pricingTiersEnabled ?? this.pricingTiersEnabled,
      selectedPricingTier: selectedPricingTier ?? this.selectedPricingTier,
      canOverridePrice: canOverridePrice ?? this.canOverridePrice,
      customerRememberedPrices: clearRememberedPrices
          ? const {}
          : (customerRememberedPrices ?? this.customerRememberedPrices),
      cashSessionOpen: cashSessionOpen ?? this.cashSessionOpen,
      negativeStockMode: negativeStockMode ?? this.negativeStockMode,
      allowCreditSales: allowCreditSales ?? this.allowCreditSales,
      confirmBeforeValidation: confirmBeforeValidation ?? this.confirmBeforeValidation,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        cart,
        customers,
        paymentMethod,
        selectedCustomerId,
        mixedAmountCash,
        mixedAmountMomo,
        mixedAmountCredit,
        searchQuery,
        creatingCustomer,
        createdSale,
        errorMessage,
        pricingTiersEnabled,
        selectedPricingTier,
        canOverridePrice,
        customerRememberedPrices,
        cashSessionOpen,
        negativeStockMode,
        allowCreditSales,
        confirmBeforeValidation,
        autoPrintReceipt,
      ];
}
