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
  });

  final CashSessionsStatus status;
  final CashSession? openSession;
  final CashSessionLiveTotals? liveTotals;
  final List<CashSessionListRow> history;
  final List<CashMovement> movements;
  final bool isRefreshing;
  final bool isSubmitting;
  final String? errorMessage;

  CashSessionsState copyWith({
    CashSessionsStatus? status,
    CashSession? openSession,
    bool clearOpenSession = false,
    CashSessionLiveTotals? liveTotals,
    List<CashSessionListRow>? history,
    List<CashMovement>? movements,
    bool? isRefreshing,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashSessionsState(
      status: status ?? this.status,
      openSession:
          clearOpenSession ? null : (openSession ?? this.openSession),
      liveTotals: liveTotals ?? this.liveTotals,
      history: history ?? this.history,
      movements: movements ?? this.movements,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
      ];
}
