part of 'cash_sessions_bloc.dart';

sealed class CashSessionsEvent extends Equatable {
  const CashSessionsEvent();

  @override
  List<Object?> get props => [];
}

final class CashSessionsLoadRequested extends CashSessionsEvent {
  const CashSessionsLoadRequested();
}

final class CashSessionsRefreshRequested extends CashSessionsEvent {
  const CashSessionsRefreshRequested();
}

final class CashSessionOpenRequested extends CashSessionsEvent {
  const CashSessionOpenRequested(this.input);

  final OpenCashSessionInput input;

  @override
  List<Object?> get props => [input];
}

final class CashSessionSubmitClosingRequested extends CashSessionsEvent {
  const CashSessionSubmitClosingRequested(this.input);

  final SubmitCashSessionClosingInput input;

  @override
  List<Object?> get props => [input];
}

final class CashSessionApproveRequested extends CashSessionsEvent {
  const CashSessionApproveRequested({
    required this.sessionId,
    this.input = const ApproveCashSessionInput(),
  });

  final int sessionId;
  final ApproveCashSessionInput input;

  @override
  List<Object?> get props => [sessionId, input];
}

final class CashSessionCloseRequested extends CashSessionsEvent {
  const CashSessionCloseRequested(this.input);

  final CloseCashSessionInput input;

  @override
  List<Object?> get props => [input];
}

final class CashMovementRecordRequested extends CashSessionsEvent {
  const CashMovementRecordRequested(this.input);

  final RecordCashMovementInput input;

  @override
  List<Object?> get props => [input];
}

final class CashSessionOwnerDropRequested extends CashSessionsEvent {
  const CashSessionOwnerDropRequested(this.input);

  final RecordOwnerDropInput input;

  @override
  List<Object?> get props => [input];
}
