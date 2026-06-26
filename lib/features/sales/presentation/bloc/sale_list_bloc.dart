import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    emit(state.copyWith(status: SaleListStatus.loading, clearError: true));
    await _fetch(emit);
  }

  Future<void> _onRefresh(
    SaleListRefreshRequested event,
    Emitter<SaleListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit);
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
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<SaleListState> emit) async {
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
      emit(
        state.copyWith(
          status: SaleListStatus.failure,
          errorMessage: e.message,
          isRefreshing: false,
        ),
      );
    } catch (_) {
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
