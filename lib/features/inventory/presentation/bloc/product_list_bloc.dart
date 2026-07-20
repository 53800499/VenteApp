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
    on<ProductListLocalRefreshRequested>(_onLocalRefresh);
    on<ProductListSyncRefreshRequested>(_onSyncRefresh);

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
    add(const ProductListSyncRefreshRequested());
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
    await _fetch(emit, syncRemote: true);
  }

  Future<void> _onRefresh(
    ProductListRefreshRequested event,
    Emitter<ProductListState> emit,
  ) async {
    await _fetch(emit, syncRemote: true, forceRemote: true);
  }

  Future<void> _onLocalRefresh(
    ProductListLocalRefreshRequested event,
    Emitter<ProductListState> emit,
  ) async {
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onSyncRefresh(
    ProductListSyncRefreshRequested event,
    Emitter<ProductListState> emit,
  ) async {
    await _fetch(emit, localOnly: true);
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
      ),
    );
    await _fetch(emit, localOnly: true);
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
      ),
    );
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onLowStock(
    ProductListLowStockToggled event,
    Emitter<ProductListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(lowStockOnly: event.enabled),
      ),
    );
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onSort(
    ProductListSortChanged event,
    Emitter<ProductListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(sort: event.sort),
      ),
    );
    await _fetch(emit, localOnly: true);
  }

  Future<void> _fetch(
    Emitter<ProductListState> emit, {
    bool syncRemote = false,
    bool forceRemote = false,
    bool localOnly = false,
  }) async {
    try {
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
          isRefreshing: syncRemote && !localOnly,
          clearError: true,
        ),
      );

      if (localOnly) {
        return;
      }

      if (!syncRemote ||
          !await _syncPolicy.shouldRunCloudSync(shopId: _session.shop.id)) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }

      emit(state.copyWith(isRefreshing: true));

      try {
        await _repository.syncFromRemote(
          shopId: _session.shop.id,
          force: forceRemote,
        );
      } on Failure {
        // Sync cloud optionnelle — conserver le stock local affiché.
      } catch (_) {
        // Doublons locaux ou données cloud partielles : ne pas bloquer la liste.
      }

      final refreshedCategories =
          await _listCategories(shopId: _session.shop.id);
      final refreshedProducts = await _listProducts(
        shopId: _session.shop.id,
        filters: state.filters,
      );

      emit(
        state.copyWith(
          status: ProductListStatus.loaded,
          products: refreshedProducts,
          categories: refreshedCategories,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      if (state.status == ProductListStatus.loaded) {
        emit(
          state.copyWith(
            isRefreshing: false,
            errorMessage: friendlyErrorMessage(e),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: ProductListStatus.failure,
          errorMessage: friendlyErrorMessage(e),
          isRefreshing: false,
        ),
      );
    } catch (_) {
      if (state.status == ProductListStatus.loaded) {
        emit(
          state.copyWith(
            isRefreshing: false,
            errorMessage: 'Impossible de charger les produits.',
          ),
        );
        return;
      }
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
