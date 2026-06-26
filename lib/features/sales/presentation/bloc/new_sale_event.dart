part of 'new_sale_bloc.dart';

sealed class NewSaleEvent extends Equatable {
  const NewSaleEvent();

  @override
  List<Object?> get props => [];
}

final class NewSaleLoadRequested extends NewSaleEvent {
  const NewSaleLoadRequested();
}

final class NewSaleProductAdded extends NewSaleEvent {
  const NewSaleProductAdded(this.product);

  final SaleProductOption product;

  @override
  List<Object?> get props => [product];
}

final class NewSaleLineQuantityChanged extends NewSaleEvent {
  const NewSaleLineQuantityChanged({
    required this.productId,
    required this.quantity,
  });

  final int productId;
  final int quantity;

  @override
  List<Object?> get props => [productId, quantity];
}

final class NewSaleLineRemoved extends NewSaleEvent {
  const NewSaleLineRemoved(this.productId);

  final int productId;

  @override
  List<Object?> get props => [productId];
}

final class NewSalePaymentMethodChanged extends NewSaleEvent {
  const NewSalePaymentMethodChanged(this.method);

  final PaymentMethod method;

  @override
  List<Object?> get props => [method];
}

final class NewSaleCustomerSelected extends NewSaleEvent {
  const NewSaleCustomerSelected(this.customerId);

  final int? customerId;

  @override
  List<Object?> get props => [customerId];
}

final class NewSaleSubmitRequested extends NewSaleEvent {
  const NewSaleSubmitRequested();
}
