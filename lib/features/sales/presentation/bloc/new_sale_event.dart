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
  const NewSaleProductAdded(this.product, {this.quantity = 1});

  final SaleProductOption product;
  final int quantity;

  @override
  List<Object?> get props => [product, quantity];
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

final class NewSaleSearchChanged extends NewSaleEvent {
  const NewSaleSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class NewSaleMixedAmountsChanged extends NewSaleEvent {
  const NewSaleMixedAmountsChanged({
    this.amountCash,
    this.amountMomo,
    this.amountCredit,
  });

  final int? amountCash;
  final int? amountMomo;
  final int? amountCredit;

  @override
  List<Object?> get props => [amountCash, amountMomo, amountCredit];
}

final class NewSaleCreateCustomerRequested extends NewSaleEvent {
  const NewSaleCreateCustomerRequested({
    required this.name,
    this.phone,
  });

  final String name;
  final String? phone;

  @override
  List<Object?> get props => [name, phone];
}

final class NewSaleErrorDismissed extends NewSaleEvent {
  const NewSaleErrorDismissed();
}

final class NewSaleSubmitRequested extends NewSaleEvent {
  const NewSaleSubmitRequested();
}

final class NewSalePricingTierChanged extends NewSaleEvent {
  const NewSalePricingTierChanged(this.tier);

  final SalePricingTier tier;

  @override
  List<Object?> get props => [tier];
}

final class NewSaleLineUnitPriceChanged extends NewSaleEvent {
  const NewSaleLineUnitPriceChanged({
    required this.productId,
    required this.unitPrice,
  });

  final int productId;
  final int unitPrice;

  @override
  List<Object?> get props => [productId, unitPrice];
}

/// Sauvegarde le brouillon si l'utilisateur quitte sans valider la vente.
final class NewSaleDraftAbandonRequested extends NewSaleEvent {
  const NewSaleDraftAbandonRequested();
}
