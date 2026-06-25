part of 'product_detail_bloc.dart';

enum ProductDetailStatus { initial, loading, loaded, failure }

class ProductDetailState extends Equatable {
  const ProductDetailState({
    this.status = ProductDetailStatus.initial,
    this.detail,
    this.errorMessage,
    this.isArchiving = false,
    this.archived = false,
  });

  final ProductDetailStatus status;
  final ProductDetail? detail;
  final String? errorMessage;
  final bool isArchiving;
  final bool archived;

  ProductDetailState copyWith({
    ProductDetailStatus? status,
    ProductDetail? detail,
    String? errorMessage,
    bool? isArchiving,
    bool? archived,
    bool clearError = false,
  }) {
    return ProductDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isArchiving: isArchiving ?? this.isArchiving,
      archived: archived ?? this.archived,
    );
  }

  @override
  List<Object?> get props => [
        status,
        detail,
        errorMessage,
        isArchiving,
        archived,
      ];
}
