part of 'product_list_bloc.dart';

sealed class ProductListEvent extends Equatable {
  const ProductListEvent();

  @override
  List<Object?> get props => [];
}

class ProductListLoadRequested extends ProductListEvent {
  const ProductListLoadRequested();
}

class ProductListRefreshRequested extends ProductListEvent {
  const ProductListRefreshRequested();
}

class ProductListLocalRefreshRequested extends ProductListEvent {
  const ProductListLocalRefreshRequested();
}

class ProductListSyncRefreshRequested extends ProductListEvent {
  const ProductListSyncRefreshRequested();
}

class ProductListSearchChanged extends ProductListEvent {
  const ProductListSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ProductListCategoryChanged extends ProductListEvent {
  const ProductListCategoryChanged(this.categoryId);

  final int? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

class ProductListLowStockToggled extends ProductListEvent {
  const ProductListLowStockToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class ProductListSortChanged extends ProductListEvent {
  const ProductListSortChanged(this.sort);

  final ProductSort sort;

  @override
  List<Object?> get props => [sort];
}
