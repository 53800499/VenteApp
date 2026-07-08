import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_snapshot.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../../../core/sync/sync_policy.dart';

part 'sale_list_event.dart';
part 'sale_list_state.dart';

class SaleListBloc extends Bloc<SaleListEvent, SaleListState> {
  SaleListBloc({
    required ListSales listSales,
    required SaleRepository repository,
    required SyncPolicy syncPolicy,
    required AuthSession session,
    SyncService? syncService,
  })  : _listSales = listSales,
        _repository = repository,
        _syncPolicy = syncPolicy,
        _session = session,
        super(const SaleListState()) {
    on<SaleListLoadRequested>(_onLoad);
    on<SaleListRefreshRequested>(_onRefresh);
    on<SaleListSearchChanged>(_onSearch);

    // Recharge la liste locale à la fin de chaque cycle de sync (le pull cloud
    // a déjà écrit les nouvelles ventes en base à ce moment).
    _syncSub = syncService?.snapshots.listen(_onSyncSnapshot);
  }

  final ListSales _listSales;
  final SaleRepository _repository;
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
    add(const SaleListRefreshRequested());
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    SaleListLoadRequested event,
    Emitter<SaleListState> emit,
  ) async {
    final keepStale = state.sales.isNotEmpty;
    if (keepStale) {
      emit(state.copyWith(isRefreshing: true, clearError: true));
    } else {
      emit(state.copyWith(status: SaleListStatus.loading, clearError: true));
    }
    await _fetch(emit, keepStale: keepStale, syncRemote: true);
  }

  Future<void> _onRefresh(
    SaleListRefreshRequested event,
    Emitter<SaleListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit, keepStale: state.sales.isNotEmpty, syncRemote: true);
  }

  Future<void> _onSearch(
    SaleListSearchChanged event,
    Emitter<SaleListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(
          search: event.query,
          clearSearch: event.query.isEmpty,
        ),
        isRefreshing: state.status == SaleListStatus.loaded,
      ),
    );
    await _fetch(emit, keepStale: state.status == SaleListStatus.loaded);
  }

  Future<void> _fetch(
    Emitter<SaleListState> emit, {
    required bool keepStale,
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
          // Sync cloud optionnelle — afficher les ventes locales.
        }
      }

      final sales = await _listSales(
        session: _session,
        filters: state.filters,
      );
      emit(
        state.copyWith(
          status: SaleListStatus.loaded,
          sales: sales,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      if (keepStale) {
        emit(
          state.copyWith(
            status: SaleListStatus.loaded,
            isRefreshing: false,
            errorMessage: friendlyErrorMessage(e),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: SaleListStatus.failure,
          errorMessage: friendlyErrorMessage(e),
          isRefreshing: false,
        ),
      );
    } catch (_) {
      if (keepStale) {
        emit(
          state.copyWith(
            status: SaleListStatus.loaded,
            isRefreshing: false,
            errorMessage: 'Impossible de charger les ventes.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: SaleListStatus.failure,
          errorMessage: 'Impossible de charger les ventes.',
          isRefreshing: false,
        ),
      );
    }
  }
}
