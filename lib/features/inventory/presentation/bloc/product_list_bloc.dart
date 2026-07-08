import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_snapshot.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/usecases/inventory_usecases.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../../../core/sync/sync_policy.dart';

part 'product_list_event.dart';
part 'product_list_state.dart';

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  ProductListBloc({
    required ListProducts listProducts,
    required ListCategories listCategories,
    required InventoryRepository repository,
    required SyncPolicy syncPolicy,
    required AuthSession session,
    ProductListFilters initialFilters = const ProductListFilters(),
    SyncService? syncService,
  })  : _listProducts = listProducts,
        _listCategories = listCategories,
        _repository = repository,
        _syncPolicy = syncPolicy,
        _session = session,
        super(ProductListState(filters: initialFilters)) {
    on<ProductListLoadRequested>(_onLoad);
    on<ProductListSearchChanged>(_onSearch);
    on<ProductListCategoryChanged>(_onCategory);
    on<ProductListLowStockToggled>(_onLowStock);
    on<ProductListSortChanged>(_onSort);
    on<ProductListRefreshRequested>(_onRefresh);

    // Recharge le stock local à la fin de chaque cycle de sync.
    _syncSub = syncService?.snapshots.listen(_onSyncSnapshot);
  }

  final ListProducts _listProducts;
  final ListCategories _listCategories;
  final InventoryRepository _repository;
  final SyncPolicy _syncPolicy;
  final AuthSession _session;

  StreamSubscription<SyncSnapshot>? _syncSub;
  DateTime? _lastHandledSyncAt;

  void _onSyncSnapshot(SyncSnapshot snapshot) {
    if (snapshot.phase != SyncRunPhase.completed) return;
    if (snapshot.shopId != null && snapshot.shopId != _session.shop.id) return;

    final completedAt = snapshot.lastCompletedAt;
    if (completedAt != null && completedAt == _lastHandledSyncAt) return;
    _lastHandledSyncAt = completedAt;

    if (isClosed) return;
    add(const ProductListRefreshRequested());
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    ProductListLoadRequested event,
    Emitter<ProductListState> emit,
  ) async {
    emit(state.copyWith(status: ProductListStatus.loading, clearError: true));
    await _fetch(emit, syncRemote: true);
  }

  Future<void> _onRefresh(
    ProductListRefreshRequested event,
    Emitter<ProductListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit, syncRemote: true);
  }

  Future<void> _onSearch(
    ProductListSearchChanged event,
    Emitter<ProductListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(
          search: event.query,
          clearSearch: event.query.isEmpty,
        ),
        isRefreshing: state.status == ProductListStatus.loaded,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onCategory(
    ProductListCategoryChanged event,
    Emitter<ProductListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(
          categoryId: event.categoryId,
          clearCategory: event.categoryId == null,
        ),
        isRefreshing: state.status == ProductListStatus.loaded,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onLowStock(
    ProductListLowStockToggled event,
    Emitter<ProductListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(lowStockOnly: event.enabled),
        isRefreshing: state.status == ProductListStatus.loaded,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onSort(
    ProductListSortChanged event,
    Emitter<ProductListState> emit,
  ) async {
    emit(state.copyWith(
      filters: state.filters.copyWith(sort: event.sort),
      isRefreshing: state.status == ProductListStatus.loaded,
    ));
    await _fetch(emit);
  }

  Future<void> _fetch(
    Emitter<ProductListState> emit, {
    bool syncRemote = false,
  }) async {
    try {
      if (syncRemote &&
          await _syncPolicy.shouldRunCloudSync(
            shopId: _session.shop.id,
          )) {
        try {
          await _repository.syncFromRemote(shopId: _session.shop.id);
        } on Failure {
          // Sync cloud optionnelle — afficher le stock local.
        }
      }

      final categories = await _listCategories(shopId: _session.shop.id);
      final products = await _listProducts(
        shopId: _session.shop.id,
        filters: state.filters,
      );
      emit(
        state.copyWith(
          status: ProductListStatus.loaded,
          products: products,
          categories: categories,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: ProductListStatus.failure,
          errorMessage: friendlyErrorMessage(e),
          isRefreshing: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ProductListStatus.failure,
          errorMessage: 'Impossible de charger les produits.',
          isRefreshing: false,
        ),
      );
    }
  }
}
