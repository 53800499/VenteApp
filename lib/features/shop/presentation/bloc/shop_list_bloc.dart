import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/shop_entities.dart';
import '../../domain/usecases/shop_usecases.dart';

part 'shop_list_event.dart';
part 'shop_list_state.dart';

class ShopListBloc extends Bloc<ShopListEvent, ShopListState> {
  ShopListBloc({
    required ListShops listShops,
    required CreateShop createShop,
    required UpdateShop updateShop,
    required DeactivateShop deactivateShop,
    required SetDefaultShop setDefaultShop,
    required int? activeServerShopId,
  })  : _listShops = listShops,
        _createShop = createShop,
        _updateShop = updateShop,
        _deactivateShop = deactivateShop,
        _setDefaultShop = setDefaultShop,
        super(ShopListState(activeServerShopId: activeServerShopId)) {
    on<ShopListLoadRequested>(_onLoad);
    on<ShopListRefreshRequested>(_onRefresh);
    on<ShopCreateRequested>(_onCreate);
    on<ShopUpdateRequested>(_onUpdate);
    on<ShopDeactivateRequested>(_onDeactivate);
    on<ShopSetDefaultRequested>(_onSetDefault);
  }

  final ListShops _listShops;
  final CreateShop _createShop;
  final UpdateShop _updateShop;
  final DeactivateShop _deactivateShop;
  final SetDefaultShop _setDefaultShop;

  Future<void> _onLoad(
    ShopListLoadRequested event,
    Emitter<ShopListState> emit,
  ) async {
    emit(state.copyWith(status: ShopListStatus.loading, clearError: true));
    await _fetch(emit);
  }

  Future<void> _onRefresh(
    ShopListRefreshRequested event,
    Emitter<ShopListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<ShopListState> emit) async {
    try {
      final result = await _listShops();
      emit(
        state.copyWith(
          status: ShopListStatus.loaded,
          shops: result.shops,
          activeServerShopId: result.activeShopId,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: ShopListStatus.failure,
          errorMessage: e.message,
          isRefreshing: false,
        ),
      );
    }
  }

  Future<void> _onCreate(
    ShopCreateRequested event,
    Emitter<ShopListState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _createShop(event.input);
      await _fetch(emit);
      emit(state.copyWith(isSubmitting: false, successMessage: 'Boutique créée.'));
    } on Failure catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> _onUpdate(
    ShopUpdateRequested event,
    Emitter<ShopListState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _updateShop(event.shopId, event.input);
      await _fetch(emit);
      emit(state.copyWith(isSubmitting: false, successMessage: 'Boutique mise à jour.'));
    } on Failure catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> _onDeactivate(
    ShopDeactivateRequested event,
    Emitter<ShopListState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _deactivateShop(event.shopId, reason: event.reason);
      await _fetch(emit);
      emit(state.copyWith(isSubmitting: false, successMessage: 'Boutique désactivée.'));
    } on Failure catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> _onSetDefault(
    ShopSetDefaultRequested event,
    Emitter<ShopListState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _setDefaultShop(event.shopId);
      await _fetch(emit);
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Boutique par défaut définie.',
        ),
      );
    } on Failure catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }
}
