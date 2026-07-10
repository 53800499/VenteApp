import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_snapshot.dart';
import '../../domain/usecases/get_dashboard.dart';
import '../../domain/entities/dashboard_entities.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required GetDashboard getDashboard,
    required AuthSession session,
    SyncService? syncService,
  })  : _getDashboard = getDashboard,
        _session = session,
        super(const DashboardInitial()) {
    on<DashboardLoadRequested>(_onLoad);
    on<DashboardRefreshRequested>(_onLoad);

    // Recharge automatiquement depuis Drift à la fin de chaque cycle de sync
    // (le pull cloud a déjà écrit les nouvelles données en local à ce moment).
    _syncSub = syncService?.snapshots.listen(_onSyncSnapshot);
  }

  final GetDashboard _getDashboard;
  final AuthSession _session;

  StreamSubscription<SyncSnapshot>? _syncSub;
  DateTime? _lastHandledSyncAt;

  void _onSyncSnapshot(SyncSnapshot snapshot) {
    if (snapshot.phase != SyncRunPhase.completed) return;
    if (snapshot.shopId != null && snapshot.shopId != _session.shop.id) return;

    // Déduplication : un cycle terminé porte un horodatage unique.
    final completedAt = snapshot.lastCompletedAt;
    if (completedAt != null && completedAt == _lastHandledSyncAt) return;
    _lastHandledSyncAt = completedAt;

    if (isClosed) return;
    add(const DashboardRefreshRequested());
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    DashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    final previous = state;
    if (previous is DashboardLoaded) {
      emit(DashboardLoaded(previous.data, isRefreshing: true));
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
