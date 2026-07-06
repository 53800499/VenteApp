import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/report_entities.dart';
import '../../domain/usecases/get_report.dart';

part 'report_event.dart';
part 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc({
    required GetReport getReport,
    required AuthSession session,
  })  : _getReport = getReport,
        _session = session,
        super(const ReportState()) {
    on<ReportLoadRequested>(_onLoad);
    on<ReportPeriodChanged>(_onPeriodChanged);
    on<ReportCustomRangeSelected>(_onCustomRange);
    on<ReportTopSortChanged>(_onTopSortChanged);
    on<ReportConsolidatedToggled>(_onConsolidatedToggled);
  }

  final GetReport _getReport;
  final AuthSession _session;

  AuthSession get session => _session;

  Set<Permission> get _permissions => _session.user.permissions;

  bool get _canViewFinancial =>
      PermissionGuard.can(_permissions, Permission.reportsFinancial);

  bool get _canUseConsolidated => PermissionGuard.can(
        _permissions,
        Permission.shopsConsolidatedRead,
      );

  bool get _includeSellerPerformance =>
      PermissionGuard.can(_permissions, Permission.reportsRead);

  Future<void> _onLoad(
    ReportLoadRequested event,
    Emitter<ReportState> emit,
  ) async {
    await _fetch(emit);
  }

  Future<void> _onPeriodChanged(
    ReportPeriodChanged event,
    Emitter<ReportState> emit,
  ) async {
    if (event.period == ReportPeriodPreset.custom) {
      if (state.report == null) {
        emit(state.copyWith(status: ReportStatus.loading));
      }
      return;
    }
    emit(
      state.copyWith(
        query: state.query.copyWith(period: event.period),
        clearError: true,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onCustomRange(
    ReportCustomRangeSelected event,
    Emitter<ReportState> emit,
  ) async {
    emit(
      state.copyWith(
        query: state.query.copyWith(
          period: ReportPeriodPreset.custom,
          customFrom: event.fromMs,
          customTo: event.toMs,
        ),
        clearError: true,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onTopSortChanged(
    ReportTopSortChanged event,
    Emitter<ReportState> emit,
  ) async {
    emit(
      state.copyWith(
        query: state.query.copyWith(topBy: event.sort),
        clearError: true,
      ),
    );
    await _fetch(emit);
  }

  Future<void> _onConsolidatedToggled(
    ReportConsolidatedToggled event,
    Emitter<ReportState> emit,
  ) async {
    final previousConsolidated = state.query.consolidated;
    emit(
      state.copyWith(
        query: state.query.copyWith(consolidated: event.enabled),
        clearError: true,
      ),
    );
    final failed = await _fetch(emit);
    if (failed && previousConsolidated != event.enabled) {
      emit(
        state.copyWith(
          query: state.query.copyWith(consolidated: previousConsolidated),
        ),
      );
    }
  }

  /// Retourne `true` si le chargement a échoué.
  Future<bool> _fetch(Emitter<ReportState> emit) async {
    final keepStale = state.report != null;
    if (!keepStale) {
      emit(state.copyWith(status: ReportStatus.loading, clearError: true));
    } else {
      emit(state.copyWith(isRefreshing: true, clearError: true));
    }

    try {
      final report = await _getReport(
        session: _session,
        query: state.query,
        canViewFinancial: _canViewFinancial,
        canUseConsolidated: _canUseConsolidated,
        includeSellerPerformance: _includeSellerPerformance,
      );
      emit(
        state.copyWith(
          status: ReportStatus.success,
          report: report,
          isRefreshing: false,
          clearError: true,
        ),
      );
      return false;
    } on Failure catch (error) {
      if (keepStale) {
        emit(
          state.copyWith(
            status: ReportStatus.success,
            isRefreshing: false,
            errorMessage: error.message,
          ),
        );
        return true;
      }
      emit(
        state.copyWith(
          status: ReportStatus.failure,
          isRefreshing: false,
          errorMessage: error.message,
        ),
      );
      return true;
    } catch (error) {
      if (keepStale) {
        emit(
          state.copyWith(
            status: ReportStatus.success,
            isRefreshing: false,
            errorMessage: error.toString(),
          ),
        );
        return true;
      }
      emit(
        state.copyWith(
          status: ReportStatus.failure,
          isRefreshing: false,
          errorMessage: error.toString(),
        ),
      );
      return true;
    }
  }
}
