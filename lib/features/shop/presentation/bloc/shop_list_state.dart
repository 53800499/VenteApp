part of 'shop_list_bloc.dart';

enum ShopListStatus { initial, loading, loaded, failure }

class ShopListState extends Equatable {
  const ShopListState({
    this.status = ShopListStatus.initial,
    this.shops = const [],
    this.activeServerShopId,
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
  });

  final ShopListStatus status;
  final List<ManagedShop> shops;
  final int? activeServerShopId;
  final bool isRefreshing;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  List<ManagedShop> get activeShops =>
      shops.where((shop) => shop.isActive).toList();

  ShopListState copyWith({
    ShopListStatus? status,
    List<ManagedShop>? shops,
    int? activeServerShopId,
    bool? isRefreshing,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ShopListState(
      status: status ?? this.status,
      shops: shops ?? this.shops,
      activeServerShopId: activeServerShopId ?? this.activeServerShopId,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        shops,
        activeServerShopId,
        isRefreshing,
        isSubmitting,
        errorMessage,
        successMessage,
      ];
}
