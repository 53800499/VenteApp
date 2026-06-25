part of 'product_list_bloc.dart';

enum ProductListStatus { initial, loading, loaded, failure }

class ProductListState extends Equatable {
  const ProductListState({
    this.status = ProductListStatus.initial,
    this.products = const [],
    this.categories = const [],
    this.filters = const ProductListFilters(),
    this.errorMessage,
    this.isRefreshing = false,
  });

  final ProductListStatus status;
  final List<Product> products;
  final List<ProductCategory> categories;
  final ProductListFilters filters;
  final String? errorMessage;
  final bool isRefreshing;

  ProductListState copyWith({
    ProductListStatus? status,
    List<Product>? products,
    List<ProductCategory>? categories,
    ProductListFilters? filters,
    String? errorMessage,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return ProductListState(
      status: status ?? this.status,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      filters: filters ?? this.filters,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        categories,
        filters,
        errorMessage,
        isRefreshing,
      ];
}
