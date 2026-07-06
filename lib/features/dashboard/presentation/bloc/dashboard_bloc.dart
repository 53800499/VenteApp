import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/usecases/get_dashboard.dart';
import '../../domain/entities/dashboard_entities.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required GetDashboard getDashboard,
    required AuthSession session,
  })  : _getDashboard = getDashboard,
        _session = session,
        super(const DashboardInitial()) {
    on<DashboardLoadRequested>(_onLoad);
    on<DashboardRefreshRequested>(_onLoad);
  }

  final GetDashboard _getDashboard;
  final AuthSession _session;

  Future<void> _onLoad(
    DashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    final previous = state;
    if (previous is DashboardLoaded) {
      emit(DashboardLoaded(previous.data, isRefreshing: true));
    } else {
      emit(const DashboardLoading());
    }

    try {
      final data = await _getDashboard(
        shopId: _session.shop.id,
        permissions: _session.user.permissions,
      );
      emit(DashboardLoaded(data));
    } catch (error) {
      if (previous is DashboardLoaded) {
        emit(DashboardLoaded(previous.data, isRefreshing: false));
        return;
      }
      emit(DashboardFailure(error.toString()));
    }
  }
}
