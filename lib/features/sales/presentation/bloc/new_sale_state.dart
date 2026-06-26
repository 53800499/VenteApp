part of 'new_sale_bloc.dart';

class SaleProductOption extends Equatable {
  const SaleProductOption({
    required this.id,
    required this.name,
    required this.priceSell,
    required this.quantityInStock,
  });

  final int id;
  final String name;
  final int priceSell;
  final int quantityInStock;

  @override
  List<Object?> get props => [id, name, priceSell, quantityInStock];
}

class CartLine extends Equatable {
  const CartLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.stockAvailable,
  });

  final int productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final int stockAvailable;

  int get lineTotal => unitPrice * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      stockAvailable: stockAvailable,
    );
  }

  @override
  List<Object?> get props =>
      [productId, productName, unitPrice, quantity, stockAvailable];
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
    this.createdSale,
    this.errorMessage,
  });

  final NewSaleStatus status;
  final List<SaleProductOption> products;
  final List<CartLine> cart;
  final List<SaleCustomerOption> customers;
  final PaymentMethod paymentMethod;
  final int? selectedCustomerId;
  final Sale? createdSale;
  final String? errorMessage;

  int get subtotal => cart.fold<int>(0, (sum, line) => sum + line.lineTotal);

  NewSaleState copyWith({
    NewSaleStatus? status,
    List<SaleProductOption>? products,
    List<CartLine>? cart,
    List<SaleCustomerOption>? customers,
    PaymentMethod? paymentMethod,
    int? selectedCustomerId,
    bool clearCustomer = false,
    Sale? createdSale,
    bool clearSale = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NewSaleState(
      status: status ?? this.status,
      products: products ?? this.products,
      cart: cart ?? this.cart,
      customers: customers ?? this.customers,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      selectedCustomerId:
          clearCustomer ? null : (selectedCustomerId ?? this.selectedCustomerId),
      createdSale: clearSale ? null : (createdSale ?? this.createdSale),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
        createdSale,
        errorMessage,
      ];
}
