part of 'cash_sessions_bloc.dart';

enum CashSessionsStatus { initial, loading, loaded, failure }

class CashSessionsState extends Equatable {
  const CashSessionsState({
    this.status = CashSessionsStatus.initial,
    this.openSession,
    this.liveTotals,
    this.history = const [],
    this.movements = const [],
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
  });

  final CashSessionsStatus status;
  final CashSession? openSession;
  final CashSessionLiveTotals? liveTotals;
  final List<CashSessionListRow> history;
  final List<CashMovement> movements;
  final bool isRefreshing;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  CashSessionsState copyWith({
    CashSessionsStatus? status,
    CashSession? openSession,
    bool clearOpenSession = false,
    CashSessionLiveTotals? liveTotals,
    bool clearLiveTotals = false,
    List<CashSessionListRow>? history,
    List<CashMovement>? movements,
    bool? isRefreshing,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return CashSessionsState(
      status: status ?? this.status,
      openSession:
          clearOpenSession ? null : (openSession ?? this.openSession),
      liveTotals:
          (clearOpenSession || clearLiveTotals) ? null : (liveTotals ?? this.liveTotals),
      history: history ?? this.history,
      movements: clearOpenSession ? const [] : (movements ?? this.movements),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        openSession,
        liveTotals,
        history,
        movements,
        isRefreshing,
        isSubmitting,
        errorMessage,
        successMessage,
      ];
}
