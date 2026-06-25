part of 'product_detail_bloc.dart';

sealed class ProductDetailEvent extends Equatable {
  const ProductDetailEvent();

  @override
  List<Object?> get props => [];
}

class ProductDetailLoadRequested extends ProductDetailEvent {
  const ProductDetailLoadRequested();
}

class ProductDetailArchiveRequested extends ProductDetailEvent {
  const ProductDetailArchiveRequested();
}
