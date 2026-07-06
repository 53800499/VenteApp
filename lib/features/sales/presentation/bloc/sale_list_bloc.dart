import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';

part 'sale_list_event.dart';
part 'sale_list_state.dart';

class SaleListBloc extends Bloc<SaleListEvent, SaleListState> {
  SaleListBloc({
    required ListSales listSales,
    required AuthSession session,
  })  : _listSales = listSales,
        _session = session,
        super(const SaleListState()) {
    on<SaleListLoadRequested>(_onLoad);
    on<SaleListRefreshRequested>(_onRefresh);
    on<SaleListSearchChanged>(_onSearch);
  }

  final ListSales _listSales;
  final AuthSession _session;

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
    await _fetch(emit, keepStale: keepStale);
  }

  Future<void> _onRefresh(
    SaleListRefreshRequested event,
    Emitter<SaleListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit, keepStale: state.sales.isNotEmpty);
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
