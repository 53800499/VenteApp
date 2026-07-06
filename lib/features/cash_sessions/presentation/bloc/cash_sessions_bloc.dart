import 'dart:async' show unawaited;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/cash_session_entities.dart';
import '../../domain/usecases/cash_session_usecases.dart';

part 'cash_sessions_event.dart';
part 'cash_sessions_state.dart';

class CashSessionsBloc extends Bloc<CashSessionsEvent, CashSessionsState> {
  CashSessionsBloc({
    required FindOpenCashSession findOpenSession,
    required ListCashSessions listSessions,
    required GetCashSessionLiveTotals getLiveTotals,
    required ListCashMovements listMovements,
    required OpenCashSession openSession,
    required CloseCashSession closeSession,
    required RecordCashMovement recordMovement,
    required SyncCashSessionsFromRemote syncFromRemote,
    required AuthSession session,
  })  : _findOpenSession = findOpenSession,
        _listSessions = listSessions,
        _getLiveTotals = getLiveTotals,
        _listMovements = listMovements,
        _openSession = openSession,
        _closeSession = closeSession,
        _recordMovement = recordMovement,
        _syncFromRemote = syncFromRemote,
        _session = session,
        super(const CashSessionsState()) {
    on<CashSessionsLoadRequested>(_onLoad);
    on<CashSessionsRefreshRequested>(_onRefresh);
    on<CashSessionOpenRequested>(_onOpen);
    on<CashSessionCloseRequested>(_onClose);
    on<CashMovementRecordRequested>(_onMovement);
  }

  final FindOpenCashSession _findOpenSession;
  final ListCashSessions _listSessions;
  final GetCashSessionLiveTotals _getLiveTotals;
  final ListCashMovements _listMovements;
  final OpenCashSession _openSession;
  final CloseCashSession _closeSession;
  final RecordCashMovement _recordMovement;
  final SyncCashSessionsFromRemote _syncFromRemote;
  final AuthSession _session;

  AuthSession get session => _session;

  Future<void> _onLoad(
    CashSessionsLoadRequested event,
    Emitter<CashSessionsState> emit,
  ) async {
    emit(state.copyWith(status: CashSessionsStatus.loading, clearError: true));
    await _fetch(emit);
  }

  Future<void> _onRefresh(
    CashSessionsRefreshRequested event,
    Emitter<CashSessionsState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit);
  }

  Future<void> _onOpen(
    CashSessionOpenRequested event,
    Emitter<CashSessionsState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _openSession(session: _session, input: event.input);
      emit(state.copyWith(isSubmitting: false));
      await _fetch(emit);
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onClose(
    CashSessionCloseRequested event,
    Emitter<CashSessionsState> emit,
  ) async {
    final open = state.openSession;
    if (open == null) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _closeSession(
        session: _session,
        sessionId: open.id,
        input: event.input,
      );
      emit(state.copyWith(isSubmitting: false, clearOpenSession: true));
      await _fetch(emit);
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onMovement(
    CashMovementRecordRequested event,
    Emitter<CashSessionsState> emit,
  ) async {
    final open = state.openSession;
    if (open == null) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _recordMovement(
        session: _session,
        sessionId: open.id,
        input: event.input,
      );
      emit(state.copyWith(isSubmitting: false));
      await _fetch(emit);
    } on Failure catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _fetch(Emitter<CashSessionsState> emit) async {
    try {
      unawaited(_syncFromRemote(session: _session));
      final open = await _findOpenSession(session: _session);
      final history = await _listSessions(session: _session);
      CashSessionLiveTotals? totals;
      List<CashMovement> movements = const [];
      if (open != null) {
        totals = await _getLiveTotals(session: _session, cashSession: open);
        movements = await _listMovements(
          session: _session,
          sessionId: open.id,
        );
      }
      emit(
        state.copyWith(
          status: CashSessionsStatus.loaded,
          openSession: open,
          clearOpenSession: open == null,
          liveTotals: totals,
          history: history,
          movements: movements,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: state.openSession != null
              ? CashSessionsStatus.loaded
              : CashSessionsStatus.failure,
          isRefreshing: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: state.openSession != null
              ? CashSessionsStatus.loaded
              : CashSessionsStatus.failure,
          isRefreshing: false,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }
}