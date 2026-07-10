import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_snapshot.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/customer_usecases.dart';
import '../../../sales/domain/repositories/sale_repository.dart';

part 'customer_list_event.dart';
part 'customer_list_state.dart';

class CustomerListBloc extends Bloc<CustomerListEvent, CustomerListState> {
  CustomerListBloc({
    required ListCustomers listCustomers,
    required ListDebtors listDebtors,
    required CustomerRepository repository,
    required SyncPolicy syncPolicy,
    required AuthSession session,
    SaleRepository? saleRepository,
    CustomerListFilters initialFilters = const CustomerListFilters(),
    SyncService? syncService,
  })  : _listCustomers = listCustomers,
        _listDebtors = listDebtors,
        _repository = repository,
        _saleRepository = saleRepository,
        _syncPolicy = syncPolicy,
        _session = session,
        super(CustomerListState(filters: initialFilters)) {
    on<CustomerListLoadRequested>(_onLoad);
    on<CustomerListRefreshRequested>(_onRefresh);
    on<CustomerListLocalRefreshRequested>(_onLocalRefresh);
    on<CustomerListSyncRefreshRequested>(_onSyncRefresh);
    on<CustomerListSearchChanged>(_onSearch);
    on<CustomerListDebtFilterToggled>(_onDebtFilter);
    on<CustomerListSortChanged>(_onSort);
    on<CustomerListShowDebtorsToggled>(_onShowDebtors);

    _syncSub = syncService?.snapshots.listen(_onSyncSnapshot);
  }

  final ListCustomers _listCustomers;
  final ListDebtors _listDebtors;
  final CustomerRepository _repository;
  final SaleRepository? _saleRepository;
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
    add(const CustomerListSyncRefreshRequested());
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    CustomerListLoadRequested event,
    Emitter<CustomerListState> emit,
  ) async {
    if (state.status == CustomerListStatus.ready) {
      await _fetch(emit, syncRemote: true);
      return;
    }
    await _fetch(emit, syncRemote: true);
  }

  Future<void> _onRefresh(
    CustomerListRefreshRequested event,
    Emitter<CustomerListState> emit,
  ) async {
    await _fetch(emit, syncRemote: true, forceRemote: true);
  }

  Future<void> _onLocalRefresh(
    CustomerListLocalRefreshRequested event,
    Emitter<CustomerListState> emit,
  ) async {
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onSyncRefresh(
    CustomerListSyncRefreshRequested event,
    Emitter<CustomerListState> emit,
  ) async {
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onSearch(
    CustomerListSearchChanged event,
    Emitter<CustomerListState> emit,
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

  Future<void> _onDebtFilter(
    CustomerListDebtFilterToggled event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(hasDebtOnly: event.enabled),
        showDebtorsOverview: event.enabled,
      ),
    );
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onSort(
    CustomerListSortChanged event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(sort: event.sort),
      ),
    );
    await _fetch(emit, localOnly: true);
  }

  Future<void> _onShowDebtors(
    CustomerListShowDebtorsToggled event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(
      state.copyWith(
        showDebtorsOverview: event.enabled,
        filters: state.filters.copyWith(hasDebtOnly: event.enabled),
      ),
    );
    await _fetch(emit, localOnly: true);
  }

  Future<void> _fetch(
    Emitter<CustomerListState> emit, {
    bool syncRemote = false,
    bool forceRemote = false,
    bool localOnly = false,
  }) async {
    try {
      final customers = await _listCustomers(
        session: _session,
        filters: state.filters,
      );
      final debtors = await _loadDebtorsIfNeeded();

      emit(
        state.copyWith(
          status: CustomerListStatus.ready,
          customers: customers,
          debtorsOverview: debtors,
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
        await _saleRepository?.syncFromRemote(
          shopId: _session.shop.id,
          force: forceRemote,
        );
      } on Failure {
        // Sync cloud optionnelle — conserver la liste locale affichée.
      }

      final refreshedCustomers = await _listCustomers(
        session: _session,
        filters: state.filters,
      );
      final refreshedDebtors = await _loadDebtorsIfNeeded();

      emit(
        state.copyWith(
          status: CustomerListStatus.ready,
          customers: refreshedCustomers,
          debtorsOverview: refreshedDebtors,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      if (state.status == CustomerListStatus.ready) {
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
          status: CustomerListStatus.failure,
          isRefreshing: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (_) {
      if (state.status == CustomerListStatus.ready) {
        emit(
          state.copyWith(
            isRefreshing: false,
            errorMessage: 'Impossible de charger les clients.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: CustomerListStatus.failure,
          isRefreshing: false,
          errorMessage: 'Impossible de charger les clients.',
        ),
      );
    }
  }

  Future<DebtorsOverview?> _loadDebtorsIfNeeded() async {
    if (state.showDebtorsOverview || state.filters.hasDebtOnly) {
      return _listDebtors(session: _session);
    }
    return null;
  }
}
