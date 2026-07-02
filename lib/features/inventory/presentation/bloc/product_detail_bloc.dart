import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/usecases/inventory_usecases.dart';

part 'product_detail_event.dart';
part 'product_detail_state.dart';

class ProductDetailBloc extends Bloc<ProductDetailEvent, ProductDetailState> {
  ProductDetailBloc({
    required GetProductDetail getProductDetail,
    required ArchiveProduct archiveProduct,
    required int shopId,
    required int productId,
  })  : _getProductDetail = getProductDetail,
        _archiveProduct = archiveProduct,
        _shopId = shopId,
        _productId = productId,
        super(const ProductDetailState()) {
    on<ProductDetailLoadRequested>(_onLoad);
    on<ProductDetailArchiveRequested>(_onArchive);
    on<ProductDetailErrorDismissed>(_onErrorDismissed);
  }

  final GetProductDetail _getProductDetail;
  final ArchiveProduct _archiveProduct;
  final int _shopId;
  final int _productId;

  Future<void> _onLoad(
    ProductDetailLoadRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(state.copyWith(status: ProductDetailStatus.loading, clearError: true));
    try {
      final detail = await _getProductDetail(
        shopId: _shopId,
        productId: _productId,
      );
      emit(
        state.copyWith(
          status: ProductDetailStatus.loaded,
          detail: detail,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: ProductDetailStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onArchive(
    ProductDetailArchiveRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(state.copyWith(isArchiving: true, clearError: true));
    try {
      await _archiveProduct(shopId: _shopId, productId: _productId);
      emit(state.copyWith(isArchiving: false, archived: true));
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isArchiving: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  void _onErrorDismissed(
    ProductDetailErrorDismissed event,
    Emitter<ProductDetailState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
