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
    on<SaleListLocalRefreshRequested>(_onLocalRefresh);
    on<SaleListSyncRefreshRequested>(_onSyncRefresh);
    on<SaleListSearchChanged>(_onSearch);

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
    add(const SaleListSyncRefreshRequested());
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
    await _fetch(emit, syncRemote: true);
  }

  Future<void> _onRefresh(
    SaleListRefreshRequested event,
    Emitter<SaleListState> emit,
  ) async {
    await _fetch(emit, syncRemote: true, forceRemote: true);
  }

  Future<void> _onLocalRefresh(
    SaleListLocalRefreshRequested event,
    Emitter<SaleListState> emit,
  ) async {
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onSyncRefresh(
    SaleListSyncRefreshRequested event,
    Emitter<SaleListState> emit,
  ) async {
    await _fetch(emit, localOnly: true);
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
      ),
    );
    await _fetch(emit, localOnly: true);
  }

  Future<void> _fetch(
    Emitter<SaleListState> emit, {
    bool syncRemote = false,
    bool forceRemote = false,
    bool localOnly = false,
  }) async {
    try {
      final sales = await _listSales(
        session: _session,
        filters: state.filters,
      );

      emit(
        state.copyWith(
          status: SaleListStatus.loaded,
          sales: sales,
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
        // Sync cloud optionnelle — conserver les ventes locales affichées.
      } catch (_) {
        // Doublons locaux ou données cloud partielles : ne pas bloquer la liste.
      }

      final refreshedSales = await _listSales(
        session: _session,
        filters: state.filters,
      );

      emit(
        state.copyWith(
          status: SaleListStatus.loaded,
          sales: refreshedSales,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      if (state.status == SaleListStatus.loaded) {
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
          status: SaleListStatus.failure,
          errorMessage: friendlyErrorMessage(e),
          isRefreshing: false,
        ),
      );
    } catch (_) {
      if (state.status == SaleListStatus.loaded) {
        emit(
          state.copyWith(
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
