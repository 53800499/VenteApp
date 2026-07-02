import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/customer_usecases.dart';

part 'customer_list_event.dart';
part 'customer_list_state.dart';

class CustomerListBloc extends Bloc<CustomerListEvent, CustomerListState> {
  CustomerListBloc({
    required ListCustomers listCustomers,
    required ListDebtors listDebtors,
    required CustomerRepository repository,
    required SyncPolicy syncPolicy,
    required AuthSession session,
    CustomerListFilters initialFilters = const CustomerListFilters(),
  })  : _listCustomers = listCustomers,
        _listDebtors = listDebtors,
        _repository = repository,
        _syncPolicy = syncPolicy,
        _session = session,
        super(CustomerListState(filters: initialFilters)) {
    on<CustomerListLoadRequested>(_onLoad);
    on<CustomerListRefreshRequested>(_onRefresh);
    on<CustomerListSearchChanged>(_onSearch);
    on<CustomerListDebtFilterToggled>(_onDebtFilter);
    on<CustomerListSortChanged>(_onSort);
    on<CustomerListShowDebtorsToggled>(_onShowDebtors);
  }

  final ListCustomers _listCustomers;
  final ListDebtors _listDebtors;
  final CustomerRepository _repository;
  final SyncPolicy _syncPolicy;
  final AuthSession _session;

  Future<void> _onLoad(
    CustomerListLoadRequested event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(state.copyWith(status: CustomerListStatus.loading, clearError: true));
    await _fetch(emit, syncRemote: true);
  }

  Future<void> _onRefresh(
    CustomerListRefreshRequested event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit, syncRemote: true);
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
        isRefreshing: state.status == CustomerListStatus.ready,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onDebtFilter(
    CustomerListDebtFilterToggled event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(hasDebtOnly: event.enabled),
        showDebtorsOverview: false,
        isRefreshing: state.status == CustomerListStatus.ready,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onSort(
    CustomerListSortChanged event,
    Emitter<CustomerListState> emit,
  ) async {
    emit(
      state.copyWith(
        filters: state.filters.copyWith(sort: event.sort),
        isRefreshing: state.status == CustomerListStatus.ready,
      ),
    );
    await _fetch(emit);
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
    await _fetch(emit, syncRemote: event.enabled);
  }

  Future<void> _fetch(
    Emitter<CustomerListState> emit, {
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
          // Sync cloud optionnelle — afficher les clients locaux.
        }
      }

      final customers = await _listCustomers(
        session: _session,
        filters: state.filters,
      );

      DebtorsOverview? debtors;
      if (state.showDebtorsOverview || state.filters.hasDebtOnly) {
        debtors = await _listDebtors(session: _session);
      }

      emit(
        state.copyWith(
          status: CustomerListStatus.ready,
          customers: customers,
          debtorsOverview: debtors,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: CustomerListStatus.failure,
          isRefreshing: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: CustomerListStatus.failure,
          isRefreshing: false,
          errorMessage: 'Impossible de charger les clients.',
        ),
      );
    }
  }
}
