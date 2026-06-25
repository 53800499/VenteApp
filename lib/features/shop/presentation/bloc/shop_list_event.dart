part of 'shop_list_bloc.dart';

sealed class ShopListEvent extends Equatable {
  const ShopListEvent();

  @override
  List<Object?> get props => [];
}

class ShopListLoadRequested extends ShopListEvent {
  const ShopListLoadRequested();
}

class ShopListRefreshRequested extends ShopListEvent {
  const ShopListRefreshRequested();
}

class ShopCreateRequested extends ShopListEvent {
  const ShopCreateRequested(this.input);

  final CreateShopInput input;

  @override
  List<Object?> get props => [input];
}

class ShopUpdateRequested extends ShopListEvent {
  const ShopUpdateRequested({required this.shopId, required this.input});

  final int shopId;
  final UpdateShopInput input;

  @override
  List<Object?> get props => [shopId, input];
}

class ShopDeactivateRequested extends ShopListEvent {
  const ShopDeactivateRequested({required this.shopId, this.reason});

  final int shopId;
  final String? reason;

  @override
  List<Object?> get props => [shopId, reason];
}

class ShopSetDefaultRequested extends ShopListEvent {
  const ShopSetDefaultRequested(this.shopId);

  final int shopId;

  @override
  List<Object?> get props => [shopId];
}
